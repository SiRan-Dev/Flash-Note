<p align="center">
  <img src="web/icons/Icon-512.png" width="120" alt="FlashNote Logo">
</p>

<h1 align="center">闪念 / FlashNote</h1>
<p align="center"><strong>AI 驱动的灵感捕捉与管理工具</strong></p>

<p align="center">
  <a href="https://github.com/SiRan-Dev/FlashNote/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/SiRan-Dev/FlashNote"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/SiRan-Dev/FlashNote?color=blue"></a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.41+-02569B?logo=flutter">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.7+-0175C2?logo=dart">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-brightgreen">
</p>

<p align="center">
  <a href="README.md">Switch to English / 切换到英文</a>
</p>

---

## 截图

<p align="center">
  <img src="screenshot/1.jpg" width="30%" alt="首页">
  <img src="screenshot/2.jpg" width="30%" alt="灵感列表">
  <img src="screenshot/3.jpg" width="30%" alt="灵感详情">
  <img src="screenshot/4.jpg" width="30%" alt="AI 分析">
  <img src="screenshot/5.jpg" width="30%" alt="思维导图">
  <img src="screenshot/6.jpg" width="30%" alt="AI 对话">
  <img src="screenshot/7.jpg" width="30%" alt="知识图谱">
  <img src="screenshot/8.jpg" width="30%" alt="每日回顾">
  <img src="screenshot/9.jpg" width="30%" alt="周报">
  <img src="screenshot/10.jpg" width="30%" alt="AI 洞察">
  <img src="screenshot/11.jpg" width="30%" alt="项目">
  <img src="screenshot/12.jpg" width="30%" alt="设置">
</p>

---

## 功能

- 快速记录灵感，支持标签和来源标记
- AI 分析 — 可行性、潜力、风险与建议
- 思维导图自动生成
- AI 对话 — 深入探讨灵感
- 每日回顾 — 标记已回顾或需跟进
- 周报 / 月报 / AI 洞察
- 灵感关联 — AI 发现 + 手动添加
- 知识图谱 — 可视化关系、手动串联、适配视图、重新布局
- 项目管理 — 灵感转项目，任务拆分，进度追踪
- AI 接口 — OpenAI 兼容与 Anthropic 兼容，支持自定义 Base URL 和模型名
- 本地导出/导入 —— 备份灵感、项目、设置、知识图谱布局、回顾状态、报告、洞察与附件
- WebDAV 云同步 — 拉取 / 推送 / 合并，支持自动同步，可按开关同步附件
- 导入 / 恢复后应用内立即生效，无需重启
- 周报 / 月报 / AI 洞察已做本地持久化
- 桌面端画布交互 —— hover、右键菜单、中键拖拽、触控板缩放、快捷键
- Material You 动态取色 + AMOLED 黑主题
- 主题调色盘 —— 10 个预设色、可拖动色板、HEX 输入、浅色/深色预览
- 浅色 / 深色 / 跟随系统
- 全平台覆盖 — Android、iOS、macOS、Windows、Linux、Web

## 1.2.0 更新亮点

- AI 工作区 UI 统一向知识图谱视觉语言收敛
- AI 思维导图不再僵硬，节点布局与遮挡处理更自然
- 知识图谱与思维导图补了一轮桌面端交互能力
- 知识图谱操作统一收敛到底部工具框
- 本地导入 / 恢复覆盖更多数据，包含附件，并且恢复后立即刷新生效
- WebDAV 同步可在设置中选择是否包含附件
- 主题设置补齐动态取色、A 屏黑主题和完整自定义调色盘
- 周报 / 月报 / AI 洞察从短期缓存升级为本地持久化

> Android Debug 版包名 `com.sirandev.flashnote.debug`，可与正式版共存。

---

## 快速开始

### 环境要求

- Flutter SDK >= 3.41.0
- Dart SDK >= 3.7.0

### 安装

```bash
git clone https://github.com/SiRan-Dev/FlashNote.git
cd FlashNote
flutter pub get
```

### 生成代码

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 运行

```bash
flutter run                  # Android
flutter run -d ios           # iOS
flutter run -d macos         # macOS
flutter run -d windows       # Windows
flutter run -d linux         # Linux
flutter run -d chrome        # Web
```

### 构建正式版

```bash
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android AAB
flutter build ios --release --no-codesign
flutter build macos --release
flutter build windows --release
flutter build linux --release
flutter build web --release
```

---

## 架构

```
lib/
├── app/                          # 入口、路由、主题
│   └── theme/
├── core/                         # 共享核心
│   ├── constants/                # 应用常量、内置图标
│   ├── error/                    # 错误处理
│   └── utils/                    # 工具（图标构建器、来源映射器）
├── data/                         # 数据层
│   ├── datasources/
│   │   ├── local/                # drift 数据库、SharedPrefs、SecureStorage
│   │   │   ├── connection/       # 各平台数据库连接
│   │   │   └── tables/           # Drift 表定义
│   │   └── remote/               # AI（OpenAI + Claude）、WebDAV 客户端
│   ├── repositories/             # 仓库实现
│   └── services/                 # 导出、同步、通知服务
├── domain/                       # 领域层
│   ├── entities/                 # 实体（freezed）
│   ├── repositories/             # 仓库接口
│   └── services/                 # 服务接口（AI）
├── l10n/                         # 国际化（中文 / English）
└── presentation/                 # 表现层
    ├── pages/
    │   ├── home/                 # 首页
    │   ├── inspiration/          # 灵感捕捉、列表、详情、AI、图谱、回顾、报告
    │   ├── project/              # 项目列表、详情、创建
    │   └── settings/             # 设置、WebDAV、来源管理
    ├── providers/                # Riverpod Providers
    └── widgets/                  # 通用组件
```

**Clean Architecture** + **Riverpod** + **drift** + **go_router** + **freezed**

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 状态管理 | [Riverpod](https://riverpod.dev/) |
| 路由 | [go_router](https://pub.dev/packages/go_router) |
| 数据库 | [drift](https://drift.simonbinder.eu/) (SQLite) |
| 代码生成 | [freezed](https://pub.dev/packages/freezed) + [json_serializable](https://pub.dev/packages/json_serializable) |
| HTTP | [dio](https://pub.dev/packages/dio) |
| 安全存储 | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) |
| 云同步 | WebDAV |
| AI 服务 | OpenAI 兼容 API + Anthropic 兼容 API（策略模式）|
| 国际化 | Flutter ARB（中文 / English）|
| 设计系统 | Material 3 |

---

## CI/CD

GitHub Actions — 仅在推送 `v*` tag 时触发：

- 构建全平台
- 自动发布 GitHub Release 并附带所有构建产物

Android 正式版签名通过 GitHub Secrets 配置：

| Secret | 说明 |
|--------|------|
| `ANDROID_KEYSTORE_BASE64` | base64 编码的密钥库 |
| `ANDROID_STORE_PASSWORD` | 密钥库密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

---

## 许可证

GPL-3.0 — 详见 [LICENSE](LICENSE)
