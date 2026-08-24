import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the Android predictive back gesture.
///
/// When enabled, swiping from the left edge shows a preview of the previous
/// screen before committing the navigation. The setting is persisted and also
/// pushed to the native side so MainActivity can apply it at runtime via
/// ComponentActivity.setEnableOnBackInvokedCallback.
const predictiveBackEnabledKey = 'predictive_back_enabled';

final predictiveBackProvider =
    NotifierProvider<PredictiveBackNotifier, bool>(PredictiveBackNotifier.new);

class PredictiveBackNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(predictiveBackEnabledKey) ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(predictiveBackEnabledKey, value);
  }
}
