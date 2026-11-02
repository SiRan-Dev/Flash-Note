import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';

@TableIndex(name: 'projects_uuid_unique', columns: {#uuid}, unique: true)
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get inspirationId => integer().nullable()();
  TextColumn get title => text().withLength(min: 1)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// 跨设备唯一身份，[id] 保持不变。
  TextColumn get uuid =>
      text().clientDefault(newUuidV4).customConstraint("NOT NULL DEFAULT ''")();
}
