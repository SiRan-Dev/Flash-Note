import 'dart:io';

import 'package:flashnote/data/datasources/local/connection/migration_backup_registry.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Thrown when a database backup could not be created.
///
/// The native connection propagates this before opening the database, so an
/// upgrade never starts without a recoverable copy of the previous file.
class MigrationBackupException implements Exception {
  const MigrationBackupException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message ($cause)';
}

/// Copies the SQLite database (and its `-wal` / `-shm` sidecars) before a
/// schema upgrade so users can recover if the migration goes wrong.
///
/// The copy lives next to the database in a timestamped directory:
///
/// ```text
/// flashnote_backups/v10_to_v11_20261102_160000_000/
///   flashnote.db
///   flashnote.db-wal   (only if the source had one)
///   flashnote.db-shm
///   backup_complete
/// ```
///
/// `backup_complete` is written last and acts as the "already backed up"
/// marker: an incomplete backup from a crash is ignored, and a completed
/// backup for the same version transition is reused instead of creating
/// duplicates.
class NativeMigrationBackup {
  NativeMigrationBackup._();

  /// Name of the marker file written after all database files were copied.
  static const String markerFileName = 'backup_complete';

  /// Creates a backup if [databaseFile] exists and is older than
  /// [targetVersion]. Returns the backup for the pending transition, or
  /// `null` when no upgrade (or no existing database) is detected.
  ///
  /// Throws [MigrationBackupException] when the version cannot be read or the
  /// copy fails. Callers must treat that as fatal for the current startup.
  static Future<MigrationBackupSummary?> prepare({
    required File databaseFile,
    required Directory backupRoot,
    required int targetVersion,
  }) async {
    if (!await databaseFile.exists()) return null;

    Directory? createdDirectory;
    try {
      final currentVersion = _readUserVersion(databaseFile);
      // 0 is drift's marker for a brand-new database; >= target needs no
      // upgrade. Neither case requires a copy.
      if (currentVersion <= 0 || currentVersion >= targetVersion) return null;

      final existing = _findCompletedBackup(
        backupRoot,
        currentVersion,
        targetVersion,
      );
      if (existing != null) {
        MigrationBackupRegistry.lastBackup = existing;
        return existing;
      }

      final directory = Directory(
        p.join(
          backupRoot.path,
          'v${currentVersion}_to_v$targetVersion'
          '_${_timestamp(DateTime.now())}',
        ),
      );
      createdDirectory = directory;
      await directory.create(recursive: true);

      final dbName = p.basename(databaseFile.path);
      await _copyIfExists(databaseFile, File(p.join(directory.path, dbName)));
      await _copyIfExists(
        File('${databaseFile.path}-wal'),
        File(p.join(directory.path, '$dbName-wal')),
      );
      await _copyIfExists(
        File('${databaseFile.path}-shm'),
        File(p.join(directory.path, '$dbName-shm')),
      );

      await File(p.join(directory.path, markerFileName)).writeAsString(
        'FlashNote migration backup\n'
        'from_version=$currentVersion\n'
        'to_version=$targetVersion\n'
        'created_at=${DateTime.now().toIso8601String()}\n',
        flush: true,
      );

      final summary = MigrationBackupSummary(
        path: directory.path,
        fromVersion: currentVersion,
        toVersion: targetVersion,
      );
      MigrationBackupRegistry.lastBackup = summary;
      return summary;
    } catch (error) {
      if (createdDirectory != null) {
        try {
          await createdDirectory.delete(recursive: true);
        } catch (_) {
          // Best effort cleanup; the marker was never written, so an
          // incomplete directory is harmless.
        }
      }
      if (error is MigrationBackupException) rethrow;
      throw MigrationBackupException('升级前备份失败，已停止升级，原数据库未被修改。', error);
    }
  }

  /// Reads `PRAGMA user_version` from an at-rest database file.
  ///
  /// The connection is opened read-write (but never written to) so SQLite can
  /// recover a hot journal or read a WAL that still has pending frames.
  static int _readUserVersion(File databaseFile) {
    final db = sqlite3.open(databaseFile.path);
    try {
      final result = db.select('PRAGMA user_version');
      final value = result.first['user_version'];
      return value is int ? value : int.parse('$value');
    } finally {
      db.close();
    }
  }

  static MigrationBackupSummary? _findCompletedBackup(
    Directory backupRoot,
    int fromVersion,
    int toVersion,
  ) {
    if (!backupRoot.existsSync()) return null;

    final prefix = 'v${fromVersion}_to_v${toVersion}_';
    for (final entity in backupRoot.listSync()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(prefix)) continue;
      if (File(p.join(entity.path, markerFileName)).existsSync()) {
        return MigrationBackupSummary(
          path: entity.path,
          fromVersion: fromVersion,
          toVersion: toVersion,
        );
      }
    }
    return null;
  }

  static Future<void> _copyIfExists(File source, File destination) async {
    if (!await source.exists()) return;
    await source.copy(destination.path);
  }

  static String _timestamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${time.year}${two(time.month)}${two(time.day)}'
        '_${two(time.hour)}${two(time.minute)}${two(time.second)}'
        '_${three(time.millisecond)}';
  }
}
