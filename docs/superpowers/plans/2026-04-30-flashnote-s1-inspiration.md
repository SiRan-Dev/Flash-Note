# FlashNote S1: 架构骨架 + 灵感管理 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建 FlashNote Flutter 项目骨架，实现灵感 CRUD 和列表管理，应用可独立运行。

**Architecture:** Clean Architecture 三层（Presentation → Domain ← Data），Riverpod 做依赖注入和状态管理，drift 做跨平台 SQLite ORM，go_router 做声明式路由。去掉了 PRD 中的 get_it + injectable，全部用 Riverpod Provider 替代。

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod 2.x, go_router, drift, freezed, Material 3

**S1 简化说明:**
- 底部导航栏使用标准 M3 NavigationBar，PRD 中的「浮动胶囊 + 毛玻璃」效果留到 S4 打磨阶段
- 响应式布局（手机/平板/桌面）留到 S4
- 动态取色留到 S4

---

## File Map

### Domain Layer (纯 Dart)
- `lib/domain/entities/inspiration.dart` — 灵感实体 (freezed)
- `lib/domain/entities/custom_source.dart` — 自定义来源实体 (freezed)
- `lib/domain/repositories/inspiration_repository.dart` — 灵感仓库接口
- `lib/domain/repositories/source_repository.dart` — 来源仓库接口

### Data Layer
- `lib/data/datasources/local/app_database.dart` — drift 数据库定义
- `lib/data/datasources/local/tables/inspiration_table.dart` — inspirations 表
- `lib/data/datasources/local/tables/custom_source_table.dart` — custom_sources 表
- `lib/data/repositories/inspiration_repository_impl.dart` — 灵感仓库实现
- `lib/data/repositories/source_repository_impl.dart` — 来源仓库实现

### Presentation Layer
- `lib/main.dart` — 应用入口
- `lib/app/app.dart` — MaterialApp + ProviderScope
- `lib/app/router.dart` — go_router 路由
- `lib/app/theme/app_theme.dart` — M3 主题定义
- `lib/presentation/pages/home/home_page.dart` — 首页占位
- `lib/presentation/pages/inspiration/inspiration_list_page.dart` — 灵感列表
- `lib/presentation/pages/inspiration/capture_page.dart` — 灵感捕捉/编辑
- `lib/presentation/pages/inspiration/inspiration_detail_page.dart` — 灵感详情
- `lib/presentation/pages/project/project_list_page.dart` — 项目 Tab 占位
- `lib/presentation/pages/settings/settings_page.dart` — 我的 Tab 占位
- `lib/presentation/widgets/shell_page.dart` — Tab 导航 Shell
- `lib/presentation/widgets/inspiration_card.dart` — 灵感卡片
- `lib/presentation/widgets/source_selector.dart` — 来源选择器
- `lib/presentation/widgets/tag_input.dart` — 标签输入组件
- `lib/presentation/providers/database_provider.dart` — 数据库 Provider
- `lib/presentation/providers/inspiration_providers.dart` — 灵感相关 Provider
- `lib/presentation/providers/source_providers.dart` — 来源相关 Provider

### Core
- `lib/core/constants/app_constants.dart` — 应用常量
- `lib/core/error/failures.dart` — 错误类型
- `lib/core/utils/source_mapper.dart` — 来源 key → 本地化名称映射

### i18n
- `l10n.yaml` — l10n 配置
- `lib/l10n/app_zh.arb` — 中文翻译
- `lib/l10n/app_en.arb` — 英文翻译

### Tests
- `test/domain/entities/inspiration_test.dart`
- `test/domain/entities/custom_source_test.dart`
- `test/data/repositories/inspiration_repository_impl_test.dart`
- `test/data/repositories/source_repository_impl_test.dart`
- `test/presentation/widgets/inspiration_card_test.dart`
- `test/presentation/widgets/tag_input_test.dart`

---

## Task 1: Flutter 项目初始化与依赖配置

**Files:**
- Create: `pubspec.yaml` (覆写 `flutter create` 生成的)
- Create: `analysis_options.yaml`

- [ ] **Step 1: 创建 Flutter 项目**

```bash
cd d:\EchoRan\Documents\GitHub\FlashNote
flutter create . --org com.echoran --project-name flashnote --platforms android,ios,macos,windows,linux,web
```

- [ ] **Step 2: 替换 pubspec.yaml 依赖**

```yaml
name: flashnote
description: 闪念 - 灵感捕捉与管理工具
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'
  flutter: '>=3.22.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  go_router: ^14.8.1
  drift: ^2.24.0
  sqlite3_flutter_libs: ^0.5.0
  sqlite3: ^2.7.0
  path_provider: ^2.1.5
  path: ^1.9.1
  shared_preferences: ^2.3.5
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lint: ^5.1.1
  build_runner: ^2.4.15
  drift_dev: ^2.24.0
  freezed: ^2.5.8
  json_serializable: ^6.9.4
  riverpod_generator: ^2.6.3
  mockito: ^5.4.5
  build_verify: ^3.1.0

flutter:
  uses-material-design: true

  generate: true
```

同时创建 `l10n.yaml` 配置文件：

```yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
preferred-supported-locales: ["zh"]
nullable-getter: false
```

- [ ] **Step 3: 配置 analysis_options.yaml**

```yaml
include: package:lint/recommended.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
```

- [ ] **Step 4: 运行 flutter pub get 验证依赖**

```bash
flutter pub get
```

Expected: 所有依赖成功解析，无冲突。

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "chore: 初始化 Flutter 项目，配置 S1 依赖"
```

---

## Task 2: 目录结构与常量

**Files:**
- Create: `lib/core/constants/app_constants.dart`
- Create: `lib/core/error/failures.dart`

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p lib/app/theme
mkdir -p lib/core/constants
mkdir -p lib/core/error
mkdir -p lib/data/datasources/local/tables
mkdir -p lib/data/repositories
mkdir -p lib/domain/entities
mkdir -p lib/domain/repositories
mkdir -p lib/presentation/pages/home
mkdir -p lib/presentation/pages/inspiration
mkdir -p lib/presentation/pages/project
mkdir -p lib/presentation/pages/settings
mkdir -p lib/presentation/providers
mkdir -p lib/presentation/widgets
mkdir -p test/domain/entities
mkdir -p test/data/repositories
mkdir -p test/presentation/widgets
```

- [ ] **Step 2: 创建 app_constants.dart**

```dart
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
```

- [ ] **Step 3: 创建 failures.dart**

```dart
sealed class Failure {
  const Failure(this.message);
  final String message;
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}
```

- [ ] **Step 4: 提交**

```bash
git add lib/core/
git commit -m "feat: 添加目录结构、常量定义和错误类型"
```

---

## Task 3: 国际化 (i18n) 搭建

**Files:**
- Create: `l10n.yaml`
- Create: `lib/l10n/app_zh.arb`
- Create: `lib/l10n/app_en.arb`

- [ ] **Step 1: 创建 l10n.yaml 配置**

```yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
preferred-supported-locales: ["zh"]
nullable-getter: false
```

- [ ] **Step 2: 创建中文 ARB 文件**

```json
{
  "@@locale": "zh",
  "appName": "闪念",
  "appTagline": "捕捉每一个灵感",
  "home": "首页",
  "inspirations": "灵感",
  "projects": "项目",
  "settings": "我的",
  "captureInspiration": "捕捉灵感",
  "editInspiration": "编辑灵感",
  "writeInspiration": "写下你的灵感...",
  "inspirationSource": "灵感来源（可选）",
  "tags": "标签（可选）",
  "tagHint": "输入标签，回车添加",
  "save": "保存",
  "cancel": "取消",
  "delete": "删除",
  "pin": "置顶",
  "unpin": "取消置顶",
  "deleteInspiration": "删除灵感",
  "deleteInspirationConfirm": "确定要删除这条灵感吗？",
  "searchInspiration": "搜索灵感...",
  "noMatchFound": "没有找到匹配的灵感",
  "noInspirationYet": "还没有灵感，快去捕捉吧！",
  "all": "全部",
  "aiCapabilities": "AI 能力",
  "aiAnalysis": "AI 分析",
  "aiAnalysisDesc": "评估可行性、潜力和风险",
  "mindMap": "思维导图",
  "mindMapDesc": "AI 生成思维导图",
  "aiChat": "AI 对话",
  "aiChatDesc": "深度探讨灵感",
  "createProject": "创建项目",
  "createProjectDesc": "将灵感转化为项目",
  "catchEveryInspiration": "随时记录你的灵感",
  "contentEmpty": "灵感内容不能为空",
  "sourceFlash": "突发奇想",
  "sourceReading": "阅读启发",
  "sourceDialogue": "对话碰撞",
  "sourceObservation": "观察发现",
  "sourceProblem": "问题驱动",
  "inspirationNotFound": "灵感不存在",
  "loadFailed": "加载失败",
  "projectComingSoon": "项目管理即将上线",
  "projectComingSoonDesc": "S3 阶段实现",
  "developer": "开发者",
  "version": "版本"
}
```

- [ ] **Step 3: 创建英文 ARB 文件**

```json
{
  "@@locale": "en",
  "appName": "FlashNote",
  "appTagline": "Capture Every Inspiration",
  "home": "Home",
  "inspirations": "Ideas",
  "projects": "Projects",
  "settings": "Me",
  "captureInspiration": "Capture Idea",
  "editInspiration": "Edit Idea",
  "writeInspiration": "Write down your inspiration...",
  "inspirationSource": "Source (optional)",
  "tags": "Tags (optional)",
  "tagHint": "Type a tag, press Enter to add",
  "save": "Save",
  "cancel": "Cancel",
  "delete": "Delete",
  "pin": "Pin",
  "unpin": "Unpin",
  "deleteInspiration": "Delete Idea",
  "deleteInspirationConfirm": "Are you sure you want to delete this idea?",
  "searchInspiration": "Search ideas...",
  "noMatchFound": "No matching ideas found",
  "noInspirationYet": "No ideas yet. Go capture one!",
  "all": "All",
  "aiCapabilities": "AI Capabilities",
  "aiAnalysis": "AI Analysis",
  "aiAnalysisDesc": "Evaluate feasibility, potential, and risk",
  "mindMap": "Mind Map",
  "mindMapDesc": "AI-generated mind map",
  "aiChat": "AI Chat",
  "aiChatDesc": "Deep-dive discussion",
  "createProject": "Create Project",
  "createProjectDesc": "Turn inspiration into a project",
  "catchEveryInspiration": "Capture your inspiration anytime",
  "contentEmpty": "Idea content cannot be empty",
  "sourceFlash": "Flash Idea",
  "sourceReading": "Reading",
  "sourceDialogue": "Dialogue",
  "sourceObservation": "Observation",
  "sourceProblem": "Problem-driven",
  "inspirationNotFound": "Idea not found",
  "loadFailed": "Failed to load",
  "projectComingSoon": "Project management coming soon",
  "projectComingSoonDesc": "Coming in Stage S3",
  "developer": "Developer",
  "version": "Version"
}
```

- [ ] **Step 4: 生成 l10n 代码并验证**

```bash
flutter gen-l10n
```

Expected: 生成 `.dart_tool/flutter_gen/gen_l10n/` 下的本地化文件。

- [ ] **Step 5: 提交**

```bash
git add l10n.yaml lib/l10n/
git commit -m "feat: 添加 i18n 支持（中文/英文 ARB 文件）"
```

---

## Task 4: Domain 层 — 灵感实体

**Files:**
- Create: `lib/domain/entities/inspiration.dart`
- Create: `test/domain/entities/inspiration_test.dart`

- [ ] **Step 1: 写灵感实体测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flashnote/domain/entities/inspiration.dart';

void main() {
  group('Inspiration', () {
    test('创建默认灵感', () {
      final now = DateTime.now();
      final inspiration = Inspiration(
        id: 0,
        content: '测试灵感',
        createdAt: now,
        updatedAt: now,
      );

      expect(inspiration.content, '测试灵感');
      expect(inspiration.source, isNull);
      expect(inspiration.tags, isEmpty);
      expect(inspiration.aiAnalysis, isNull);
      expect(inspiration.isPinned, false);
    });

    test('copyWith 修改内容', () {
      final now = DateTime.now();
      final original = Inspiration(
        id: 1,
        content: '原始内容',
        createdAt: now,
        updatedAt: now,
      );

      final copied = original.copyWith(content: '修改后内容', isPinned: true);

      expect(copied.content, '修改后内容');
      expect(copied.isPinned, true);
      expect(copied.id, 1);
    });

    test('tags JSON 序列化', () {
      final now = DateTime.now();
      final inspiration = Inspiration(
        id: 1,
        content: '测试',
        tags: ['标签1', '标签2'],
        createdAt: now,
        updatedAt: now,
      );

      expect(inspiration.tagsJson, '["标签1","标签2"]');
    });

    test('tags 从 JSON 反序列化', () {
      final result = Inspiration.tagsFromJson('["标签1","标签2"]');
      expect(result, ['标签1', '标签2']);
    });

    test('tags 空 JSON 返回空列表', () {
      final result = Inspiration.tagsFromJson('[]');
      expect(result, isEmpty);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/domain/entities/inspiration_test.dart
```

Expected: FAIL — `Inspiration` 类未定义。

- [ ] **Step 3: 实现灵感实体**

```dart
import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'inspiration.freezed.dart';
part 'inspiration.g.dart';

@freezed
class Inspiration with _$Inspiration {
  const Inspiration._();

  const factory Inspiration({
    required int id,
    required String content,
    String? source,
    @Default([]) List<String> tags,
    String? aiAnalysis,
    @Default(false) bool isPinned,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Inspiration;

  factory Inspiration.fromJson(Map<String, dynamic> json) =>
      _$InspirationFromJson(json);

  String get tagsJson => jsonEncode(tags);

  static List<String> tagsFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list.map((e) => e.toString()).toList();
  }
}
```

- [ ] **Step 4: 运行代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: 生成 `inspiration.freezed.dart` 和 `inspiration.g.dart`。

- [ ] **Step 5: 运行测试确认通过**

```bash
flutter test test/domain/entities/inspiration_test.dart
```

Expected: 全部 PASS。

- [ ] **Step 6: 提交**

```bash
git add lib/domain/entities/inspiration.dart lib/domain/entities/inspiration.freezed.dart lib/domain/entities/inspiration.g.dart test/domain/entities/inspiration_test.dart
git commit -m "feat: 添加灵感实体 (freezed)，包含 tags JSON 序列化"
```

---

## Task 5: Domain 层 — 自定义来源实体

**Files:**
- Create: `lib/domain/entities/custom_source.dart`
- Create: `test/domain/entities/custom_source_test.dart`

- [ ] **Step 1: 写自定义来源实体测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flashnote/domain/entities/custom_source.dart';

void main() {
  group('CustomSource', () {
    test('创建来源', () {
      final source = CustomSource(
        id: 1,
        name: '播客启发',
        icon: 'headphones',
        sortOrder: 0,
        createdAt: DateTime(2026, 4, 30),
      );

      expect(source.name, '播客启发');
      expect(source.icon, 'headphones');
      expect(source.isBuiltIn, false);
    });

    test('内置来源标记', () {
      final source = CustomSource(
        id: 0,
        name: '突发奇想',
        icon: 'lightbulb',
        sortOrder: 0,
        isBuiltIn: true,
        createdAt: DateTime(2026, 4, 30),
      );

      expect(source.isBuiltIn, true);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/domain/entities/custom_source_test.dart
```

Expected: FAIL — `CustomSource` 类未定义。

- [ ] **Step 3: 实现自定义来源实体**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'custom_source.freezed.dart';
part 'custom_source.g.dart';

@freezed
class CustomSource with _$CustomSource {
  const factory CustomSource({
    required int id,
    required String name,
    required String icon,
    @Default(0) int sortOrder,
    @Default(false) bool isBuiltIn,
    required DateTime createdAt,
  }) = _CustomSource;

  factory CustomSource.fromJson(Map<String, dynamic> json) =>
      _$CustomSourceFromJson(json);
}
```

- [ ] **Step 4: 运行代码生成并测试**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/domain/entities/custom_source_test.dart
```

Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/domain/entities/custom_source.dart lib/domain/entities/custom_source.freezed.dart lib/domain/entities/custom_source.g.dart test/domain/entities/custom_source_test.dart
git commit -m "feat: 添加自定义来源实体 (freezed)"
```

---

## Task 6: Domain 层 — Repository 接口

**Files:**
- Create: `lib/domain/repositories/inspiration_repository.dart`
- Create: `lib/domain/repositories/source_repository.dart`

- [ ] **Step 1: 创建灵感仓库接口**

```dart
import 'package:flashnote/domain/entities/inspiration.dart';

abstract class InspirationRepository {
  Future<List<Inspiration>> getAll();
  Future<List<Inspiration>> search(String query);
  Future<List<Inspiration>> filterBySource(String? source);
  Future<Inspiration?> getById(int id);
  Future<int> create(String content, {String? source, List<String> tags});
  Future<void> update(Inspiration inspiration);
  Future<void> delete(int id);
  Future<void> togglePin(int id);
}
```

- [ ] **Step 2: 创建来源仓库接口**

```dart
import 'package:flashnote/domain/entities/custom_source.dart';

abstract class SourceRepository {
  Future<List<CustomSource>> getAll();
  Future<int> create(String name, String icon);
  Future<void> update(CustomSource source);
  Future<void> delete(int id);
  Future<void> seedBuiltInSources();
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/domain/repositories/
git commit -m "feat: 添加灵感和来源 Repository 接口"
```

---

## Task 8: Data 层 — drift 数据库表定义

**Files:**
- Create: `lib/data/datasources/local/tables/inspiration_table.dart`
- Create: `lib/data/datasources/local/tables/custom_source_table.dart`

- [ ] **Step 1: 创建灵感表定义**

```dart
import 'package:drift/drift.dart';

class Inspirations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text().withLength(min: 1)();
  TextColumn get source => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get aiAnalysis => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}
```

- [ ] **Step 2: 创建自定义来源表定义**

```dart
import 'package:drift/drift.dart';

class CustomSources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get icon => text().withLength(min: 1)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/data/datasources/local/tables/
git commit -m "feat: 添加 drift 数据库表定义 (inspirations, custom_sources)"
```

---

## Task 8: Data 层 — drift 数据库

**Files:**
- Create: `lib/data/datasources/local/app_database.dart`
- Create: `lib/presentation/providers/database_provider.dart`

- [ ] **Step 1: 创建数据库定义**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flashnote/core/constants/app_constants.dart';
import 'tables/inspiration_table.dart';
import 'tables/custom_source_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Inspirations, CustomSources])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
      );

  // === Inspirations ===

  Future<List<Inspiration>> getAllInspirations() =>
      (select(inspirations)..orderBy([
        (t) => OrderingTerm.desc(t.isPinned),
        (t) => OrderingTerm.desc(t.createdAt),
      ])).get();

  Future<List<Inspiration>> searchInspirations(String query) =>
      (select(inspirations)
            ..where((t) => t.content.like('%$query%'))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .get();

  Future<List<Inspiration>> filterBySource(String? source) {
    if (source == null) return getAllInspirations();
    return (select(inspirations)
          ..where((t) => t.source.equals(source))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .get();
  }

  Future<Inspiration?> getInspirationById(int id) =>
      (select(inspirations)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertInspiration(InspirationsCompanion entry) =>
      into(inspirations).insert(entry);

  Future<bool> updateInspiration(InspirationsCompanion entry) =>
      update(inspirations).replace(entry);

  Future<int> deleteInspiration(int id) =>
      (delete(inspirations)..where((t) => t.id.equals(id))).go();

  // === CustomSources ===

  Future<List<CustomSource>> getAllSources() =>
      (select(customSources)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<int> insertSource(CustomSourcesCompanion entry) =>
      into(customSources).insert(entry);

  Future<bool> updateSource(CustomSourcesCompanion entry) =>
      update(customSources).replace(entry);

  Future<int> deleteSource(int id) =>
      (delete(customSources)..where((t) => t.id.equals(id))).go();

  Future<int> deleteAllSources() => delete(customSources).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, AppConstants.dbName));
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 2: 运行 drift 代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: 生成 `app_database.g.dart`。

- [ ] **Step 3: 创建数据库 Provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
```

- [ ] **Step 4: 提交**

```bash
git add lib/data/datasources/local/app_database.dart lib/data/datasources/local/app_database.g.dart lib/presentation/providers/database_provider.dart
git commit -m "feat: 添加 drift 数据库定义和 Provider"
```

---

## Task 9: Data 层 — Repository 实现

**Files:**
- Create: `lib/data/repositories/inspiration_repository_impl.dart`
- Create: `lib/data/repositories/source_repository_impl.dart`
- Create: `test/data/repositories/inspiration_repository_impl_test.dart`
- Create: `test/data/repositories/source_repository_impl_test.dart`

- [ ] **Step 1: 写灵感仓库测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/repositories/inspiration_repository_impl.dart';

void main() {
  late AppDatabase db;
  late InspirationRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = InspirationRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  test('创建灵感并获取', () async {
    final id = await repo.create('测试灵感内容');
    final inspiration = await repo.getById(id);

    expect(inspiration, isNotNull);
    expect(inspiration!.content, '测试灵感内容');
    expect(inspiration.isPinned, false);
    expect(inspiration.tags, isEmpty);
  });

  test('创建带来源和标签的灵感', () async {
    final id = await repo.create('灵感', source: '阅读启发', tags: ['标签A']);
    final inspiration = await repo.getById(id);

    expect(inspiration!.source, '阅读启发');
    expect(inspiration.tags, ['标签A']);
  });

  test('获取所有灵感按置顶和时间排序', () async {
    await repo.create('第一条');
    final id2 = await repo.create('第二条');
    await repo.togglePin(id2);

    final list = await repo.getAll();

    expect(list.first.id, id2);
    expect(list.first.isPinned, true);
  });

  test('搜索灵感', () async {
    await repo.create('Flutter 开发');
    await repo.create('AI 灵感');
    await repo.create('Flutter 布局技巧');

    final results = await repo.search('Flutter');

    expect(results.length, 2);
  });

  test('按来源筛选', () async {
    await repo.create('灵感A', source: '阅读启发');
    await repo.create('灵感B', source: '对话碰撞');
    await repo.create('灵感C');

    final results = await repo.filterBySource('阅读启发');

    expect(results.length, 1);
    expect(results.first.source, '阅读启发');
  });

  test('更新灵感', () async {
    final id = await repo.create('原始内容');
    final original = await repo.getById(id);

    await repo.update(original!.copyWith(content: '更新后内容'));

    final updated = await repo.getById(id);
    expect(updated!.content, '更新后内容');
  });

  test('删除灵感', () async {
    final id = await repo.create('待删除');
    await repo.delete(id);

    final result = await repo.getById(id);
    expect(result, isNull);
  });

  test('切换置顶', () async {
    final id = await repo.create('测试');
    await repo.togglePin(id);

    final inspiration = await repo.getById(id);
    expect(inspiration!.isPinned, true);

    await repo.togglePin(id);
    final toggled = await repo.getById(id);
    expect(toggled!.isPinned, false);
  });

  test('获取不存在的灵感返回 null', () async {
    final result = await repo.getById(999);
    expect(result, isNull);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/data/repositories/inspiration_repository_impl_test.dart
```

Expected: FAIL — `InspirationRepositoryImpl` 未定义。

- [ ] **Step 3: 实现灵感仓库**

```dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/domain/repositories/inspiration_repository.dart';

class InspirationRepositoryImpl implements InspirationRepository {
  InspirationRepositoryImpl(this._db);

  final AppDatabase _db;

  // drift row 直接就是数据对象，这里做简化映射
  Inspiration _fromRow(dynamic row) {
    return Inspiration(
      id: row.id,
      content: row.content,
      source: row.source,
      tags: row.tags == '[]' ? [] : Inspiration.tagsFromJson(row.tags),
      aiAnalysis: row.aiAnalysis,
      isPinned: row.isPinned,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  @override
  Future<List<Inspiration>> getAll() async {
    final rows = await _db.getAllInspirations();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Inspiration>> search(String query) async {
    final rows = await _db.searchInspirations(query);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Inspiration>> filterBySource(String? source) async {
    final rows = await _db.filterBySource(source);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Inspiration?> getById(int id) async {
    final row = await _db.getInspirationById(id);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<int> create(String content, {String? source, List<String> tags = const []}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.insertInspiration(InspirationsCompanion(
      content: Value(content),
      source: Value.absentIfNull(source),
      tags: Value(jsonEncode(tags)),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  @override
  Future<void> update(Inspiration inspiration) async {
    await _db.updateInspiration(InspirationsCompanion(
      id: Value(inspiration.id),
      content: Value(inspiration.content),
      source: Value.absentIfNull(inspiration.source),
      tags: Value(inspiration.tagsJson),
      aiAnalysis: Value.absentIfNull(inspiration.aiAnalysis),
      isPinned: Value(inspiration.isPinned),
      createdAt: Value(inspiration.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  @override
  Future<void> delete(int id) => _db.deleteInspiration(id);

  @override
  Future<void> togglePin(int id) async {
    final inspiration = await getById(id);
    if (inspiration == null) return;
    await update(inspiration.copyWith(isPinned: !inspiration.isPinned));
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/data/repositories/inspiration_repository_impl_test.dart
```

Expected: 全部 PASS。

- [ ] **Step 5: 写来源仓库测试并实现**

来源仓库测试：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/repositories/source_repository_impl.dart';
import 'package:flashnote/core/constants/app_constants.dart';

void main() {
  late AppDatabase db;
  late SourceRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = SourceRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  test('初始化内置来源', () async {
    await repo.seedBuiltInSources();

    final sources = await repo.getAll();
    expect(sources.length, AppConstants.builtInSourceKeys.length);
    expect(sources.first.name, 'flash'); // 存储 key
    expect(sources.first.isBuiltIn, true);
  });

  test('创建自定义来源', () async {
    final id = await repo.create('播客启发', 'headphones');
    final sources = await repo.getAll();

    expect(sources.length, 1);
    expect(sources.first.name, '播客启发');
    expect(sources.first.isBuiltIn, false);
  });

  test('删除自定义来源', () async {
    final id = await repo.create('测试来源', 'star');
    await repo.delete(id);

    final sources = await repo.getAll();
    expect(sources, isEmpty);
  });

  test('不重复添加内置来源', () async {
    await repo.seedBuiltInSources();
    await repo.seedBuiltInSources();

    final sources = await repo.getAll();
    expect(sources.length, AppConstants.builtInSourceKeys.length);
  });
}
```

来源仓库实现：

```dart
import 'package:drift/drift.dart';
import 'package:flashnote/core/constants/app_constants.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/domain/entities/custom_source.dart';
import 'package:flashnote/domain/repositories/source_repository.dart';

class SourceRepositoryImpl implements SourceRepository {
  SourceRepositoryImpl(this._db);

  final AppDatabase _db;

  CustomSource _fromRow(dynamic row) {
    return CustomSource(
      id: row.id,
      name: row.name,
      icon: row.icon,
      sortOrder: row.sortOrder,
      isBuiltIn: row.isBuiltIn,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }

  @override
  Future<List<CustomSource>> getAll() async {
    final rows = await _db.getAllSources();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> create(String name, String icon) {
    return _db.insertSource(CustomSourcesCompanion(
      name: Value(name),
      icon: Value(icon),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  @override
  Future<void> update(CustomSource source) async {
    await _db.updateSource(CustomSourcesCompanion(
      id: Value(source.id),
      name: Value(source.name),
      icon: Value(source.icon),
      sortOrder: Value(source.sortOrder),
    ));
  }

  @override
  Future<void> delete(int id) => _db.deleteSource(id);

  @override
  Future<void> seedBuiltInSources() async {
    final existing = await getAll();
    if (existing.isNotEmpty) return;

    for (var i = 0; i < AppConstants.builtInSourceKeys.length; i++) {
      await _db.insertSource(CustomSourcesCompanion(
        name: Value(AppConstants.builtInSourceKeys[i]), // 存 key，UI 层翻译
        icon: Value(AppConstants.builtInSourceIcons[i]),
        sortOrder: Value(i),
        isBuiltIn: const Value(true),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    }
  }
}
```

同时添加一个工具方法，将 source key 映射到本地化名称：

```dart
// lib/core/utils/source_mapper.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SourceMapper {
  SourceMapper._();

  static String displayName(BuildContext context, String sourceKey) {
    final l10n = AppLocalizations.of(context);
    switch (sourceKey) {
      case 'flash':
        return l10n.sourceFlash;
      case 'reading':
        return l10n.sourceReading;
      case 'dialogue':
        return l10n.sourceDialogue;
      case 'observation':
        return l10n.sourceObservation;
      case 'problem':
        return l10n.sourceProblem;
      default:
        return sourceKey; // 自定义来源直接显示原名
    }
  }
}
```

在 `SourceSelector` 和 `InspirationCard` 中使用 `SourceMapper.displayName(context, source.name)` 替代直接显示 `source.name`。

- [ ] **Step 6: 运行全部测试**

```bash
flutter test test/data/repositories/
```

Expected: 全部 PASS。

- [ ] **Step 7: 提交**

```bash
git add lib/data/repositories/ test/data/repositories/
git commit -m "feat: 添加灵感和来源 Repository 实现及测试"
```

---

## Task 10: Presentation 层 — Riverpod Providers

**Files:**
- Create: `lib/presentation/providers/inspiration_providers.dart`
- Create: `lib/presentation/providers/source_providers.dart`

- [ ] **Step 1: 创建灵感 Provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashnote/data/repositories/inspiration_repository_impl.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/domain/repositories/inspiration_repository.dart';
import 'database_provider.dart';

final inspirationRepositoryProvider = Provider<InspirationRepository>((ref) {
  return InspirationRepositoryImpl(ref.watch(databaseProvider));
});

final inspirationListProvider =
    AsyncNotifierProvider<InspirationListNotifier, List<Inspiration>>(
        InspirationListNotifier.new);

class InspirationListNotifier extends AsyncNotifier<List<Inspiration>> {
  @override
  Future<List<Inspiration>> build() {
    return ref.read(inspirationRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(inspirationRepositoryProvider).getAll());
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = await AsyncValue.guard(
          () => ref.read(inspirationRepositoryProvider).getAll());
    } else {
      state = await AsyncValue.guard(
          () => ref.read(inspirationRepositoryProvider).search(query));
    }
  }

  Future<void> filterBySource(String? source) async {
    state = await AsyncValue.guard(
        () => ref.read(inspirationRepositoryProvider).filterBySource(source));
  }

  Future<void> delete(int id) async {
    await ref.read(inspirationRepositoryProvider).delete(id);
    await refresh();
  }

  Future<void> togglePin(int id) async {
    await ref.read(inspirationRepositoryProvider).togglePin(id);
    await refresh();
  }
}
```

- [ ] **Step 2: 创建来源 Provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flashnote/data/repositories/source_repository_impl.dart';
import 'package:flashnote/domain/entities/custom_source.dart';
import 'package:flashnote/domain/repositories/source_repository.dart';
import 'database_provider.dart';

final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  return SourceRepositoryImpl(ref.watch(databaseProvider));
});

final sourceListProvider =
    AsyncNotifierProvider<SourceListNotifier, List<CustomSource>>(
        SourceListNotifier.new);

class SourceListNotifier extends AsyncNotifier<List<CustomSource>> {
  @override
  Future<List<CustomSource>> build() async {
    final repo = ref.read(sourceRepositoryProvider);
    await repo.seedBuiltInSources();
    return repo.getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(sourceRepositoryProvider).getAll());
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/presentation/providers/
git commit -m "feat: 添加灵感和来源 Riverpod Provider"
```

---

## Task 11: 主题系统

**Files:**
- Create: `lib/app/theme/app_theme.dart`

- [ ] **Step 1: 创建 M3 主题**

```dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF2979FF);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return _build(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return _build(colorScheme);
  }

  static ThemeData _build(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Noto Sans SC',
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        height: 64,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/app/theme/
git commit -m "feat: 添加 Material 3 主题系统（浅色/深色）"
```

---

## Task 12: 路由与应用壳

**Files:**
- Create: `lib/app/router.dart`
- Create: `lib/presentation/widgets/shell_page.dart`
- Create: `lib/app/app.dart`
- Create: `lib/main.dart`

- [ ] **Step 1: 创建路由配置**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flashnote/presentation/pages/home/home_page.dart';
import 'package:flashnote/presentation/pages/inspiration/inspiration_list_page.dart';
import 'package:flashnote/presentation/pages/inspiration/capture_page.dart';
import 'package:flashnote/presentation/pages/inspiration/inspiration_detail_page.dart';
import 'package:flashnote/presentation/pages/project/project_list_page.dart';
import 'package:flashnote/presentation/pages/settings/settings_page.dart';
import 'package:flashnote/presentation/widgets/shell_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ShellPage(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomePage(),
          ),
        ),
        GoRoute(
          path: '/inspirations',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: InspirationListPage(),
          ),
        ),
        GoRoute(
          path: '/projects',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProjectListPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsPage(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/inspiration/new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CapturePage(),
    ),
    GoRoute(
      path: '/inspiration/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return InspirationDetailPage(id: id);
      },
      routes: [
        GoRoute(
          path: 'edit',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return CapturePage(editId: id);
          },
        ),
      ],
    ),
  ],
);
```

- [ ] **Step 2: 创建 Shell 页面（底部导航）**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.child});

  final Widget child;

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/inspirations')) return 1;
    if (location.startsWith('/projects')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/inspirations');
      case 2:
        context.go('/projects');
      case 3:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getCurrentIndex(context),
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.lightbulb_outline_rounded),
            selectedIcon: const Icon(Icons.lightbulb_rounded),
            label: l10n.inspirations,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder_rounded),
            label: l10n.projects,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 创建 App 入口**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class FlashNoteApp extends StatelessWidget {
  const FlashNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: '闪念',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh'),
          Locale('en'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 创建 main.dart**

```dart
import 'package:flutter/material.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlashNoteApp());
}
```

- [ ] **Step 5: 运行应用验证编译**

```bash
flutter run -d windows --debug
```

Expected: 应用启动，显示 4 个 Tab 的底部导航栏，可以切换。

- [ ] **Step 6: 提交**

```bash
git add lib/app/ lib/main.dart lib/presentation/widgets/shell_page.dart
git commit -m "feat: 添加路由、底部导航 Shell 和应用入口"
```

---

## Task 13: 占位页面（首页、项目、我的）

**Files:**
- Create: `lib/presentation/pages/home/home_page.dart`
- Create: `lib/presentation/pages/project/project_list_page.dart`
- Create: `lib/presentation/pages/settings/settings_page.dart`

- [ ] **Step 1: 创建首页占位**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dateStr = DateFormat.yMMMMd(l10n.localeName).format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateStr, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(l10n.appName, style: theme.textTheme.displaySmall),
              Text(l10n.appTagline, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(l10n.catchEveryInspiration,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push('/inspiration/new'),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.captureInspiration),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建项目 Tab 占位**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ProjectListPage extends StatelessWidget {
  const ProjectListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.projects)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(l10n.projectComingSoon, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.projectComingSoonDesc, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 创建我的 Tab 占位**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(l10n.appName, style: theme.textTheme.titleLarge),
                Text('v1.0.0', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('${l10n.developer}: EchoRan', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 验证编译**

```bash
flutter run -d windows --debug
```

Expected: 4 个 Tab 都能切换，各自显示对应内容。

- [ ] **Step 5: 提交**

```bash
git add lib/presentation/pages/home/ lib/presentation/pages/project/ lib/presentation/pages/settings/
git commit -m "feat: 添加首页、项目 Tab、我的 Tab 占位页面"
```

---

## Task 14: 灵感卡片组件

**Files:**
- Create: `lib/presentation/widgets/inspiration_card.dart`
- Create: `test/presentation/widgets/inspiration_card_test.dart`

- [ ] **Step 1: 写灵感卡片 Widget 测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/presentation/widgets/inspiration_card.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  final now = DateTime(2026, 4, 30, 12, 0);
  final testInspiration = Inspiration(
    id: 1,
    content: 'Test inspiration content for card display.',
    source: 'reading',
    tags: ['Flutter', 'dev'],
    isPinned: false,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('灵感卡片显示内容摘要', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      InspirationCard(
        inspiration: testInspiration,
        onTap: () {},
      ),
    ));

    expect(find.text('Test inspiration content for card display.'), findsOneWidget);
  });

  testWidgets('灵感卡片显示来源', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      InspirationCard(
        inspiration: testInspiration,
        onTap: () {},
      ),
    ));

    expect(find.text('reading'), findsOneWidget);
  });

  testWidgets('灵感卡片显示标签', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      InspirationCard(
        inspiration: testInspiration,
        onTap: () {},
      ),
    ));

    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('dev'), findsOneWidget);
  });

  testWidgets('置顶灵感显示置顶图标', (tester) async {
    final pinned = testInspiration.copyWith(isPinned: true);

    await tester.pumpWidget(_buildTestApp(
      InspirationCard(
        inspiration: pinned,
        onTap: () {},
      ),
    ));

    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
  });

  testWidgets('无来源时不显示来源 Chip', (tester) async {
    final noSource = testInspiration.copyWith(source: null);

    await tester.pumpWidget(_buildTestApp(
      InspirationCard(
        inspiration: noSource,
        onTap: () {},
      ),
    ));

    expect(find.text('reading'), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/presentation/widgets/inspiration_card_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现灵感卡片**

```dart
import 'package:flutter/material.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:intl/intl.dart';

class InspirationCard extends StatelessWidget {
  const InspirationCard({
    super.key,
    required this.inspiration,
    required this.onTap,
  });

  final Inspiration inspiration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MM/dd HH:mm').format(inspiration.createdAt);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (inspiration.isPinned) ...[
                    Icon(Icons.push_pin_rounded,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                  ],
                  if (inspiration.source != null) ...[
                    Chip(
                      label: Text(inspiration.source!,
                          style: theme.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  Text(dateStr, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                inspiration.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              if (inspiration.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: inspiration.tags
                      .map((tag) => Chip(
                            label: Text(tag,
                                style: theme.textTheme.labelSmall),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/presentation/widgets/inspiration_card_test.dart
```

Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/presentation/widgets/inspiration_card.dart test/presentation/widgets/inspiration_card_test.dart
git commit -m "feat: 添加灵感卡片组件及 Widget 测试"
```

---

## Task 15: 来源选择器与标签输入组件

**Files:**
- Create: `lib/presentation/widgets/source_selector.dart`
- Create: `lib/presentation/widgets/tag_input.dart`
- Create: `test/presentation/widgets/tag_input_test.dart`

- [ ] **Step 1: 创建来源选择器**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flashnote/domain/entities/custom_source.dart';
import 'package:flashnote/presentation/providers/source_providers.dart';

class SourceSelector extends ConsumerWidget {
  const SourceSelector({
    super.key,
    this.selectedSource,
    required this.onSelected,
  });

  final String? selectedSource;
  final ValueChanged<String?> onSelected;

  IconData _iconForName(String iconName) {
    switch (iconName) {
      case 'lightbulb':
        return Icons.lightbulb_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'forum':
        return Icons.forum_rounded;
      case 'search':
        return Icons.search_rounded;
      case 'flag':
        return Icons.flag_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourceListProvider);

    return sourcesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('${AppLocalizations.of(context).loadFailed}: $e'),
      data: (sources) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          FilterChip(
            label: Text(AppLocalizations.of(context).all),
            selected: selectedSource == null,
            onSelected: (_) => onSelected(null),
          ),
          ...sources.map((source) => FilterChip(
                avatar: Icon(_iconForName(source.icon), size: 18),
                label: Text(source.name),
                selected: selectedSource == source.name,
                onSelected: (_) => onSelected(
                    selectedSource == source.name ? null : source.name),
              )),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 写标签输入测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flashnote/presentation/widgets/tag_input.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('输入标签并回车添加', (tester) async {
    List<String> tags = [];

    await tester.pumpWidget(_buildTestApp(
      TagInput(
        tags: tags,
        onChanged: (newTags) => tags = newTags,
      ),
    ));

    await tester.enterText(find.byType(TextField), '新标签');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('新标签'), findsOneWidget);
  });

  testWidgets('已有标签显示为 Chip', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      TagInput(
        tags: const ['tagA', 'tagB'],
        onChanged: (_) {},
      ),
    ));

    expect(find.text('tagA'), findsOneWidget);
    expect(find.text('tagB'), findsOneWidget);
  });

  testWidgets('点击删除按钮移除标签', (tester) async {
    List<String> tags = ['toDelete'];

    await tester.pumpWidget(_buildTestApp(
      StatefulBuilder(
        builder: (context, setState) => TagInput(
          tags: tags,
          onChanged: (newTags) => setState(() => tags = newTags),
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(tags, isEmpty);
  });
}
```

- [ ] **Step 3: 运行测试确认失败**

```bash
flutter test test/presentation/widgets/tag_input_test.dart
```

Expected: FAIL。

- [ ] **Step 4: 实现标签输入**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TagInput extends StatefulWidget {
  const TagInput({
    super.key,
    required this.tags,
    required this.onChanged,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();

  void _addTag() {
    final tag = _controller.text.trim();
    if (tag.isEmpty || widget.tags.contains(tag)) return;
    widget.onChanged([...widget.tags, tag]);
    _controller.clear();
  }

  void _removeTag(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: widget.tags
              .map((tag) => Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeTag(tag),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).tagHint,
            isDense: true,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addTag(),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: 运行测试确认通过**

```bash
flutter test test/presentation/widgets/tag_input_test.dart
```

Expected: 全部 PASS。

- [ ] **Step 6: 提交**

```bash
git add lib/presentation/widgets/source_selector.dart lib/presentation/widgets/tag_input.dart test/presentation/widgets/tag_input_test.dart
git commit -m "feat: 添加来源选择器和标签输入组件"
```

---

## Task 16: 灵感捕捉/编辑页面

**Files:**
- Create: `lib/presentation/pages/inspiration/capture_page.dart`

- [ ] **Step 1: 实现灵感捕捉页面**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/widgets/source_selector.dart';
import 'package:flashnote/presentation/widgets/tag_input.dart';

class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key, this.editId});

  final int? editId;

  bool get isEditing => editId != null;

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String? _selectedSource;
  List<String> _tags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadInspiration();
    }
  }

  Future<void> _loadInspiration() async {
    setState(() => _isLoading = true);
    final repo = ref.read(inspirationRepositoryProvider);
    final inspiration = await repo.getById(widget.editId!);
    if (inspiration != null && mounted) {
      setState(() {
        _contentController.text = inspiration.content;
        _selectedSource = inspiration.source;
        _tags = List.from(inspiration.tags);
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(inspirationRepositoryProvider);

    if (widget.isEditing) {
      final original = await repo.getById(widget.editId!);
      if (original == null) return;
      await repo.update(original.copyWith(
        content: _contentController.text.trim(),
        source: _selectedSource,
        tags: _tags,
      ));
    } else {
      await repo.create(
        _contentController.text.trim(),
        source: _selectedSource,
        tags: _tags,
      );
    }

    ref.read(inspirationListProvider.notifier).refresh();

    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l10n.editInspiration : l10n.captureInspiration),
        actions: [
          FilledButton(
            onPressed: _save,
            child: Text(l10n.save),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        hintText: l10n.writeInspiration,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 8,
                      minLines: 4,
                      autofocus: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.contentEmpty;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(l10n.inspirationSource,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SourceSelector(
                      selectedSource: _selectedSource,
                      onSelected: (source) =>
                          setState(() => _selectedSource = source),
                    ),
                    const SizedBox(height: 24),
                    Text(l10n.tags,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TagInput(
                      tags: _tags,
                      onChanged: (tags) => setState(() => _tags = tags),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
flutter run -d windows --debug
```

Expected: 从首页点击「捕捉灵感」可打开此页面，输入内容后保存。

- [ ] **Step 3: 提交**

```bash
git add lib/presentation/pages/inspiration/capture_page.dart
git commit -m "feat: 添加灵感捕捉/编辑页面"
```

---

## Task 17: 灵感列表页面

**Files:**
- Create: `lib/presentation/pages/inspiration/inspiration_list_page.dart`

- [ ] **Step 1: 实现灵感列表页面**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/widgets/inspiration_card.dart';
import 'package:flashnote/presentation/widgets/source_selector.dart';

class InspirationListPage extends ConsumerStatefulWidget {
  const InspirationListPage({super.key});

  @override
  ConsumerState<InspirationListPage> createState() =>
      _InspirationListPageState();
}

class _InspirationListPageState extends ConsumerState<InspirationListPage> {
  String? _selectedSource;
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inspirationsAsync = ref.watch(inspirationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchInspiration,
                  border: InputBorder.none,
                ),
                onChanged: (query) {
                  setState(() => _searchQuery = query);
                  ref.read(inspirationListProvider.notifier).search(query);
                },
              )
            : Text(l10n.inspirations),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  ref.read(inspirationListProvider.notifier).refresh();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SourceSelector(
              selectedSource: _selectedSource,
              onSelected: (source) {
                setState(() => _selectedSource = source);
                ref
                    .read(inspirationListProvider.notifier)
                    .filterBySource(source);
              },
            ),
          ),
          Expanded(
            child: inspirationsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (inspirations) {
                if (inspirations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? l10n.noMatchFound
                              : l10n.noInspirationYet,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                context.push('/inspiration/new'),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.captureInspiration),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(inspirationListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: inspirations.length,
                    itemBuilder: (context, index) {
                      final inspiration = inspirations[index];
                      return InspirationCard(
                        inspiration: inspiration,
                        onTap: () =>
                            context.push('/inspiration/${inspiration.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/inspiration/new'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
flutter run -d windows --debug
```

Expected: 灵感 Tab 显示空状态引导，点击 FAB 可新建灵感，保存后列表刷新显示。

- [ ] **Step 3: 提交**

```bash
git add lib/presentation/pages/inspiration/inspiration_list_page.dart
git commit -m "feat: 添加灵感列表页面（搜索、来源筛选、空状态）"
```

---

## Task 18: 灵感详情页面

**Files:**
- Create: `lib/presentation/pages/inspiration/inspiration_detail_page.dart`

- [ ] **Step 1: 实现灵感详情页面**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:intl/intl.dart';

class InspirationDetailPage extends ConsumerWidget {
  const InspirationDetailPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(inspirationRepositoryProvider);

    return FutureBuilder<Inspiration?>(
      future: repo.getById(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final inspiration = snapshot.data;
        if (inspiration == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('灵感不存在')),
          );
        }

        final theme = Theme.of(context);
        final dateStr =
            DateFormat('yyyy年MM月dd日 HH:mm').format(inspiration.createdAt);

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: Icon(
                    inspiration.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                onPressed: () async {
                  await ref
                      .read(inspirationRepositoryProvider)
                      .togglePin(inspiration.id);
                  ref.read(inspirationListProvider.notifier).refresh();
                  // ignore: use_build_context_synchronously
                  (context as Element).markNeedsBuild();
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('/inspiration/${inspiration.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除灵感'),
                      content: const Text('确定要删除这条灵感吗？'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('删除')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(inspirationRepositoryProvider)
                        .delete(inspiration.id);
                    ref.read(inspirationListProvider.notifier).refresh();
                    if (context.mounted) context.pop();
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (inspiration.source != null) ...[
                      Chip(
                        label: Text(inspiration.source!),
                        avatar: const Icon(Icons.lightbulb_outline, size: 18),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(dateStr, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(
                  inspiration.content,
                  style: theme.textTheme.bodyLarge,
                ),
                if (inspiration.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: inspiration.tags
                        .map((tag) => Chip(label: Text(tag)))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text('AI 能力', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('AI 分析'),
                  subtitle: const Text('评估可行性、潜力和风险'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  enabled: false, // S2 启用
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: const Text('思维导图'),
                  subtitle: const Text('AI 生成思维导图'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  enabled: false, // S2 启用
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.chat_outlined),
                  title: const Text('AI 对话'),
                  subtitle: const Text('深度探讨灵感'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  enabled: false, // S2 启用
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('创建项目'),
                  subtitle: const Text('将灵感转化为项目'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  enabled: false, // S3 启用
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 修复灵感详情页刷新问题**

`InspirationDetailPage` 使用 `FutureBuilder` 但置顶/删除后不会自动刷新。改为用 Provider 监听单个灵感。

将 `InspirationDetailPage` 改为 ConsumerStatefulWidget，使用 Provider 获取数据，并在操作后刷新：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:intl/intl.dart';

final inspirationDetailProvider =
    FutureProvider.family<Inspiration?, int>((ref, id) {
  return ref.read(inspirationRepositoryProvider).getById(id);
});

class InspirationDetailPage extends ConsumerWidget {
  const InspirationDetailPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final inspirationAsync = ref.watch(inspirationDetailProvider(id));

    return inspirationAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('${l10n.loadFailed}: $e'))),
      data: (inspiration) {
        if (inspiration == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.inspirationNotFound)),
          );
        }

        final theme = Theme.of(context);
        final dateStr = DateFormat.yMMMMd(l10n.localeName)
            .add_Hm()
            .format(inspiration.createdAt);

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: Icon(inspiration.isPinned
                    ? Icons.push_pin
                    : Icons.push_pin_outlined),
                onPressed: () async {
                  await ref
                      .read(inspirationRepositoryProvider)
                      .togglePin(inspiration.id);
                  ref.invalidate(inspirationDetailProvider(id));
                  ref.read(inspirationListProvider.notifier).refresh();
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('/inspiration/${inspiration.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.deleteInspiration),
                      content: Text(l10n.deleteInspirationConfirm),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.cancel)),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.delete)),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(inspirationRepositoryProvider)
                        .delete(inspiration.id);
                    ref.read(inspirationListProvider.notifier).refresh();
                    if (context.mounted) context.pop();
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (inspiration.source != null) ...[
                      Chip(
                        label: Text(inspiration.source!),
                        avatar:
                            const Icon(Icons.lightbulb_outline, size: 18),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(dateStr, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(
                  inspiration.content,
                  style: theme.textTheme.bodyLarge,
                ),
                if (inspiration.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: inspiration.tags
                        .map((tag) => Chip(label: Text(tag)))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(l10n.aiCapabilities, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: Text(l10n.aiAnalysis),
                  subtitle: Text(l10n.aiAnalysisDesc),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  enabled: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: Text(l10n.mindMap),
                  subtitle: Text(l10n.mindMapDesc),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  enabled: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.chat_outlined),
                  title: Text(l10n.aiChat),
                  subtitle: Text(l10n.aiChatDesc),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  enabled: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(l10n.createProject),
                  subtitle: Text(l10n.createProjectDesc),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  enabled: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 3: 验证编译和功能**

```bash
flutter run -d windows --debug
```

Expected: 点击灵感卡片进入详情页，可看到完整内容、来源、标签，AI 能力入口显示为禁用状态。

- [ ] **Step 4: 提交**

```bash
git add lib/presentation/pages/inspiration/inspiration_detail_page.dart
git commit -m "feat: 添加灵感详情页面，含置顶/编辑/删除和 AI 能力占位"
```

---

## Task 19: 长按菜单（置顶/删除）

**Files:**
- Modify: `lib/presentation/pages/inspiration/inspiration_list_page.dart`

- [ ] **Step 1: 在灵感列表中添加长按菜单**

在 `InspirationListPage` 的 `ListView.builder` 中，给 `InspirationCard` 外层包裹 `GestureDetector`，添加长按弹出菜单：

```dart
// 替换 ListView.builder 中的 itemBuilder
itemBuilder: (context, index) {
  final inspiration = inspirations[index];
  return GestureDetector(
    onSecondaryTap: () => _showContextMenu(context, ref, inspiration.id, inspiration.isPinned),
    onLongPress: () => _showContextMenu(context, ref, inspiration.id, inspiration.isPinned),
    child: InspirationCard(
      inspiration: inspiration,
      onTap: () => context.push('/inspiration/${inspiration.id}'),
    ),
  );
},
```

- [ ] **Step 2: 添加 `_showContextMenu` 方法到 `_InspirationListPageState`**

```dart
void _showContextMenu(
    BuildContext context, WidgetRef ref, int id, bool isPinned) {
  final l10n = AppLocalizations.of(context);
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(isPinned ? l10n.unpin : l10n.pin),
            onTap: () {
              Navigator.pop(ctx);
              ref.read(inspirationListProvider.notifier).togglePin(id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(ctx);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: Text(l10n.deleteInspiration),
                  content: Text(l10n.deleteInspirationConfirm),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: Text(l10n.cancel)),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: Text(l10n.delete)),
                  ],
                ),
              );
              if (confirmed == true) {
                ref.read(inspirationListProvider.notifier).delete(id);
              }
            },
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 3: 验证功能**

```bash
flutter run -d windows --debug
```

Expected: 长按灵感卡片弹出底部菜单，可置顶/删除。右键也弹出菜单。

- [ ] **Step 4: 提交**

```bash
git add lib/presentation/pages/inspiration/inspiration_list_page.dart
git commit -m "feat: 灵感列表添加长按/右键菜单（置顶、删除）"
```

---

## Task 20: 全量测试与最终验证

**Files:**
- 无新文件

- [ ] **Step 1: 运行全部测试**

```bash
flutter test
```

Expected: 所有测试通过。

- [ ] **Step 2: 代码生成验证**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: 无错误，所有 .g.dart 和 .freezed.dart 文件正确生成。

- [ ] **Step 3: 编译检查（全平台）**

```bash
flutter build windows --debug
flutter build apk --debug
```

Expected: 编译成功，无报错。

- [ ] **Step 4: 功能走查**

手动验证以下流程：
1. 应用启动 → 4 Tab 导航正常
2. 首页 → 点击「捕捉灵感」→ 打开捕捉页
3. 输入内容、选择来源、添加标签 → 保存 → 回到灵感列表
4. 灵感列表 → 搜索 → 筛选来源 → 卡片展示正确
5. 点击卡片 → 详情页 → 显示完整内容
6. 长按卡片 → 置顶/删除
7. 编辑灵感 → 保存 → 更新生效
8. 首页/项目/我的 Tab → 占位页面显示正确

- [ ] **Step 5: 最终提交**

```bash
git add -A
git commit -m "feat: S1 阶段完成 — 架构骨架 + 灵感管理全流程"
```

---

## S1 完成检查清单

- [ ] Flutter 项目初始化，全平台可编译
- [ ] Clean Architecture 目录结构完整
- [ ] Riverpod DI 正常工作
- [ ] drift 数据库创建成功，inspirations 和 custom_sources 表可用
- [ ] go_router 路由和底部 Tab 导航正常
- [ ] 灵感 CRUD（新建、编辑、删除、置顶）功能完整
- [ ] 灵感列表（搜索、来源筛选、空状态）正常
- [ ] 灵感详情页（完整内容、AI 入口占位）正常
- [ ] 长按/右键菜单（置顶、删除）正常
- [ ] 所有测试通过
- [ ] 首页、项目 Tab、我的 Tab 占位页面正确
