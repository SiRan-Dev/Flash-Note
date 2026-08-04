import 'package:flashnote/data/services/data_export_service.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flashnote/presentation/providers/webdav_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dataExportServiceProvider = FutureProvider<DataExportService>((ref) async {
  final db = ref.watch(databaseProvider);
  final aiStorage = await ref.watch(aiSettingsStorageProvider.future);
  final webdavStorage = await ref.watch(webdavStorageProvider.future);
  final prefs = await SharedPreferences.getInstance();
  return DataExportService(db, aiStorage, webdavStorage, prefs);
});
