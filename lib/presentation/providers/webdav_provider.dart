import 'package:flashnote/data/datasources/local/webdav_storage.dart';
import 'package:flashnote/data/services/webdav_sync_service.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncStatus { idle, syncing, done }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

final webdavStorageProvider = FutureProvider<WebDavStorage>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return WebDavStorage(prefs: prefs);
});

final webdavSyncServiceProvider = FutureProvider<WebDavSyncService>((ref) async {
  final db = ref.watch(databaseProvider);
  final aiStorage = await ref.watch(aiSettingsStorageProvider.future);
  final webdavStorage = await ref.watch(webdavStorageProvider.future);
  return WebDavSyncService(
    db: db,
    aiStorage: aiStorage,
    webdavStorage: webdavStorage,
  );
});
