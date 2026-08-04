import 'package:drift/drift.dart';

class Reports extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text().withLength(min: 1)();
  TextColumn get content => text()();
  TextColumn get model => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}
