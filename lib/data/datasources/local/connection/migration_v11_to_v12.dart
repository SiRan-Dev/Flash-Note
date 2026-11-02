import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';
import 'package:flashnote/data/datasources/local/schema_versions.dart';

/// 需要补 `uuid` 的同步实体表，以及它们各自唯一索引的名字。
///
/// 索引名必须与表定义上的 `@TableIndex` 一致，否则 SchemaVerifier 会认为迁移
/// 后的库与 v12 基线不同。
const Map<String, String> _uuidIndexes = {
  'inspirations': 'inspirations_uuid_unique',
  'projects': 'projects_uuid_unique',
  'tasks': 'tasks_uuid_unique',
  'attachments': 'attachments_uuid_unique',
  'reports': 'reports_uuid_unique',
  'inspiration_links': 'inspiration_links_uuid_unique',
  'clusters': 'clusters_uuid_unique',
  'custom_sources': 'custom_sources_uuid_unique',
  'chat_messages': 'chat_messages_uuid_unique',
};

const int _batchSize = 500;

/// v11 → v12：为同步实体补跨设备 UUID，并把墓碑表切换到
/// `(entityType, entityUuid)` 唯一键。
///
/// 迁移由 [AppDatabase] 包在一个事务里；本函数内的每一步都必须幂等，这样
/// 迁移中断后重试也不会因为列/索引已存在而失败。
Future<void> migrateFrom11To12(Migrator m, Schema12 schema) async {
  await _addUuidColumnsIfMissing(m);
  await _backfillUuids(m);
  await _createUuidIndexes(m);
  await _rebuildDeletedRecords(m, schema);
  await _selfCheck(m);
}

Future<void> _addUuidColumnsIfMissing(Migrator m) async {
  for (final table in _uuidIndexes.keys) {
    final columns = await _tableColumns(m, table);
    if (columns.contains('uuid')) continue;

    // 不能交给 m.addColumn：clientDefault 不会变成 SQL DEFAULT，非空表上
    // 添加 NOT NULL 列会直接失败。这里显式写 DEFAULT ''，随后分批回填。
    await m.database.customStatement(
      'ALTER TABLE "$table" ADD COLUMN uuid TEXT NOT NULL DEFAULT \'\'',
    );
  }
}

Future<void> _backfillUuids(Migrator m) async {
  for (final table in _uuidIndexes.keys) {
    if (table == 'reports') {
      await _backfillReports(m);
    } else if (table == 'custom_sources') {
      await _backfillSources(m);
    } else {
      await _backfillRandomUuids(m, table);
    }
  }
}

Future<void> _backfillRandomUuids(Migrator m, String table) async {
  while (true) {
    final rows = await m.database
        .customSelect(
          'SELECT id FROM "$table" WHERE length(uuid) = 0 '
          'ORDER BY id LIMIT $_batchSize',
        )
        .get();
    if (rows.isEmpty) return;

    await m.database.batch((batch) {
      for (final row in rows) {
        batch.customStatement('UPDATE "$table" SET uuid = ? WHERE id = ?', [
          newUuidV4(),
          row.read<int>('id'),
        ]);
      }
    });
  }
}

/// 报告按 type 确定性回填：同一 type 只保留一行使用 type UUID，重复历史行
/// 用 id 区分，避免唯一索引冲突。
Future<void> _backfillReports(Migrator m) async {
  final assignedTypes = <String>{};

  while (true) {
    final rows = await m.database
        .customSelect(
          'SELECT id, type FROM reports WHERE length(uuid) = 0 '
          'ORDER BY type, updated_at DESC, id DESC LIMIT $_batchSize',
        )
        .get();
    if (rows.isEmpty) return;

    await m.database.batch((batch) {
      for (final row in rows) {
        final type = row.read<String>('type');
        final id = row.read<int>('id');
        final firstOfType = assignedTypes.add(type);
        final uuid = firstOfType
            ? deterministicReportUuid(type)
            : deterministicReportUuid(type, discriminator: id);
        batch.customStatement('UPDATE reports SET uuid = ? WHERE id = ?', [
          uuid,
          id,
        ]);
      }
    });
  }
}

/// 内置来源按 name 确定性回填；自定义来源保留随机 UUID。
Future<void> _backfillSources(Migrator m) async {
  final assignedNames = <String>{};

  while (true) {
    final rows = await m.database
        .customSelect(
          'SELECT id, name, is_built_in FROM custom_sources '
          'WHERE length(uuid) = 0 '
          'ORDER BY is_built_in DESC, id LIMIT $_batchSize',
        )
        .get();
    if (rows.isEmpty) return;

    await m.database.batch((batch) {
      for (final row in rows) {
        final id = row.read<int>('id');
        final name = row.read<String>('name');
        final isBuiltIn = row.read<int>('is_built_in') != 0;

        String uuid;
        if (!isBuiltIn) {
          uuid = newUuidV4();
        } else if (assignedNames.add(name)) {
          uuid = deterministicBuiltInSourceUuid(name);
        } else {
          uuid = deterministicBuiltInSourceUuid(name, discriminator: id);
        }

        batch.customStatement(
          'UPDATE custom_sources SET uuid = ? WHERE id = ?',
          [uuid, id],
        );
      }
    });
  }
}

Future<void> _createUuidIndexes(Migrator m) async {
  for (final entry in _uuidIndexes.entries) {
    await m.database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS "${entry.value}" '
      'ON "${entry.key}" (uuid)',
    );
  }
}

/// 重建墓碑表：`entityId` 保留为可空过渡列，唯一键改为
/// `(entityType, entityUuid)`，旧墓碑标记 `legacy = true`。
Future<void> _rebuildDeletedRecords(Migrator m, Schema12 schema) async {
  final columns = await _tableColumns(m, 'deleted_records');
  if (columns.contains('entity_uuid')) return;

  final oldRows = await m.database
      .customSelect(
        'SELECT id, entity_type, entity_id, deleted_at FROM deleted_records',
      )
      .get();

  const newTable = 'deleted_records_v12';
  // 复用 v12 基线里的表定义，保证列类型/约束与全新安装完全一致。
  await m.createTable(schema.deletedRecords.createAlias(newTable));

  await m.database.batch((batch) {
    for (final row in oldRows) {
      final entityType = row.read<String>('entity_type');
      final entityId = row.read<int>('entity_id');
      batch.customStatement(
        'INSERT INTO "$newTable" '
        '(id, entity_type, entity_uuid, entity_id, deleted_at, legacy) '
        'VALUES (?, ?, ?, ?, ?, 1)',
        [
          row.read<int>('id'),
          entityType,
          legacyTombstoneUuid(entityType, entityId),
          entityId,
          row.read<int>('deleted_at'),
        ],
      );
    }
  });

  await m.database.customStatement('DROP TABLE deleted_records');
  await m.database.customStatement(
    'ALTER TABLE "$newTable" RENAME TO deleted_records',
  );
}

Future<void> _selfCheck(Migrator m) async {
  final db = m.database;

  for (final table in _uuidIndexes.keys) {
    final empty = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM "$table" WHERE length(uuid) = 0',
        )
        .getSingle();
    if (empty.read<int>('c') > 0) {
      throw StateError('迁移自检失败：$table 仍存在空 uuid');
    }

    final duplicates = await db
        .customSelect(
          'SELECT uuid FROM "$table" '
          'GROUP BY uuid HAVING COUNT(*) > 1 LIMIT 1',
        )
        .get();
    if (duplicates.isNotEmpty) {
      throw StateError('迁移自检失败：$table 存在重复 uuid');
    }
  }

  final emptyTombstone = await db
      .customSelect(
        'SELECT COUNT(*) AS c FROM deleted_records '
        'WHERE length(entity_uuid) = 0',
      )
      .getSingle();
  if (emptyTombstone.read<int>('c') > 0) {
    throw StateError('迁移自检失败：deleted_records 存在空 entity_uuid');
  }

  // 逻辑孤儿（例如项目已删但任务还在）可能来自历史快照或手动导入，
  // 本轮只统计数量，不作为失败条件。
  await _countLogicalOrphans(m);
}

Future<int> _countLogicalOrphans(Migrator m) async {
  const queries = [
    'SELECT COUNT(*) AS c FROM tasks t LEFT JOIN projects p ON p.id = t.project_id WHERE p.id IS NULL',
    'SELECT COUNT(*) AS c FROM projects p LEFT JOIN inspirations i ON i.id = p.inspiration_id WHERE p.inspiration_id IS NOT NULL AND i.id IS NULL',
    'SELECT COUNT(*) AS c FROM chat_messages c LEFT JOIN inspirations i ON i.id = c.inspiration_id WHERE i.id IS NULL',
    'SELECT COUNT(*) AS c FROM inspiration_links l LEFT JOIN inspirations a ON a.id = l.source_id LEFT JOIN inspirations b ON b.id = l.target_id WHERE a.id IS NULL OR b.id IS NULL',
    "SELECT COUNT(*) AS c FROM attachments a LEFT JOIN inspirations i ON i.id = a.owner_id WHERE a.owner_type = 'inspiration' AND i.id IS NULL",
    "SELECT COUNT(*) AS c FROM attachments a LEFT JOIN projects p ON p.id = a.owner_id WHERE a.owner_type = 'project' AND p.id IS NULL",
  ];

  var total = 0;
  for (final query in queries) {
    final row = await m.database.customSelect(query).getSingle();
    total += row.read<int>('c');
  }
  return total;
}

Future<Set<String>> _tableColumns(Migrator m, String tableName) async {
  final rows = await m.database
      .customSelect('PRAGMA table_info("$tableName")')
      .get();
  return {for (final row in rows) row.read<String>('name')};
}
