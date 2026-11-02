import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../generated_migrations/schema.dart';

const _uuidTables = [
  'inspirations',
  'projects',
  'tasks',
  'attachments',
  'reports',
  'inspiration_links',
  'clusters',
  'custom_sources',
  'chat_messages',
];

const _uuidIndexes = [
  'inspirations_uuid_unique',
  'projects_uuid_unique',
  'tasks_uuid_unique',
  'attachments_uuid_unique',
  'reports_uuid_unique',
  'inspiration_links_uuid_unique',
  'clusters_uuid_unique',
  'custom_sources_uuid_unique',
  'chat_messages_uuid_unique',
];

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v11 fixture 升级到 v12：id/关系不变、uuid 唯一、墓碑补齐、结构一致', () async {
    final schema = await verifier.schemaAt(11);
    addTearDown(schema.close);

    _insertFullV11Fixture(schema);

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 12);

    // id 原样保留
    final inspiration = await db.getInspirationById(1);
    expect(inspiration, isNotNull);
    expect(inspiration!.content, '第一条灵感');
    expect(inspiration.id, 1);
    expect(inspiration.needsFollowUp, isTrue);

    final project = await db.getProjectById(1);
    expect(project!.inspirationId, 1);
    final task = await db.getTaskById(1);
    expect(task!.projectId, 1);
    final attachment = await db.getAttachmentById(1);
    expect(attachment!.ownerId, 1);
    expect(attachment.ownerType, 'inspiration');
    final link = await db.getLinkById(1);
    expect(link!.sourceId, 1);
    expect(link.targetId, 2);
    final chat = (await db.getChatMessagesByInspirationId(1)).single;
    expect(chat.inspirationId, 1);

    // uuid 全部非空且唯一
    for (final table in _uuidTables) {
      final uuids = await _uuids(db, table);
      expect(uuids, isNotEmpty, reason: '$table 应有数据');
      expect(uuids.where((u) => u.isEmpty), isEmpty, reason: '$table 有空 uuid');
      expect(uuids.toSet(), hasLength(uuids.length), reason: '$table uuid 重复');
    }

    // 墓碑：旧 id 保留为过渡列，entityUuid 已补齐，legacy = true
    final tombstones = await db.getAllDeletedRecords();
    expect(tombstones, hasLength(2));
    for (final tombstone in tombstones) {
      expect(tombstone.entityUuid, isNotEmpty);
      expect(tombstone.entityId, isNotNull);
      expect(tombstone.legacy, isTrue);
    }
    expect(
      tombstones.firstWhere((t) => t.entityType == 'inspirations').entityUuid,
      legacyTombstoneUuid('inspirations', 99),
    );

    // 唯一索引存在且确实是 UNIQUE
    for (final index in _uuidIndexes) {
      expect(await _hasUniqueIndex(db, index), isTrue, reason: '$index 缺失');
    }

    expect(await _userVersion(db), 12);
    expect(await _integrityCheck(db), 'ok');
  });

  test('历史 needs_follow_up 无 CHECK 的 v11 库也能迁移（不校验结构差异）', () async {
    final schema = await verifier.schemaAt(11);
    addTearDown(schema.close);

    // 模拟从 v10 用 raw ALTER 升级上来的库：needs_follow_up 没有 CHECK。
    schema.rawDatabase.execute(
      'INSERT INTO inspirations '
      '(id, content, created_at, updated_at, needs_follow_up) '
      "VALUES (1, '历史结构', 1000, 1000, 1)",
    );
    schema.rawDatabase.execute(
      'ALTER TABLE inspirations RENAME TO inspirations_legacy',
    );
    schema.rawDatabase.execute(
      'CREATE TABLE inspirations ( '
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"content" TEXT NOT NULL, "source" TEXT NULL, '
      "\"tags\" TEXT NOT NULL DEFAULT '[]', "
      '"ai_analysis" TEXT NULL, "mind_map_data" TEXT NULL, '
      '"is_pinned" INTEGER NOT NULL DEFAULT 0 '
      'CHECK ("is_pinned" IN (0, 1)), '
      '"created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, '
      '"reviewed_at" INTEGER NULL, '
      '"needs_follow_up" INTEGER NOT NULL DEFAULT 0)',
    );
    schema.rawDatabase.execute(
      'INSERT INTO inspirations (id, content, source, tags, is_pinned, '
      'created_at, updated_at, needs_follow_up) '
      'SELECT id, content, source, tags, is_pinned, created_at, updated_at, '
      'needs_follow_up FROM inspirations_legacy',
    );
    schema.rawDatabase.execute('DROP TABLE inspirations_legacy');
    schema.rawDatabase.execute(
      "INSERT INTO deleted_records (entity_type, entity_id, deleted_at) "
      "VALUES ('inspirations', 1, 1000)",
    );

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);

    // 不能 migrateAndValidate：遗留结构缺少 CHECK，本轮按要求不顺手归一化。
    await db.customSelect('SELECT 1').get();

    final rows = await db.getAllInspirations();
    expect(rows, hasLength(1));
    expect(rows.single.id, 1);
    expect(rows.single.needsFollowUp, isTrue);
    expect(rows.single.uuid, isNotEmpty);

    final tombstone = (await db.getAllDeletedRecords()).single;
    expect(tombstone.entityUuid, legacyTombstoneUuid('inspirations', 1));
    expect(tombstone.entityId, 1);

    expect(await _userVersion(db), 12);
    expect(await _integrityCheck(db), 'ok');
    expect(await _hasUniqueIndex(db, 'inspirations_uuid_unique'), isTrue);
  });

  test('v10 fixture 升级到 v12：迁移成功、数据完好、integrity_check 为 ok', () async {
    final schema = await verifier.schemaAt(11);
    addTearDown(schema.close);

    // 从 v11 基线里去掉 v11 新增的 global_chat_messages 表，并把
    // user_version 降回 10，得到一个真实的 v10 数据库。
    schema.rawDatabase.execute('DROP TABLE global_chat_messages');
    schema.rawDatabase.execute('PRAGMA user_version = 10');
    schema.rawDatabase.execute(
      'INSERT INTO inspirations (content, created_at, updated_at) '
      "VALUES ('v10 升级后必须还在', 1000, 1000)",
    );

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 12);

    final rows = await db.getAllInspirations();
    expect(rows, hasLength(1));
    expect(rows.single.content, 'v10 升级后必须还在');
    expect(rows.single.uuid, isNotEmpty);
    expect(await _userVersion(db), 12);
    expect(await _tableExists(db, 'global_chat_messages'), isTrue);
    expect(await _integrityCheck(db), 'ok');
  });

  test('迁移中抛错：事务回滚，仍是 v11 结构，user_version 为 11，数据完好', () async {
    final schema = await verifier.schemaAt(11);
    addTearDown(schema.close);

    schema.rawDatabase.execute(
      'INSERT INTO inspirations (content, created_at, updated_at) '
      "VALUES ('升级失败也不能丢', 1000, 1000)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO deleted_records (entity_type, entity_id, deleted_at) "
      "VALUES ('inspirations', 5, 1000)",
    );

    final db = AppDatabase.forTesting(
      schema.newConnection(),
      onMigrationFinishedForTesting: () =>
          Future<void>.error(StateError('injected migration failure')),
    );
    addTearDown(db.close);

    await expectLater(
      db.customSelect('SELECT 1').get(),
      throwsA(
        predicate(
          (error) => '$error'.contains('injected migration failure'),
          'injected failure propagates',
        ),
      ),
    );

    await db.close();

    // 直接读底层 sqlite 文件，确认 ALTER / 建索引 / 重建墓碑都被回滚。
    expect(_rawUserVersion(schema), 11);
    expect(
      schema.rawDatabase
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'inspirations_uuid_unique'",
          )
          .length,
      0,
    );
    expect(_rawColumns(schema, 'inspirations').contains('uuid'), isFalse);
    expect(
      _rawColumns(schema, 'deleted_records').contains('entity_uuid'),
      isFalse,
    );
    expect(
      schema.rawDatabase
          .select('SELECT content FROM inspirations')
          .single['content'],
      '升级失败也不能丢',
    );
    expect(
      schema.rawDatabase
          .select('PRAGMA integrity_check')
          .single['integrity_check'],
      'ok',
    );

    // 回滚后可以安全重试：同一个底层数据库换成干净连接即可升级成功。
    final retry = AppDatabase.forTesting(schema.newConnection());
    addTearDown(retry.close);
    await verifier.migrateAndValidate(retry, 12);

    final rows = await retry.getAllInspirations();
    expect(rows, hasLength(1));
    expect(rows.single.content, '升级失败也不能丢');
    expect(rows.single.uuid, isNotEmpty);
    expect(await _userVersion(retry), 12);
  });

  test('对已迁移的库重复执行迁移步骤：无报错、uuid 与数据都不变', () async {
    final schema = await verifier.schemaAt(11);
    addTearDown(schema.close);

    schema.rawDatabase.execute(
      'INSERT INTO inspirations (content, created_at, updated_at) '
      "VALUES ('重复迁移不能改数据', 1000, 1000)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO reports (type, content, created_at, updated_at) "
      "VALUES ('weekly', '报告', 1000, 1000)",
    );

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 12);
    final before = await db.getAllInspirations();
    final reportBefore = (await db.getAllReports()).single;
    final tombstonesBefore = await db.getAllDeletedRecords();

    // 模拟“迁移曾中断、第二次启动又从很旧的版本重跑”的场景：直接对已经
    // 是 v12 的库执行全部历史步骤，新增列/索引/墓碑重建都必须幂等。
    await db.migration.onUpgrade(Migrator(db), 1, 12);
    await db.migration.onUpgrade(Migrator(db), 11, 12);

    final after = await db.getAllInspirations();
    expect(after, hasLength(before.length));
    expect(after.single.id, before.single.id);
    expect(after.single.content, before.single.content);
    expect(after.single.uuid, before.single.uuid);

    expect((await db.getAllReports()).single.uuid, reportBefore.uuid);
    expect(await db.getAllDeletedRecords(), hasLength(tombstonesBefore.length));
    expect(await _userVersion(db), 12);
    expect(await _integrityCheck(db), 'ok');
  });
}

void _insertFullV11Fixture(InitializedSchema schema) {
  final raw = schema.rawDatabase;

  raw.execute(
    'INSERT INTO inspirations '
    '(id, content, tags, is_pinned, created_at, updated_at, reviewed_at, '
    'needs_follow_up) '
    "VALUES (1, '第一条灵感', '[\"a\"]', 1, 1000, 1000, 1200, 1)",
  );
  raw.execute(
    'INSERT INTO inspirations (id, content, created_at, updated_at) '
    "VALUES (2, '第二条灵感', 1000, 1000)",
  );
  raw.execute(
    'INSERT INTO projects '
    '(id, inspiration_id, title, description, progress, status, is_pinned, '
    'created_at, updated_at) '
    "VALUES (1, 1, '项目', '描述', 30, 'active', 0, 1000, 1000)",
  );
  raw.execute(
    'INSERT INTO tasks '
    '(id, project_id, title, is_completed, is_pinned, created_at, updated_at) '
    "VALUES (1, 1, '任务', 0, 0, 1000, 1000)",
  );
  raw.execute(
    'INSERT INTO attachments '
    '(id, owner_type, owner_id, file_name, file_path, mime_type, size, '
    'created_at) '
    "VALUES (1, 'inspiration', 1, 'a.txt', '/tmp/a.txt', 'text/plain', 10, "
    '1000)',
  );
  raw.execute(
    'INSERT INTO chat_messages '
    '(id, inspiration_id, role, content, created_at) '
    "VALUES (1, 1, 'user', '你好', 1000)",
  );
  raw.execute(
    'INSERT INTO inspiration_links '
    '(id, source_id, target_id, link_type, relation_label, confidence, '
    'is_auto_generated, created_at) '
    "VALUES (1, 1, 2, 'similar', '相近', 0.8, 1, 1000)",
  );
  raw.execute(
    'INSERT INTO clusters (id, name, description, created_at, updated_at) '
    "VALUES (1, '聚类', '描述', 1000, 1000)",
  );
  raw.execute(
    'INSERT INTO reports (id, type, content, model, created_at, updated_at) '
    "VALUES (1, 'weekly', '周报内容', 'gpt', 1000, 1000)",
  );
  raw.execute(
    'INSERT INTO custom_sources '
    '(id, name, icon, sort_order, is_built_in, created_at) '
    "VALUES (1, 'flash', 'lightbulb', 0, 1, 1000)",
  );
  raw.execute(
    'INSERT INTO custom_sources '
    '(id, name, icon, sort_order, is_built_in, created_at) '
    "VALUES (2, '我的来源', 'star', 1, 0, 1000)",
  );
  raw.execute(
    'INSERT INTO deleted_records (entity_type, entity_id, deleted_at) '
    "VALUES ('inspirations', 99, 1000)",
  );
  raw.execute(
    'INSERT INTO deleted_records (entity_type, entity_id, deleted_at) '
    "VALUES ('tasks', 999, 1000)",
  );
}

Future<Set<String>> _uuids(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT uuid FROM "$table"').get();
  return {for (final row in rows) row.read<String>('uuid')};
}

Future<int> _userVersion(AppDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

Future<String> _integrityCheck(AppDatabase db) async {
  final row = await db.customSelect('PRAGMA integrity_check').getSingle();
  return row.read<String>('integrity_check');
}

Future<bool> _tableExists(AppDatabase db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(table)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<bool> _hasUniqueIndex(AppDatabase db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = ?",
        variables: [Variable<String>(name)],
      )
      .get();
  if (rows.isEmpty) return false;
  return rows.single.read<String>('sql').toUpperCase().contains('UNIQUE INDEX');
}

int _rawUserVersion(InitializedSchema schema) {
  return schema.rawDatabase.select('PRAGMA user_version').single['user_version']
      as int;
}

Set<String> _rawColumns(InitializedSchema schema, String table) {
  return {
    for (final row in schema.rawDatabase.select('PRAGMA table_info("$table")'))
      row['name'] as String,
  };
}
