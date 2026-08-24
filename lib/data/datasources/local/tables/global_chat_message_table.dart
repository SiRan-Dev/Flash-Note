import 'package:drift/drift.dart';

class GlobalChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get role => text().withLength(min: 1)();
  TextColumn get content => text()();
  IntColumn get createdAt => integer()();
  IntColumn get inspirationId => integer().nullable()();
}
