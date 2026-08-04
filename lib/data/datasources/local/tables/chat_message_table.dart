import 'package:drift/drift.dart';

class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get inspirationId => integer()();
  TextColumn get role => text().withLength(min: 1)();
  TextColumn get content => text()();
  IntColumn get createdAt => integer()();
}
