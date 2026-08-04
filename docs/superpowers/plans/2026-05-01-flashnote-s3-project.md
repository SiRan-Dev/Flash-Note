# FlashNote S3: 项目管理 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打通「灵感→项目→任务」落地链路，实现项目 CRUD、任务管理、进度自动计算、灵感转项目、首页 Dashboard。

**Architecture:** 在 Data 层新增 projects/tasks 表和 Repository，Domain 层定义实体和接口，Presentation 层新增项目相关页面和 Provider。

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod, drift, freezed, go_router

---

## File Map

### Domain Layer (纯 Dart)
- `lib/domain/entities/project.dart` — 项目实体 (freezed)
- `lib/domain/entities/task.dart` — 任务实体 (freezed)
- `lib/domain/repositories/project_repository.dart` — 项目 Repository 接口
- `lib/domain/repositories/task_repository.dart` — 任务 Repository 接口

### Data Layer
- `lib/data/datasources/local/tables/project_table.dart` — 项目 drift 表
- `lib/data/datasources/local/tables/task_table.dart` — 任务 drift 表
- `lib/data/datasources/local/app_database.dart` — 修改：添加 projects/tasks 表，升级 v3
- `lib/data/repositories/project_repository_impl.dart` — 项目 Repository 实现
- `lib/data/repositories/task_repository_impl.dart` — 任务 Repository 实现

### Presentation Layer
- `lib/presentation/providers/project_providers.dart` — 项目/任务 Providers
- `lib/presentation/pages/project/project_list_page.dart` — 修改：项目列表（卡片+进度条）
- `lib/presentation/pages/project/project_detail_page.dart` — 项目详情（任务列表）
- `lib/presentation/pages/project/create_project_page.dart` — 创建/编辑项目
- `lib/presentation/pages/home/home_page.dart` — 修改：Dashboard（最近灵感+待办+快捷操作）
- `lib/presentation/pages/inspiration/inspiration_detail_page.dart` — 修改：启用"创建项目"入口
- `lib/app/router.dart` — 修改：添加项目相关路由
- `lib/l10n/app_zh.arb` — 修改：添加 S3 i18n key
- `lib/l10n/app_en.arb` — 修改：添加 S3 i18n key

---

## Task 1: i18n 扩展

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: 在 app_zh.arb 中添加 S3 翻译 key**

在文件末尾 `}` 之前添加：

```json
  "createProject": "创建项目",
  "editProject": "编辑项目",
  "projectTitle": "项目标题",
  "projectDescription": "项目描述",
  "projectTitleHint": "请输入项目标题",
  "projectDescriptionHint": "请输入项目描述",
  "deleteProject": "删除项目",
  "deleteProjectConfirm": "确定要删除这个项目吗？相关任务也会被删除。",
  "active": "进行中",
  "paused": "已暂停",
  "completed": "已完成",
  "progress": "进度",
  "tasks": "任务",
  "addTask": "添加任务",
  "taskTitle": "任务标题",
  "taskTitleHint": "请输入任务标题",
  "deleteTask": "删除任务",
  "deleteTaskConfirm": "确定要删除这个任务吗？",
  "noTasksYet": "暂无任务",
  "addYourFirstTask": "添加你的第一个任务",
  "inspirationToProject": "将灵感转化为项目",
  "inspirationToProjectConfirm": "确定要将这条灵感转化为项目吗？",
  "organizeInspiration": "梳理灵感思路",
  "recentInspirations": "最近灵感",
  "todayTodos": "今日待办",
  "quickActions": "快捷操作",
  "noProjectsYet": "暂无项目",
  "createYourFirstProject": "创建你的第一个项目",
  "projectCreated": "项目已创建",
  "taskCompleted": "任务已完成",
  "allTasksCompleted": "所有任务已完成！"
```

- [ ] **Step 2: 在 app_en.arb 中添加对应翻译**

在文件末尾 `}` 之前添加：

```json
  "createProject": "Create Project",
  "editProject": "Edit Project",
  "projectTitle": "Project Title",
  "projectDescription": "Project Description",
  "projectTitleHint": "Enter project title",
  "projectDescriptionHint": "Enter project description",
  "deleteProject": "Delete Project",
  "deleteProjectConfirm": "Are you sure you want to delete this project? Related tasks will also be deleted.",
  "active": "Active",
  "paused": "Paused",
  "completed": "Completed",
  "progress": "Progress",
  "tasks": "Tasks",
  "addTask": "Add Task",
  "taskTitle": "Task Title",
  "taskTitleHint": "Enter task title",
  "deleteTask": "Delete Task",
  "deleteTaskConfirm": "Are you sure you want to delete this task?",
  "noTasksYet": "No tasks yet",
  "addYourFirstTask": "Add your first task",
  "inspirationToProject": "Convert to Project",
  "inspirationToProjectConfirm": "Convert this inspiration to a project?",
  "organizeInspiration": "Organize inspiration thoughts",
  "recentInspirations": "Recent Inspirations",
  "todayTodos": "Today's Todos",
  "quickActions": "Quick Actions",
  "noProjectsYet": "No projects yet",
  "createYourFirstProject": "Create your first project",
  "projectCreated": "Project created",
  "taskCompleted": "Task completed",
  "allTasksCompleted": "All tasks completed!"
```

- [ ] **Step 3: 重新生成 l10n**

```bash
flutter gen-l10n
```

- [ ] **Step 4: 提交**

---

## Task 2: Domain 层 — Project 和 Task 实体

**Files:**
- Create: `lib/domain/entities/project.dart`
- Create: `lib/domain/entities/task.dart`

- [ ] **Step 1: 创建项目实体**

```dart
// lib/domain/entities/project.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

@freezed
class Project with _$Project {
  const factory Project({
    required int id,
    int? inspirationId,
    required String title,
    @Default('') String description,
    @Default(0) int progress,
    @Default('active') String status,
    @Default(false) bool isPinned,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}
```

- [ ] **Step 2: 创建任务实体**

```dart
// lib/domain/entities/task.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
class Task with _$Task {
  const factory Task({
    required int id,
    required int projectId,
    required String title,
    @Default(false) bool isCompleted,
    @Default(false) bool isPinned,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) =>
      _$TaskFromJson(json);
}
```

- [ ] **Step 3: 运行代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: 验证**

```bash
dart analyze lib/domain/entities/
```

- [ ] **Step 5: 提交**

---

## Task 3: Database 升级 v3 — 添加 projects/tasks 表

**Files:**
- Create: `lib/data/datasources/local/tables/project_table.dart`
- Create: `lib/data/datasources/local/tables/task_table.dart`
- Modify: `lib/data/datasources/local/app_database.dart`

- [ ] **Step 1: 创建 projects 表**

```dart
// lib/data/datasources/local/tables/project_table.dart
import 'package:drift/drift.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get inspirationId => integer().nullable()();
  TextColumn get title => text().withLength(min: 1)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}
```

- [ ] **Step 2: 创建 tasks 表**

```dart
// lib/data/datasources/local/tables/task_table.dart
import 'package:drift/drift.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer()();
  TextColumn get title => text().withLength(min: 1)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}
```

- [ ] **Step 3: 更新 app_database.dart**

1. 导入新表文件
2. 在 `@DriftDatabase(tables: [...])` 中添加 `Projects, Tasks`
3. 将 `schemaVersion` 从 `2` 改为 `3`
4. 在 `onUpgrade` 中添加 v3 迁移：
```dart
if (from < 3) {
  await m.createTable(projects);
  await m.createTable(tasks);
}
```
5. 添加 Project 和 Task 的 CRUD 方法

- [ ] **Step 4: 运行代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: 验证**

```bash
dart analyze lib/data/datasources/local/
```

- [ ] **Step 6: 提交**

---

## Task 4: Data 层 — Project Repository

**Files:**
- Create: `lib/domain/repositories/project_repository.dart`
- Create: `lib/data/repositories/project_repository_impl.dart`

- [ ] **Step 1: 创建 Project Repository 接口**

```dart
// lib/domain/repositories/project_repository.dart
import 'package:flashnote/domain/entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAll();
  Future<Project?> getById(int id);
  Future<int> create(String title, {String description = '', int? inspirationId});
  Future<void> update(Project project);
  Future<void> delete(int id);
  Future<void> togglePin(int id);
  Future<void> updateStatus(int id, String status);
  Future<void> updateProgress(int id, int progress);
}
```

- [ ] **Step 2: 创建 Project Repository 实现**

遵循 `InspirationRepositoryImpl` 的模式。

- [ ] **Step 3: 验证**

```bash
dart analyze lib/domain/repositories/project_repository.dart lib/data/repositories/project_repository_impl.dart
```

- [ ] **Step 4: 提交**

---

## Task 5: Data 层 — Task Repository

**Files:**
- Create: `lib/domain/repositories/task_repository.dart`
- Create: `lib/data/repositories/task_repository_impl.dart`

- [ ] **Step 1: 创建 Task Repository 接口**

```dart
// lib/domain/repositories/task_repository.dart
import 'package:flashnote/domain/entities/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getByProjectId(int projectId);
  Future<Task?> getById(int id);
  Future<int> create(int projectId, String title);
  Future<void> toggleComplete(int id);
  Future<void> delete(int id);
  Future<void> togglePin(int id);
  Future<int> getCompletedCount(int projectId);
  Future<int> getTotalCount(int projectId);
}
```

- [ ] **Step 2: 创建 Task Repository 实现**

- [ ] **Step 3: 验证**

- [ ] **Step 4: 提交**

---

## Task 6: Presentation 层 — Project Providers

**Files:**
- Create: `lib/presentation/providers/project_providers.dart`

- [ ] **Step 1: 创建 Providers**

包含：
- `projectRepositoryProvider` — ProjectRepository 注入
- `taskRepositoryProvider` — TaskRepository 注入
- `projectListProvider` — AsyncNotifier，管理项目列表
- `taskListProvider` — Family AsyncNotifier，按项目 ID 管理任务列表

- [ ] **Step 2: 验证**

- [ ] **Step 3: 提交**

---

## Task 7: Project List 页

**Files:**
- Modify: `lib/presentation/pages/project/project_list_page.dart`

- [ ] **Step 1: 重写项目列表页**

功能：
- AppBar 标题 + 搜索
- 项目卡片列表：标题、描述摘要、进度条、状态标签
- 置顶/删除长按菜单
- 空状态引导
- FAB 创建项目

- [ ] **Step 2: 验证**

- [ ] **Step 3: 提交**

---

## Task 8: Project Detail 页

**Files:**
- Create: `lib/presentation/pages/project/project_detail_page.dart`

- [ ] **Step 1: 创建项目详情页**

功能：
- AppBar：标题、状态切换、编辑、删除
- 项目信息：标题、描述、进度条、状态
- 任务列表：复选框、添加、删除
- 进度自动计算：完成任务数/总数*100
- 全部完成时自动设置状态为 completed

- [ ] **Step 2: 验证**

- [ ] **Step 3: 提交**

---

## Task 9: Create Project 页

**Files:**
- Create: `lib/presentation/pages/project/create_project_page.dart`

- [ ] **Step 1: 创建项目创建/编辑页**

功能：
- 标题输入、描述输入
- 支持创建模式和编辑模式（通过 optional projectId 参数）
- 保存后跳转到项目详情

- [ ] **Step 2: 验证**

- [ ] **Step 3: 提交**

---

## Task 10: Home Dashboard

**Files:**
- Modify: `lib/presentation/pages/home/home_page.dart`

- [ ] **Step 1: 重写首页为 Dashboard**

功能：
- 顶部日期 + 问候语
- 最近灵感横向滚动卡片（最近 5 条）
- 今日待办（未完成的任务列表）
- 快捷操作：捕捉灵感、创建项目

- [ ] **Step 2: 验证**

- [ ] **Step 3: 提交**

---

## Task 11: 详情页集成 — 灵感转项目

**Files:**
- Modify: `lib/presentation/pages/inspiration/inspiration_detail_page.dart`

- [ ] **Step 1: 启用"创建项目"入口**

将 `enabled: false` 的 ListTile 改为可点击，实现灵感转项目逻辑：
- 弹出确认对话框
- 创建项目（title 从灵感内容截取，description 为完整内容）
- 自动创建第一个任务："梳理灵感思路"
- 跳转到新项目详情页

- [ ] **Step 2: 验证**

- [ ] **Step 3: 提交**

---

## Task 12: 路由更新

**Files:**
- Modify: `lib/app/router.dart`

- [ ] **Step 1: 添加项目相关路由**

添加：
- `/project/new` — 创建项目
- `/project/:id` — 项目详情
- `/project/:id/edit` — 编辑项目

- [ ] **Step 2: 验证**

- [ ] **Step 3: 提交**

---

## Task 13: 全量测试与最终验证

- [ ] **Step 1: 代码生成**
- [ ] **Step 2: 运行全部测试**
- [ ] **Step 3: 代码分析**
- [ ] **Step 4: 编译检查**
- [ ] **Step 5: 功能走查**
- [ ] **Step 6: 最终提交**
