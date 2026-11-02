import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';

@TableIndex(name: 'inspirations_uuid_unique', columns: {#uuid}, unique: true)
class Inspirations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text().withLength(min: 1)();
  TextColumn get source => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get aiAnalysis => text().nullable()();
  TextColumn get mindMapData => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get reviewedAt => integer().nullable()();
  BoolColumn get needsFollowUp => boolean().withDefault(const Constant(false))();

  /// 跨设备唯一身份。自增 [id] 仍然保留给 UI/路由/仓储使用。
  ///
  /// SQL 里写死 `DEFAULT ''` 是为了让 v11→v12 的 `ALTER TABLE ADD COLUMN` 能
  /// 在非空表上通过，并与全新安装的建表语句保持一致（drift 的 clientDefault
  /// 不会出现在 SQL DEFAULT 中）。
  TextColumn get uuid =>
      text().clientDefault(newUuidV4).customConstraint("NOT NULL DEFAULT ''")();
}
