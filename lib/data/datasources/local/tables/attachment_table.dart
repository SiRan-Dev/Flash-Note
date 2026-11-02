import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';

@TableIndex(name: 'attachments_uuid_unique', columns: {#uuid}, unique: true)
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerType => text().withLength(min: 1)(); // 'inspiration' or 'project'
  IntColumn get ownerId => integer()();
  TextColumn get fileName => text().withLength(min: 1)();
  TextColumn get filePath => text().withLength(min: 1)();
  TextColumn get mimeType => text().withLength(min: 1)();
  IntColumn get size => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  /// 跨设备唯一身份，[id] 保持不变。
  TextColumn get uuid =>
      text().clientDefault(newUuidV4).customConstraint("NOT NULL DEFAULT ''")();
}
