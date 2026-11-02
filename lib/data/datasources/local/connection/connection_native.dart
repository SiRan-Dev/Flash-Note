import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flashnote/core/constants/app_constants.dart';
import 'package:flashnote/data/datasources/local/connection/native_migration_backup.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

DatabaseConnection openConnection() {
  return DatabaseConnection.delayed(
    getApplicationDocumentsDirectory().then(_openAt),
  );
}

/// Variant of [openConnection] with an explicit documents directory, used by
/// tests to exercise the pre-migration backup without path_provider plugins.
@visibleForTesting
Future<DatabaseConnection> openConnectionAt(Directory documentsDirectory) {
  return _openAt(documentsDirectory);
}

Future<DatabaseConnection> _openAt(Directory documentsDirectory) async {
  final file = File(p.join(documentsDirectory.path, AppConstants.dbName));

  // 升级前先做文件级备份。备份抛错时这里会直接失败，绝不会创建后面的
  // NativeDatabase，因此不会出现"没备份就开始升级"的情况。
  await NativeMigrationBackup.prepare(
    databaseFile: file,
    backupRoot: Directory(
      p.join(documentsDirectory.path, AppConstants.backupDirectoryName),
    ),
    targetVersion: AppConstants.schemaVersion,
  );

  return DatabaseConnection(NativeDatabase.createInBackground(file));
}
