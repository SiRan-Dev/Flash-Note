import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flashnote/core/constants/app_constants.dart';

DatabaseConnection openConnection() {
  return DatabaseConnection.delayed(WasmDatabase.open(
    databaseName: AppConstants.dbName,
    sqlite3Uri: Uri.parse('/sqlite3.wasm'),
    driftWorkerUri: Uri.parse('/drift_worker.js'),
  ).then((result) => result.resolvedExecutor));
}
