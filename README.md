<p align="center">
  <img src="web/icons/Icon-512.png" width="120" alt="FlashNote Logo">
</p>

<h1 align="center">FlashNote</h1>
<p align="center"><strong>Local-first inspiration inbox and project incubator</strong></p>

<p align="center">
  <a href="https://github.com/SiRan-Dev/Flash-Note/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/SiRan-Dev/Flash-Note"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/SiRan-Dev/Flash-Note?color=blue"></a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.41%2B-02569B?logo=flutter">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.8%2B-0175C2?logo=dart">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux-brightgreen">
</p>

<p align="center">
  <a href="README_zh.md">Switch to Chinese / 切换到中文</a>
</p>

---

## Status

Current release: **v1.3.6 (build 72)**, from `pubspec.yaml`.

| Platform | Support | Notes |
|----------|---------|-------|
| Android | First-class | Signed APK published on GitHub Releases. No AAB is published. |
| Windows | First-class | Release zip published on GitHub Releases. |
| Linux | First-class | Release zip published on GitHub Releases (built on Ubuntu in CI). |
| iOS | Experimental | Unsigned `--no-codesign` builds only. The release job is best-effort and a release may ship without an IPA. |
| macOS | Experimental | Builds, but release builds are unsigned and the sandbox entitlements omit network client and user-selected file access, so AI, WebDAV, and import/export can fail. |
| Web | Not working | `flutter build web` currently fails: `web/sqlite3.wasm` and `web/drift_worker.js` are missing, and several services import `dart:io`. |

"First-class" means CI builds the platform and includes its artifact in every tagged release.

## Features

### Implemented

- **Capture and organize** — quick capture, tags, custom sources, search, and source filters.
- **Attachments** — attach any file to an idea or project. Images open in a full-screen preview; other file types show name and MIME type (no inline video or PDF playback).
- **AI analysis** — feasibility, potential, risk, and suggestions for an idea.
- **Mind maps** — generated from an idea and cached in the idea record.
- **AI chat** — per-idea conversation, plus a global assistant that reads your editable profile background and your ideas/projects.
- **Reports** — weekly report, monthly report, and AI insights, persisted locally in the `reports` table.
- **Linking and knowledge graph** — AI-discovered and manual links (similar, causal, complementary, opposite, parent-child); graph supports manual linking, fit view, layout reset, and cached node positions.
- **Projects** — convert an idea into a project, add tasks, track status and progress.
- **Daily review** — mark an idea as reviewed or needs follow-up.
- **Export / import** — JSON backup including ideas, projects, tasks, sources, attachments, chat history, links, clusters, reports, review state, and graph layouts. Import applies immediately without a restart. Import is overwrite semantics, not a merge.
- **WebDAV sync** — pull, push, and merge; merge keeps the newer `updatedAt` per record; optional auto-sync on launch; optional attachment sync.
- **Desktop canvas** — hover, context menu, middle-drag pan, trackpad zoom, keyboard shortcuts.
- **Appearance** — Material 3, Material You dynamic color, AMOLED black, preset palettes with draggable color field and HEX input, light/dark/system mode.
- **Languages** — Chinese and English.
- **Storage** — local SQLite via drift; no hosted FlashNote backend.

### Planned

- Stable cross-device identity (UUID). The v12 migration exists on a feature branch but is not merged into `main`; multi-device merges can still collide on auto-increment IDs.
- Markdown export for ideas, projects, and reports.
- A system share entry for ideas and reports.
- An AI triage inbox that classifies new ideas and suggests whether to act on them.
- Timeline / kanban views and idea statistics.
- UI for clusters (the `clusters` table and providers exist, but no screen uses them yet).
- Merge-mode import (current import only overwrites).
- Web support, macOS entitlements/signing, and iOS signing/distribution.

## Data ownership and sync safety

- **Local-first storage.** Ideas, projects, reports, and settings live in a local SQLite database. FlashNote has no hosted backend; AI requests go directly to the endpoint you configure (BYOK).
- **Credentials stay on the device.** API keys and the WebDAV password are kept in platform secure storage. JSON exports and WebDAV snapshots are stripped of API keys and the WebDAV password, so restoring on a new device requires re-entering them.
- **Snapshots are published atomically.** Sync writes to a temporary object, verifies its size/ETag, then moves it over the live snapshot with `MOVE`. If the server rejects `MOVE` (405/501), FlashNote falls back to two alternating slots plus a pointer file, and re-checks the pointer before and after writing so a concurrent device is not silently overwritten. A failed publish leaves the previous snapshot intact.
- **Writes are conditional.** Where the server exposes a strong ETag, writes use `If-Match`; weak ETags are not used for `If-Match`. Write requests do not follow redirects.
- **Schema upgrades back up first.** Before a native database upgrade, the database and its `-wal`/`-shm` files are copied to `flashnote_backups/vX_to_vY_<timestamp>/` and a `backup_complete` marker is written last. If the backup fails, startup aborts instead of upgrading without a recoverable copy. Migrations run in a transaction, and a failure shows a recovery screen with the backup path.
- **Merge vs. import.** Merge sync keeps the newer `updatedAt` per record and carries delete tombstones. Importing a JSON file overwrites local data.

## Screenshots

<p align="center">
  <img src="screenshot/1.jpg" width="30%" alt="Home">
  <img src="screenshot/2.jpg" width="30%" alt="Ideas">
  <img src="screenshot/3.jpg" width="30%" alt="Idea detail">
  <img src="screenshot/4.jpg" width="30%" alt="AI analysis">
  <img src="screenshot/5.jpg" width="30%" alt="Mind map">
  <img src="screenshot/6.jpg" width="30%" alt="AI chat">
  <img src="screenshot/7.jpg" width="30%" alt="Knowledge graph">
  <img src="screenshot/8.jpg" width="30%" alt="Daily review">
  <img src="screenshot/9.jpg" width="30%" alt="Weekly report">
  <img src="screenshot/10.jpg" width="30%" alt="AI insight">
  <img src="screenshot/11.jpg" width="30%" alt="Projects">
  <img src="screenshot/12.jpg" width="30%" alt="Settings">
</p>

---

## Getting Started

### Prerequisites

- Flutter SDK >= 3.41.0 (CI uses 3.47.1)
- Dart SDK >= 3.8.0

### Install

```bash
git clone https://github.com/SiRan-Dev/Flash-Note.git
cd Flash-Note
flutter pub get
```

### Generate Code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Run

Supported:

```bash
flutter run -d android
flutter run -d windows
flutter run -d linux
```

Experimental:

```bash
flutter run -d ios
flutter run -d macos
```

Web is not runnable at the moment. `flutter run -d chrome` fails because the Web SQLite assets are not in the repository and several services import `dart:io`.

### Build Release

Supported:

```bash
flutter build apk --release          # Android APK
flutter build windows --release
flutter build linux --release
```

Experimental:

```bash
flutter build ios --release --no-codesign   # unsigned; not installable without your own signing
flutter build macos --release                # unsigned and sandbox entitlements are incomplete
```

`flutter build web --release` is not available yet.

> Android debug builds use the package name `com.sirandev.flashnote.debug` and can be installed alongside the release build.

---

## Architecture

```
lib/
├── app/                          # Entry, router, theme
│   └── theme/
├── core/                         # Shared core
│   ├── constants/                # App constants, built-in icons
│   ├── error/                    # Error handling
│   └── utils/                    # Utilities (icon builder, source mapper)
├── data/                         # Data layer
│   ├── datasources/
│   │   ├── local/                # drift DB, SharedPrefs, SecureStorage
│   │   │   ├── connection/       # DB connection per platform, migration backup
│   │   │   └── tables/           # Drift table definitions
│   │   └── remote/               # AI (OpenAI + Claude), WebDAV client
│   ├── repositories/             # Repository implementations
│   └── services/                 # Export, sync, notification services
├── domain/                       # Domain layer
│   ├── entities/                 # Entities (freezed)
│   ├── repositories/             # Repository interfaces
│   └── services/                 # Service interfaces (AI)
├── l10n/                         # i18n (zh / en)
└── presentation/                 # Presentation layer
    ├── pages/
    │   ├── home/                 # Home page
    │   ├── inspiration/          # Capture, list, detail, AI, graph, review, report
    │   ├── project/              # Project list, detail, create
    │   └── settings/             # Settings, WebDAV, source management
    ├── providers/                # Riverpod Providers
    └── widgets/                  # Shared widgets
```

**Clean Architecture** + **Riverpod** + **drift** + **go_router** + **freezed**

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| State Management | [Riverpod](https://riverpod.dev/) |
| Routing | [go_router](https://pub.dev/packages/go_router) |
| Database | [drift](https://drift.simonbinder.eu/) (SQLite) |
| Code Gen | [freezed](https://pub.dev/packages/freezed) + [json_serializable](https://pub.dev/packages/json_serializable) |
| HTTP | [dio](https://pub.dev/packages/dio) |
| Secure Storage | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) |
| Cloud Sync | WebDAV |
| AI | OpenAI-compatible API + Anthropic-compatible API (Strategy Pattern) |
| i18n | Flutter ARB (zh / en) |
| Design | Material 3 |

---

## CI/CD

**CI** (`.github/workflows/ci.yml`) runs on every push and pull request:

- `flutter pub get`
- `dart run build_runner build`
- `flutter analyze --no-fatal-infos` (warnings and errors fail)
- `flutter test`

Both workflows pin Flutter 3.47.1.

**Release** (`.github/workflows/release.yml`) runs only on `v*` tag pushes:

- Builds and publishes: signed Android APK, macOS zip, Windows zip, Linux zip
- iOS is built without code signing as a best-effort job; a release may not contain an IPA
- Web is not built
- AAB is not published

Android release signing via GitHub Secrets:

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | base64-encoded keystore |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

---

## License

GPL-3.0 — see [LICENSE](LICENSE)
