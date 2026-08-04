import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const themeSeedColorPresets = <Color>[
  Color(0xFF2979FF),
  Color(0xFF6750A4),
  Color(0xFF00897B),
  Color(0xFF2E7D32),
  Color(0xFF7CB342),
  Color(0xFFD97706),
  Color(0xFFC62828),
  Color(0xFFAD1457),
  Color(0xFF6D4C41),
  Color(0xFF455A64),
];

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

enum AppLanguageMode {
  system,
  zh,
  en;

  Locale? get locale => switch (this) {
    AppLanguageMode.system => null,
    AppLanguageMode.zh => const Locale('zh'),
    AppLanguageMode.en => const Locale('en'),
  };
}

final languageModeProvider =
    NotifierProvider<LanguageModeNotifier, AppLanguageMode>(
      LanguageModeNotifier.new,
    );

class LanguageModeNotifier extends Notifier<AppLanguageMode> {
  static const _key = 'language_mode';

  @override
  AppLanguageMode build() {
    _load();
    return AppLanguageMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = AppLanguageMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => AppLanguageMode.system,
      );
    }
  }

  Future<void> setLanguageMode(AppLanguageMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final amoledBlackProvider = NotifierProvider<AmoledBlackNotifier, bool>(
  AmoledBlackNotifier.new,
);

class AmoledBlackNotifier extends Notifier<bool> {
  static const _key = 'amoled_black';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final dynamicColorProvider = NotifierProvider<DynamicColorNotifier, bool>(
  DynamicColorNotifier.new,
);

class DynamicColorNotifier extends Notifier<bool> {
  static const _key = 'use_dynamic_color';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final themeSeedColorProvider = NotifierProvider<ThemeSeedColorNotifier, Color>(
  ThemeSeedColorNotifier.new,
);

class ThemeSeedColorNotifier extends Notifier<Color> {
  static const _key = 'theme_seed_color';

  @override
  Color build() {
    _load();
    return themeSeedColorPresets.first;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_key);
    if (value != null) {
      state = Color(value);
    }
  }

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, color.toARGB32());
  }
}
