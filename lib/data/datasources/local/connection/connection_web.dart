import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flashnote/core/constants/app_constants.dart';

// Web 数据库（IndexedDB）没有可以直接复制的 `flashnote.db` / `-wal` / `-shm`
// 文件，因此不走迁移前文件备份。迁移本身仍在 `AppDatabase.migration` 的
// 事务中执行：失败会整体回滚并保留旧的 `user_version`，失败页会向用户说明
// 浏览器端没有文件备份可导出。
DatabaseConnection openConnection() {
  return DatabaseConnection.delayed(WasmDatabase.open(
    databaseName: AppConstants.dbName,
    sqlite3Uri: Uri.parse('/sqlite3.wasm'),
    driftWorkerUri: Uri.parse('/drift_worker.js'),
  ).then((result) => result.resolvedExecutor));
}
