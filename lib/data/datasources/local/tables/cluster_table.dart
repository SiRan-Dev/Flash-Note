import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';

@TableIndex(name: 'clusters_uuid_unique', columns: {#uuid}, unique: true)
class Clusters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// 跨设备唯一身份，[id] 保持不变。
  TextColumn get uuid =>
      text().clientDefault(newUuidV4).customConstraint("NOT NULL DEFAULT ''")();
}
