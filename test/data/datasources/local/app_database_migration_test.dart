import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v11 fixture 打开后结构一致、数据完好、integrity_check 为 ok', () async {
    final schema = await verifier.schemaAt(11);
    addTearDown(schema.close);

    schema.rawDatabase.execute(
      'INSERT INTO inspirations (content, created_at, updated_at) '
      "VALUES ('v11 保留下来的数据', 1000, 1000)",
    );

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 11);

    final rows = await db.getAllInspirations();
    expect(rows, hasLength(1));
    expect(rows.single.content, 'v11 保留下来的数据');

    final version = await _userVersion(db);
    expect(version, 11);

    final integrity = await _integrityCheck(db);
    expect(integrity, 'ok');
  });

  test('v10 fixture 升级到 v11：迁移成功、数据完好、integrity_check 为 ok', () async {
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

    await verifier.migrateAndValidate(db, 11);

    final rows = await db.getAllInspirations();
    expect(rows, hasLength(1));
    expect(rows.single.content, 'v10 升级后必须还在');
    expect(await _userVersion(db), 11);
    expect(await _tableExists(db, 'global_chat_messages'), isTrue);
    expect(await _integrityCheck(db), 'ok');
  });

  test('迁移中抛错：事务回滚，仍是 v10 结构，user_version 仍为 10，数据完好', () async {
    final schema = await verifier.schemaAt(11);
    addTearDown(schema.close);

    schema.rawDatabase.execute('DROP TABLE global_chat_messages');
    schema.rawDatabase.execute('PRAGMA user_version = 10');
    schema.rawDatabase.execute(
      'INSERT INTO inspirations (content, created_at, updated_at) '
      "VALUES ('升级失败也不能丢', 1000, 1000)",
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

    // 直接读底层 sqlite 文件，确认 DDL 和 user_version 都被回滚。
    expect(_rawUserVersion(schema), 10);
    expect(
      schema.rawDatabase
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'global_chat_messages'",
          )
          .length,
      0,
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
    await verifier.migrateAndValidate(retry, 11);

    final rows = await retry.getAllInspirations();
    expect(rows, hasLength(1));
    expect(rows.single.content, '升级失败也不能丢');
    expect(await _userVersion(retry), 11);
  });

  test('对已迁移的库重复执行迁移步骤：无报错、无数据变化', () async {
    final schema = await verifier.schemaAt(11);
    addTearDown(schema.close);

    schema.rawDatabase.execute(
      'INSERT INTO inspirations (content, created_at, updated_at) '
      "VALUES ('重复迁移不能改数据', 1000, 1000)",
    );

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 11);
    final before = await db.getAllInspirations();

    // 模拟“迁移曾中断、第二次启动又从很旧的版本重跑”的场景：直接对已经
    // 是 v11 的库执行全部历史步骤，新增列/建表都必须幂等。
    await db.migration.onUpgrade(Migrator(db), 1, 11);
    await db.migration.onUpgrade(Migrator(db), 10, 11);

    final after = await db.getAllInspirations();
    expect(after, hasLength(before.length));
    expect(after.single.id, before.single.id);
    expect(after.single.content, before.single.content);
    expect(await _userVersion(db), 11);
    expect(await _integrityCheck(db), 'ok');
  });
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

int _rawUserVersion(InitializedSchema schema) {
  return schema.rawDatabase.select('PRAGMA user_version').single['user_version']
      as int;
}
