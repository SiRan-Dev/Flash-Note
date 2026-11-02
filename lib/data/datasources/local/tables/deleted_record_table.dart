import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';

class DeletedRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text().withLength(min: 1)();

  /// 被删除实体的跨设备 UUID。
  ///
  /// 旧版快照（v5/v6）没有这个字段，导入时由 `insertDeletedRecord` 用
  /// [legacyTombstoneUuid] 补一个确定性的值。
  TextColumn get entityUuid => text().clientDefault(newUuidV4)();

  /// 过渡保留：v11 及更旧的墓碑只有自增 id，UI 和同步尚未消费 UUID。
  IntColumn get entityId => integer().nullable()();

  IntColumn get deletedAt => integer()();

  /// 由 v11 迁移过来的旧墓碑（没有原始实体 UUID）。
  BoolColumn get legacy => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {entityType, entityUuid},
  ];
}
