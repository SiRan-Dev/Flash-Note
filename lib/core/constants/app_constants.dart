class AppConstants {
  AppConstants._();

  static const String dbName = 'flashnote.db';

  /// 内置来源 key（数据库存储用，UI 显示通过 AppLocalizations 翻译）
  static const List<String> builtInSourceKeys = [
    'flash',
    'reading',
    'dialogue',
    'observation',
    'problem',
  ];

  static const List<String> builtInSourceIcons = [
    'lightbulb',
    'menu_book',
    'forum',
    'search',
    'flag',
  ];

  static const int recentInspirationLimit = 3;
}
