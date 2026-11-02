import 'dart:io';

import 'package:flashnote/core/constants/app_constants.dart';
import 'package:flashnote/data/datasources/local/connection/connection_native.dart';
import 'package:flashnote/data/datasources/local/connection/migration_backup_registry.dart';
import 'package:flashnote/data/datasources/local/connection/native_migration_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flashnote_backup_test_');
    MigrationBackupRegistry.lastBackup = null;
  });

  tearDown(() async {
    MigrationBackupRegistry.lastBackup = null;
    await tempDir.delete(recursive: true);
  });

  File createDatabase(int version, {String content = '保留的数据'}) {
    final file = File(p.join(tempDir.path, AppConstants.dbName));
    final db = sqlite3.open(file.path);
    db.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, content TEXT)');
    db.execute("INSERT INTO notes (content) VALUES ('$content')");
    db.execute('PRAGMA user_version = $version');
    db.close();
    return file;
  }

  test('升级前备份生成 db/wal/shm 与完成标记，且备份库可打开', () async {
    // 保持一个 WAL 模式连接打开，确保 -wal / -shm 在备份期间真实存在，
    // 并且数据确实还在 WAL 里。
    final dbFile = File(p.join(tempDir.path, AppConstants.dbName));
    final source = sqlite3.open(dbFile.path);
    source.execute('PRAGMA journal_mode = WAL');
    source.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, content TEXT)');
    source.execute("INSERT INTO notes (content) VALUES ('保留的数据')");
    source.execute('PRAGMA user_version = 10');
    expect(File('${dbFile.path}-wal').existsSync(), isTrue);
    expect(File('${dbFile.path}-shm').existsSync(), isTrue);

    final backupRoot = Directory(
      p.join(tempDir.path, AppConstants.backupDirectoryName),
    );
    final backup = await NativeMigrationBackup.prepare(
      databaseFile: dbFile,
      backupRoot: backupRoot,
      targetVersion: 11,
    );
    source.close();

    expect(backup, isNotNull);
    expect(backup!.fromVersion, 10);
    expect(backup.toVersion, 11);
    expect(MigrationBackupRegistry.lastBackup?.path, backup.path);

    final backupDir = Directory(backup.path);
    expect(backupDir.existsSync(), isTrue);
    final backupDb = File(p.join(backup.path, AppConstants.dbName));
    expect(backupDb.existsSync(), isTrue);
    expect(File('${backupDb.path}-wal').existsSync(), isTrue);
    expect(File('${backupDb.path}-shm').existsSync(), isTrue);
    expect(
      File(
        p.join(backup.path, NativeMigrationBackup.markerFileName),
      ).existsSync(),
      isTrue,
    );

    // 打开副本，确认它就是升级前的数据库（含 WAL 中的数据）。
    final copy = sqlite3.open(backupDb.path);
    try {
      expect(copy.select('PRAGMA user_version').single['user_version'], 10);
      expect(
        copy.select('PRAGMA integrity_check').single['integrity_check'],
        'ok',
      );
      expect(
        copy.select('SELECT content FROM notes').single['content'],
        '保留的数据',
      );
    } finally {
      copy.close();
    }
  });

  test('同一版本区间只备份一次，复用已有完成备份', () async {
    final dbFile = createDatabase(10);
    final backupRoot = Directory(
      p.join(tempDir.path, AppConstants.backupDirectoryName),
    );

    final first = await NativeMigrationBackup.prepare(
      databaseFile: dbFile,
      backupRoot: backupRoot,
      targetVersion: 11,
    );
    expect(first, isNotNull);

    final second = await NativeMigrationBackup.prepare(
      databaseFile: dbFile,
      backupRoot: backupRoot,
      targetVersion: 11,
    );
    expect(second, isNotNull);
    expect(second!.path, first!.path);
    expect(backupRoot.listSync().whereType<Directory>(), hasLength(1));
  });

  test('版本已等于目标或文件不存在时不备份', () async {
    final dbFile = createDatabase(11);
    final backupRoot = Directory(
      p.join(tempDir.path, AppConstants.backupDirectoryName),
    );

    expect(
      await NativeMigrationBackup.prepare(
        databaseFile: dbFile,
        backupRoot: backupRoot,
        targetVersion: 11,
      ),
      isNull,
    );
    expect(backupRoot.existsSync(), isFalse);

    final missing = File(p.join(tempDir.path, 'missing.db'));
    expect(
      await NativeMigrationBackup.prepare(
        databaseFile: missing,
        backupRoot: backupRoot,
        targetVersion: 11,
      ),
      isNull,
    );
  });

  test('备份失败会抛错，连接不会继续创建（升级不会开始）', () async {
    createDatabase(10);
    // 让备份目录路径本身是一个文件，创建目录必然失败。
    File(
      p.join(tempDir.path, AppConstants.backupDirectoryName),
    ).writeAsStringSync('not a directory');

    await expectLater(
      openConnectionAt(tempDir),
      throwsA(isA<MigrationBackupException>()),
    );
    expect(MigrationBackupRegistry.lastBackup, isNull);

    // 原数据库仍停留在 v10，未被改动。
    final db = sqlite3.open(p.join(tempDir.path, AppConstants.dbName));
    try {
      expect(db.select('PRAGMA user_version').single['user_version'], 10);
      expect(db.select('SELECT content FROM notes').single['content'], '保留的数据');
    } finally {
      db.close();
    }
  });
}
