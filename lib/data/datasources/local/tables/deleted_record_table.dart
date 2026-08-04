import 'package:drift/drift.dart';

class DeletedRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text().withLength(min: 1)();
  IntColumn get entityId => integer()();
  IntColumn get deletedAt => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {entityType, entityId},
  ];
}
