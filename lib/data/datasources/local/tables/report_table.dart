import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';

@TableIndex(name: 'reports_uuid_unique', columns: {#uuid}, unique: true)
class Reports extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text().withLength(min: 1)();
  TextColumn get content => text()();
  TextColumn get model => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// 报告按 type 确定性生成，保证两端离线生成的是同一条记录。
  TextColumn get uuid =>
      text().clientDefault(newUuidV4).customConstraint("NOT NULL DEFAULT ''")();
}
