class AppConstants {
  AppConstants._();

  static const String dbName = 'flashnote.db';

  /// drift 数据库的目标 schema 版本。
  ///
  /// 迁移前的版本检测和备份逻辑在 native 连接中读取这个常量；修改 schema
  /// 时只需同步更新这里与 `AppDatabase.schemaVersion`。
  static const int schemaVersion = 11;

  /// 迁移前备份文件所在的目录名（位于应用文档目录下）。
  static const String backupDirectoryName = 'flashnote_backups';

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
