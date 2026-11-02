import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Forces drift to open the database and run pending migrations.
///
/// The app UI waits on this provider so a failed upgrade shows the recovery
/// screen instead of silently running queries against a poisoned connection.
final databaseInitializationProvider = FutureProvider<AppDatabase>((ref) async {
  final db = ref.watch(databaseProvider);
  await db.customSelect('SELECT 1').get();
  return db;
});
