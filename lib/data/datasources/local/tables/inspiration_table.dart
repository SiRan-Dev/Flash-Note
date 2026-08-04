import 'package:drift/drift.dart';

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
}
