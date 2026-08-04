# FlashNote v1.0 开发设计文档

> **日期**: 2026-04-30
> **状态**: 已确认
> **基于**: PRD.md v1.0

---

## 1. 关键决策

| 决策项 | 结论 | 理由 |
|--------|------|------|
| 开发策略 | 垂直切片，分 4 阶段 | 每阶段可独立运行，方便验证 |
| 开发顺序 | S1 灵感 → S2 AI → S3 项目 → S4 设置 | 核心链路「灵感→AI→项目落地」 |
| 目标平台 | 全平台同步 | Flutter 跨平台，一次搞定 |
| 项目脚手架 | 手动搭建 | 完全按 PRD 结构，最灵活 |
| 依赖注入 | 纯 Riverpod DI | 去掉 get_it + injectable，减少代码生成，更简洁 |

---

## 2. 阶段规划

### S1：架构骨架 + 灵感管理

**目标**: 搭好项目骨架，实现灵感 CRUD 和列表管理，应用可独立运行。

**产出**:
- Flutter 项目初始化（全平台配置）
- Clean Architecture 目录结构（按 PRD `lib/` 结构）
- Riverpod 依赖注入（Provider 做 DI，无 get_it）
- drift 数据库（`inspirations` 表 + `custom_sources` 表，数据库 v1）
- go_router 路由（底部 4 Tab 导航 + 灵感相关路由）
- 首页占位（S1 阶段首页只显示品牌名和「捕捉灵感」快捷入口，灵感轮播和待办在 S3 实现）
- 项目 Tab 占位（S1 阶段显示空状态引导，S3 实现项目列表）
- 我的 Tab 占位（S1 阶段显示应用版本信息，S4 实现完整设置页）
- 灵感 CRUD（新建、编辑、删除、置顶）
- 灵感列表（卡片展示、搜索、来源筛选、空状态）
- 灵感详情页（完整内容展示，AI 分析入口留占位）
- 基础主题（Material 3 浅色/深色，动态取色放 S4）

**依赖包**:
```
flutter_riverpod
go_router
drift + sqlite3_flutter_libs
shared_preferences
freezed_annotation + json_annotation
intl
flutter_localizations    # i18n 支持
```

**国际化 (i18n)**:
- S1 阶段搭建 ARB 文件骨架（中文 + 英文），所有 UI 文本通过 `AppLocalizations` 访问
- ARB 文件: `lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb`
- 用户输入内容（灵感、标签等）原样存储，不翻译

**数据库表** (v1):
- `inspirations` — id, content, source, tags(JSON), aiAnalysis(JSON), isPinned, createdAt, updatedAt
- `custom_sources` — id, name, icon, sortOrder, createdAt

**路由**:
- `/` — 主页面（Tab 容器：首页/灵感/项目/我的）
- `/inspiration/new` — 灵感捕捉（新建）
- `/inspiration/:id` — 灵感详情
- `/inspiration/:id/edit` — 灵感编辑

### S2：AI 能力集成

**目标**: 为灵感叠加 AI 分析、思维导图、对话三层能力。

**产出**:
- AI 服务层 — 策略模式封装 OpenAI 兼容 API 和 Claude API 差异
- AI 预设配置 — 6 个内置服务商预设，API Key 用 flutter_secure_storage 加密存储
- 灵感分析 — 可行性/潜力/风险评分 + 建议文本，结果缓存到数据库
- 思维导图 — AI 生成 3 层树形 JSON，CustomPainter 渲染，缩放/平移
- AI 对话 — 携带灵感上下文的多轮对话，先非流式，流式输出作为增强
- 我的 Tab 最小可用版 — 仅包含 AI 配置（选预设、填 API Key、测试连接）和应用信息，主题切换和数据管理放 S4

**新增依赖包**:
```
dio
flutter_secure_storage
```

**新增路由**:
- `/inspiration/:id/mind-map` — 思维导图
- `/inspiration/:id/chat` — AI 对话

**AI 服务设计**:
- `AiService` 抽象类定义统一接口
- `OpenAiCompatibleStrategy` 处理 OpenAI/DeepSeek/通义千问/智谱
- `ClaudeStrategy` 单独适配 Claude API 差异（端点、认证头、消息格式、响应格式）
- Provider 层通过当前选中的预设决定使用哪个 Strategy

**持久化策略**:
- AI 分析结果 → `inspirations.aiAnalysis` 字段（JSON）
- 思维导图数据 → 新增 `mind_maps` 表或在 `inspirations` 表加 `mindMapData` 字段（S2 实现时确定最佳方案）
- AI 对话历史 → 内存暂存，关闭页面清空

### S3：项目与任务管理

**目标**: 打通「灵感→项目→任务」落地链路。

**产出**:
- drift 新增 `projects` 表 + `tasks` 表，数据库升级到 v2，编写迁移脚本
- 项目 CRUD（创建、编辑、删除、置顶、状态切换 active/paused/completed）
- 任务 CRUD（添加、完成/取消、删除、置顶）
- 自动进度计算（任务完成比例 → 进度，100% 自动 completed，新增自动回退 active）
- 灵感→项目转化（一键创建关联项目，自动添加「梳理灵感思路」任务）
- 项目列表页（卡片展示：标题、描述、进度条、状态标签）
- 项目详情页（任务列表 + 统计）
- 首页 Dashboard（最近灵感轮播 + 今日待办 + 快捷入口）

**新增路由**:
- `/project/new` — 创建项目
- `/project/:id` — 项目详情

**数据库新增表** (v2):
- `projects` — id, inspirationId(可空), title, description, progress, status, isPinned, createdAt, updatedAt
- `tasks` — id, projectId(级联删除), title, isCompleted, isPinned, createdAt, updatedAt

**级联规则**:
- 项目删除 → 级联删除关联任务
- 灵感删除 → `projects.inspirationId` 置空，不删除项目

### S4：设置、主题与数据管理

**目标**: 补齐 v1.0 完整功能，打磨体验。

**产出**:
- 完整设置页（AI 配置管理、自定义预设、主题切换、数据管理、关于）
- 主题系统（Material You 动态取色、浅色/深色/跟随系统）
- 数据导出（全部数据 → JSON 文件）
- 数据导入（JSON 文件 → 覆盖现有数据，导入前确认）
- 响应式布局适配（手机单列、平板双列、桌面侧边栏 + 详情面板）
- 灵感来源管理（自定义来源增删改，内置 5 个不可删）

**新增依赖包**:
```
file_picker
dynamic_color
url_launcher
```

**响应式断点**:
- `< 600dp` — 手机，单列布局，底部 Tab
- `600-1200dp` — 平板，双列布局，底部 Tab
- `> 1200dp` — 桌面，多列布局，侧边栏导航

**导出 JSON 结构**:
```json
{
  "version": 1,
  "exportedAt": "ISO8601",
  "inspirations": [...],
  "projects": [...],
  "tasks": [...],
  "customSources": [...],
  "settings": {...}
}
```

---

## 3. 架构规范

### 3.1 Clean Architecture 分层

```
lib/
├── main.dart                       # 应用入口
├── app/
│   ├── app.dart                    # MaterialApp + ProviderScope
│   ├── router.dart                 # go_router 路由定义
│   └── theme/
│       ├── app_theme.dart          # ThemeData 定义
│       ├── light_theme.dart        # 浅色主题
│       └── dark_theme.dart         # 深色主题
├── core/
│   ├── constants/                  # 常量
│   ├── utils/                      # 工具类
│   └── error/                      # 错误类型
├── data/
│   ├── datasources/
│   │   ├── local/                  # drift 数据库
│   │   └── remote/                 # AI API 客户端
│   ├── models/                     # DTO / DB Model
│   └── repositories/               # Repository 实现
├── domain/
│   ├── entities/                   # freezed 实体
│   ├── repositories/               # Repository 接口
│   └── usecases/                   # 业务逻辑
└── presentation/
    ├── pages/                      # 页面
    ├── providers/                  # Riverpod Provider
    └── widgets/                    # 可复用组件
```

### 3.2 Riverpod DI 模式

- Repository 接口定义在 `domain/repositories/`
- Repository 实现在 `data/repositories/`
- 用 `Provider` 或 `FutureProvider` 暴露 Repository 实例
- Use Case 用普通 Dart 类，通过 Provider 注入 Repository
- 数据库实例用 `Provider` 全局单例

### 3.3 数据库迁移

- 每次 schema 变更递增版本号
- drift 的 `onUpgrade` 回调中编写分步迁移
- 迁移前自动备份数据库文件（`flashnote.db.bak`）
- 迁移失败回滚到备份并提示用户

### 3.4 AI 服务策略模式

```
AiService (抽象)
├── OpenAiCompatibleStrategy  # OpenAI / DeepSeek / 通义 / 智谱
└── ClaudeStrategy            # Claude API 单独适配
```

上层通过 Provider 获取当前 Strategy，调用统一接口。

---

## 4. 设计规范

- Material 3 Expressive 设计体系
- 种子色：品牌蓝色，`ColorScheme.fromSeed()` 生成调色板
- 浅色/深色双主题
- M3 形状等级（Extra Small 4dp → Full 50%）
- M3 排版体系（Display / Headline / Title / Body / Label）
- 响应式：`LayoutBuilder` 判断断点

---

## 5. 非功能需求（按 PRD）

| 指标 | 要求 |
|------|------|
| 冷启动 | < 1s（桌面 < 2s） |
| Tab 切换 | < 16ms |
| AI 超时 | ≤ 15s |
| 数据库查询 | < 500ms |
| 包体积 | Android < 20MB, iOS < 25MB |
