import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';

@TableIndex(name: 'chat_messages_uuid_unique', columns: {#uuid}, unique: true)
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get inspirationId => integer()();
  TextColumn get role => text().withLength(min: 1)();
  TextColumn get content => text()();
  IntColumn get createdAt => integer()();

  /// 跨设备唯一身份，[id] 保持不变。
  TextColumn get uuid =>
      text().clientDefault(newUuidV4).customConstraint("NOT NULL DEFAULT ''")();
}
