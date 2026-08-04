import 'package:flashnote/data/services/update_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateSettingsStorage {
  UpdateSettingsStorage({required SharedPreferences prefs}) : _prefs = prefs;

  static const _autoCheckKey = 'auto_check_updates';

  final SharedPreferences _prefs;

  bool get autoCheckUpdates => _prefs.getBool(_autoCheckKey) ?? false;

  Future<void> setAutoCheckUpdates(bool value) =>
      _prefs.setBool(_autoCheckKey, value);
}

final updateSettingsStorageProvider = FutureProvider<UpdateSettingsStorage>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return UpdateSettingsStorage(prefs: prefs);
});

final autoCheckUpdatesProvider = FutureProvider<bool>((ref) async {
  final storage = await ref.watch(updateSettingsStorageProvider.future);
  return storage.autoCheckUpdates;
});

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
