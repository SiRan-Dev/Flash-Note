# FlashNote S2: AI 能力集成 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为灵感叠加 AI 分析、思维导图、对话三层能力，补齐 AI 配置页面。

**Architecture:** 在 Data 层新增 AI 服务（策略模式），Domain 层定义接口和实体，Presentation 层新增 AI 相关页面和 Provider。

**Tech Stack:** Flutter 3.x, Dart 3.x, dio (HTTP), flutter_secure_storage (API Key 加密存储), Riverpod, drift

**S2 简化说明:**
- AI 对话先实现非流式，流式输出留到后续增强
- 思维导图导出 PNG/PDF 留到后续
- 主题切换和数据管理仍在 S4

---

## File Map

### Domain Layer (纯 Dart)
- `lib/domain/entities/ai_preset.dart` — AI 预设配置（普通 Dart 类）
- `lib/domain/entities/ai_analysis_result.dart` — AI 分析结果 (freezed)
- `lib/domain/entities/mind_map_node.dart` — 思维导图节点 (freezed)
- `lib/domain/entities/chat_message.dart` — 聊天消息 (freezed)
- `lib/domain/services/ai_service.dart` — AI 服务抽象接口

### Data Layer
- `lib/data/datasources/remote/ai_service_impl.dart` — AI 服务实现（策略选择）
- `lib/data/datasources/remote/openai_compatible_strategy.dart` — OpenAI 兼容策略
- `lib/data/datasources/remote/claude_strategy.dart` — Claude API 策略
- `lib/data/datasources/local/ai_settings_storage.dart` — API Key 安全存储
- `lib/data/datasources/local/app_database.dart` — 修改：新增 mindMapData 列

### Presentation Layer
- `lib/presentation/providers/ai_providers.dart` — AI 相关 Riverpod Providers
- `lib/presentation/pages/settings/settings_page.dart` — 修改：AI 配置区域
- `lib/presentation/pages/inspiration/ai_analysis_page.dart` — 灵感分析结果页
- `lib/presentation/pages/inspiration/mind_map_page.dart` — 思维导图页
- `lib/presentation/pages/inspiration/ai_chat_page.dart` — AI 对话页
- `lib/presentation/pages/inspiration/inspiration_detail_page.dart` — 修改：启用 AI 入口
- `lib/app/router.dart` — 修改：新增路由

---

## Task 1: 依赖添加

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加 dio 和 flutter_secure_storage 依赖**

在 `pubspec.yaml` 的 `dependencies` 中添加：

```yaml
  dio: ^5.7.0
  flutter_secure_storage: ^9.2.4
```

- [ ] **Step 2: 安装依赖**

```bash
flutter pub get
```

Expected: 成功安装，无冲突。

- [ ] **Step 3: 提交**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: 添加 dio 和 flutter_secure_storage 依赖"
```

---

## Task 2: i18n 扩展

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: 在 app_zh.arb 中添加 S2 翻译 key**

在 `app_zh.arb` 的 `developer` 之后添加：

```json
  "aiSettings": "AI 配置",
  "aiSettingsDesc": "选择 AI 服务商、填写 API Key",
  "selectProvider": "选择服务商",
  "apiKey": "API Key",
  "apiKeyHint": "请输入 API Key",
  "testConnection": "测试连接",
  "connectionSuccess": "连接成功",
  "connectionFailed": "连接失败",
  "apiKeyRequired": "请先配置 API Key",
  "aiAnalyzing": "AI 分析中...",
  "aiAnalysisResult": "AI 分析结果",
  "feasibility": "可行性",
  "potential": "潜力",
  "risk": "风险",
  "suggestions": "建议",
  "generatingMindMap": "生成思维导图中...",
  "mindMapError": "思维导图生成失败",
  "expand": "展开",
  "collapse": "收起",
  "send": "发送",
  "typeMessage": "输入消息...",
  "aiThinking": "AI 思考中...",
  "messageSendFailed": "消息发送失败",
  "clearChatHistory": "清空对话历史",
  "clearChatHistoryConfirm": "确定要清空对话历史吗？",
  "chatCleared": "对话已清空",
  "aiChatWithInspiration": "与 AI 探讨这条灵感",
  "noApiKeyConfigured": "未配置 API Key",
  "goToSettings": "去设置",
  "analysisCached": "分析结果已缓存",
  "reanalyze": "重新分析"
```

- [ ] **Step 2: 在 app_en.arb 中添加对应翻译**

在 `app_en.arb` 的 `version` 之后添加：

```json
  "aiSettings": "AI Settings",
  "aiSettingsDesc": "Select AI provider and enter API Key",
  "selectProvider": "Select Provider",
  "apiKey": "API Key",
  "apiKeyHint": "Enter your API Key",
  "testConnection": "Test Connection",
  "connectionSuccess": "Connection successful",
  "connectionFailed": "Connection failed",
  "apiKeyRequired": "Please configure API Key first",
  "aiAnalyzing": "Analyzing with AI...",
  "aiAnalysisResult": "AI Analysis Result",
  "feasibility": "Feasibility",
  "potential": "Potential",
  "risk": "Risk",
  "suggestions": "Suggestions",
  "generatingMindMap": "Generating mind map...",
  "mindMapError": "Failed to generate mind map",
  "expand": "Expand",
  "collapse": "Collapse",
  "send": "Send",
  "typeMessage": "Type a message...",
  "aiThinking": "AI is thinking...",
  "messageSendFailed": "Failed to send message",
  "clearChatHistory": "Clear Chat History",
  "clearChatHistoryConfirm": "Are you sure you want to clear the chat history?",
  "chatCleared": "Chat cleared",
  "aiChatWithInspiration": "Discuss this idea with AI",
  "noApiKeyConfigured": "API Key not configured",
  "goToSettings": "Go to Settings",
  "analysisCached": "Analysis result cached",
  "reanalyze": "Re-analyze"
```

- [ ] **Step 3: 重新生成 l10n**

```bash
flutter gen-l10n
```

Expected: 无错误，`AppLocalizations` 新增对应 getter。

- [ ] **Step 4: 提交**

```bash
git add lib/l10n/
git commit -m "feat: 添加 S2 AI 相关 i18n 翻译 key"
```

---

## Task 3: Domain 层 — AI 实体

**Files:**
- Create: `lib/domain/entities/ai_preset.dart`
- Create: `lib/domain/entities/ai_analysis_result.dart`
- Create: `lib/domain/entities/mind_map_node.dart`
- Create: `lib/domain/entities/chat_message.dart`

- [ ] **Step 1: 创建 AI 预设配置类**

```dart
// lib/domain/entities/ai_preset.dart
class AiPreset {
  const AiPreset({
    required this.id,
    required this.name,
    required this.model,
    required this.baseUrl,
    this.isClaude = false,
  });

  final String id;
  final String name;
  final String model;
  final String baseUrl;
  final bool isClaude;

  static const List<AiPreset> builtInPresets = [
    AiPreset(
      id: 'openai',
      name: 'OpenAI',
      model: 'gpt-4.1-mini',
      baseUrl: 'https://api.openai.com/v1',
    ),
    AiPreset(
      id: 'gemini',
      name: 'Gemini',
      model: 'gemini-3.1-flash-lite-preview',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    ),
    AiPreset(
      id: 'claude',
      name: 'Claude',
      model: 'claude-haiku-4-5-20251001',
      baseUrl: 'https://api.anthropic.com/v1',
      isClaude: true,
    ),
    AiPreset(
      id: 'deepseek',
      name: 'DeepSeek',
      model: 'deepseek-v4-flash',
      baseUrl: 'https://api.deepseek.com',
    ),
    AiPreset(
      id: 'tongyi',
      name: '通义千问',
      model: 'qwen3.6-flash',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    ),
    AiPreset(
      id: 'zhipu',
      name: '智谱 GLM',
      model: 'glm-4.7-flash',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    ),
  ];

  static AiPreset? findById(String id) {
    try {
      return builtInPresets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 2: 创建 AI 分析结果实体**

```dart
// lib/domain/entities/ai_analysis_result.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_analysis_result.freezed.dart';
part 'ai_analysis_result.g.dart';

@freezed
class AiAnalysisResult with _$AiAnalysisResult {
  const factory AiAnalysisResult({
    required int feasibility,
    required int potential,
    required int risk,
    required String suggestions,
  }) = _AiAnalysisResult;

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$AiAnalysisResultFromJson(json);
}
```

- [ ] **Step 3: 创建思维导图节点实体**

```dart
// lib/domain/entities/mind_map_node.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mind_map_node.freezed.dart';
part 'mind_map_node.g.dart';

@freezed
class MindMapNode with _$MindMapNode {
  const factory MindMapNode({
    required String label,
    @Default([]) List<MindMapNode> children,
  }) = _MindMapNode;

  factory MindMapNode.fromJson(Map<String, dynamic> json) =>
      _$MindMapNodeFromJson(json);
}
```

- [ ] **Step 4: 创建聊天消息实体**

```dart
// lib/domain/entities/chat_message.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';

enum ChatRole { user, assistant }

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required ChatRole role,
    required String content,
    @Default(false) bool isLoading,
  }) = _ChatMessage;
}
```

- [ ] **Step 5: 运行代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `.freezed.dart` 和 `.g.dart` 文件成功生成。

- [ ] **Step 6: 验证**

```bash
dart analyze lib/domain/entities/
```

Expected: 无错误。

- [ ] **Step 7: 提交**

```bash
git add lib/domain/entities/ai_preset.dart lib/domain/entities/ai_analysis_result.dart lib/domain/entities/mind_map_node.dart lib/domain/entities/chat_message.dart
git commit -m "feat: 添加 AI 实体（预设、分析结果、思维导图节点、聊天消息）"
```

---

## Task 4: Domain 层 — AI 服务接口

**Files:**
- Create: `lib/domain/services/ai_service.dart`

- [ ] **Step 1: 创建 AI 服务抽象接口**

```dart
// lib/domain/services/ai_service.dart
import 'package:flashnote/domain/entities/ai_analysis_result.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';

abstract class AiService {
  /// 测试当前配置的 AI 服务连接
  Future<bool> testConnection(AiPreset preset, String apiKey);

  /// 分析灵感
  Future<AiAnalysisResult> analyze(String content, AiPreset preset, String apiKey);

  /// 生成思维导图
  Future<MindMapNode> generateMindMap(String content, AiPreset preset, String apiKey);

  /// AI 对话（非流式）
  Future<String> chat(String content, List<ChatMessage> history, AiPreset preset, String apiKey);
}
```

- [ ] **Step 2: 验证**

```bash
dart analyze lib/domain/services/
```

Expected: 无错误。

- [ ] **Step 3: 提交**

```bash
git add lib/domain/services/
git commit -m "feat: 添加 AI 服务抽象接口"
```

---

## Task 5: Data 层 — AI 预设与安全存储

**Files:**
- Create: `lib/data/datasources/local/ai_settings_storage.dart`

- [ ] **Step 1: 实现 AI 设置存储**

```dart
// lib/data/datasources/local/ai_settings_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';

class AiSettingsStorage {
  AiSettingsStorage({
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
  })  : _prefs = prefs,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _selectedPresetKey = 'ai_selected_preset';
  static const _apiKeyPrefix = 'ai_api_key_';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  /// 获取当前选中的预设 ID
  String? get selectedPresetId => _prefs.getString(_selectedPresetKey);

  /// 获取当前选中的预设
  AiPreset? get selectedPreset {
    final id = selectedPresetId;
    if (id == null) return null;
    return AiPreset.findById(id);
  }

  /// 设置选中的预设
  Future<void> setSelectedPreset(String presetId) async {
    await _prefs.setString(_selectedPresetKey, presetId);
  }

  /// 获取指定预设的 API Key
  Future<String?> getApiKey(String presetId) {
    return _secureStorage.read(key: '$_apiKeyPrefix$presetId');
  }

  /// 获取当前选中预设的 API Key
  Future<String?> get currentApiKey {
    final id = selectedPresetId;
    if (id == null) return Future.value(null);
    return getApiKey(id);
  }

  /// 保存 API Key
  Future<void> saveApiKey(String presetId, String apiKey) {
    return _secureStorage.write(key: '$_apiKeyPrefix$presetId', value: apiKey);
  }

  /// 删除 API Key
  Future<void> deleteApiKey(String presetId) {
    return _secureStorage.delete(key: '$_apiKeyPrefix$presetId');
  }
}
```

- [ ] **Step 2: 验证**

```bash
dart analyze lib/data/datasources/local/ai_settings_storage.dart
```

Expected: 无错误。

- [ ] **Step 3: 提交**

```bash
git add lib/data/datasources/local/ai_settings_storage.dart
git commit -m "feat: 添加 AI 设置安全存储（API Key 加密）"
```

---

## Task 6: Data 层 — AI 服务实现

**Files:**
- Create: `lib/data/datasources/remote/openai_compatible_strategy.dart`
- Create: `lib/data/datasources/remote/claude_strategy.dart`
- Create: `lib/data/datasources/remote/ai_service_impl.dart`

- [ ] **Step 1: 实现 OpenAI 兼容策略**

```dart
// lib/data/datasources/remote/openai_compatible_strategy.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flashnote/domain/entities/ai_analysis_result.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';

class OpenAiCompatibleStrategy {
  final Dio _dio = Dio();

  Map<String, String> _headers(String apiKey) => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  Future<bool> testConnection(AiPreset preset, String apiKey) async {
    try {
      final response = await _dio.get(
        '${preset.baseUrl}/models',
        options: Options(headers: _headers(apiKey)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> _chat(
    String systemPrompt,
    String userMessage,
    List<ChatMessage> history,
    AiPreset preset,
    String apiKey,
  ) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      for (final msg in history)
        {
          'role': msg.role == ChatRole.user ? 'user' : 'assistant',
          'content': msg.content,
        },
      {'role': 'user', 'content': userMessage},
    ];

    final response = await _dio.post(
      '${preset.baseUrl}/chat/completions',
      options: Options(headers: _headers(apiKey)),
      data: {
        'model': preset.model,
        'messages': messages,
        'temperature': 0.7,
      },
    );

    return response.data['choices'][0]['message']['content'] as String;
  }

  Future<AiAnalysisResult> analyze(
      String content, AiPreset preset, String apiKey) async {
    const systemPrompt = '''你是一个创意分析助手。请分析用户提供的灵感，返回 JSON 格式的结果。
返回格式（只返回 JSON，不要其他文字）：
{
  "feasibility": 1-10 的整数,
  "potential": 1-10 的整数,
  "risk": 1-10 的整数,
  "suggestions": "详细的建议文本"
}''';

    final raw = await _chat(systemPrompt, content, [], preset, apiKey);
    final jsonStr = _extractJson(raw);
    return AiAnalysisResult.fromJson(jsonDecode(jsonStr));
  }

  Future<MindMapNode> generateMindMap(
      String content, AiPreset preset, String apiKey) async {
    const systemPrompt = '''你是一个思维导图生成助手。请根据用户提供的灵感，生成一个 3 层树形结构的思维导图。
返回格式（只返回 JSON，不要其他文字）：
{
  "label": "根节点（灵感核心概念）",
  "children": [
    {
      "label": "分支主题1",
      "children": [
        {"label": "细节1a", "children": []},
        {"label": "细节1b", "children": []}
      ]
    },
    {
      "label": "分支主题2",
      "children": [
        {"label": "细节2a", "children": []}
      ]
    }
  ]
}
要求：2-4 个分支，每个分支 1-3 个细节。''';

    final raw = await _chat(systemPrompt, content, [], preset, apiKey);
    final jsonStr = _extractJson(raw);
    return MindMapNode.fromJson(jsonDecode(jsonStr));
  }

  Future<String> chat(String content, List<ChatMessage> history,
      AiPreset preset, String apiKey) async {
    final systemPrompt = '你是一个创意助手。用户正在探讨以下灵感：\n\n$content\n\n请围绕这个灵感与用户进行深入对话。';
    final lastMessage = history.last.content;
    return _chat(systemPrompt, lastMessage, history.sublist(0, history.length - 1), preset, apiKey);
  }

  String _extractJson(String raw) {
    // 尝试提取 JSON 块
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final match = jsonPattern.firstMatch(raw);
    if (match != null) return match.group(0)!;
    return raw.trim();
  }
}
```

- [ ] **Step 2: 实现 Claude 策略**

```dart
// lib/data/datasources/remote/claude_strategy.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flashnote/domain/entities/ai_analysis_result.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';

class ClaudeStrategy {
  final Dio _dio = Dio();

  Map<String, String> _headers(String apiKey) => {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      };

  Future<bool> testConnection(AiPreset preset, String apiKey) async {
    try {
      final response = await _dio.post(
        '${preset.baseUrl}/messages',
        options: Options(headers: _headers(apiKey)),
        data: {
          'model': preset.model,
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> _chat(
    String systemPrompt,
    String userMessage,
    List<ChatMessage> history,
    AiPreset preset,
    String apiKey,
  ) async {
    final messages = <Map<String, String>>[
      for (final msg in history)
        {
          'role': msg.role == ChatRole.user ? 'user' : 'assistant',
          'content': msg.content,
        },
      {'role': 'user', 'content': userMessage},
    ];

    final response = await _dio.post(
      '${preset.baseUrl}/messages',
      options: Options(headers: _headers(apiKey)),
      data: {
        'model': preset.model,
        'max_tokens': 2048,
        'system': systemPrompt,
        'messages': messages,
      },
    );

    return response.data['content'][0]['text'] as String;
  }

  Future<AiAnalysisResult> analyze(
      String content, AiPreset preset, String apiKey) async {
    const systemPrompt = '''你是一个创意分析助手。请分析用户提供的灵感，返回 JSON 格式的结果。
返回格式（只返回 JSON，不要其他文字）：
{
  "feasibility": 1-10 的整数,
  "potential": 1-10 的整数,
  "risk": 1-10 的整数,
  "suggestions": "详细的建议文本"
}''';

    final raw = await _chat(systemPrompt, content, [], preset, apiKey);
    final jsonStr = _extractJson(raw);
    return AiAnalysisResult.fromJson(jsonDecode(jsonStr));
  }

  Future<MindMapNode> generateMindMap(
      String content, AiPreset preset, String apiKey) async {
    const systemPrompt = '''你是一个思维导图生成助手。请根据用户提供的灵感，生成一个 3 层树形结构的思维导图。
返回格式（只返回 JSON，不要其他文字）：
{
  "label": "根节点（灵感核心概念）",
  "children": [
    {
      "label": "分支主题1",
      "children": [
        {"label": "细节1a", "children": []},
        {"label": "细节1b", "children": []}
      ]
    }
  ]
}
要求：2-4 个分支，每个分支 1-3 个细节。''';

    final raw = await _chat(systemPrompt, content, [], preset, apiKey);
    final jsonStr = _extractJson(raw);
    return MindMapNode.fromJson(jsonDecode(jsonStr));
  }

  Future<String> chat(String content, List<ChatMessage> history,
      AiPreset preset, String apiKey) async {
    final systemPrompt = '你是一个创意助手。用户正在探讨以下灵感：\n\n$content\n\n请围绕这个灵感与用户进行深入对话。';
    final lastMessage = history.last.content;
    return _chat(systemPrompt, lastMessage, history.sublist(0, history.length - 1), preset, apiKey);
  }

  String _extractJson(String raw) {
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final match = jsonPattern.firstMatch(raw);
    if (match != null) return match.group(0)!;
    return raw.trim();
  }
}
```

- [ ] **Step 3: 实现 AI 服务（策略选择器）**

```dart
// lib/data/datasources/remote/ai_service_impl.dart
import 'package:flashnote/data/datasources/remote/claude_strategy.dart';
import 'package:flashnote/data/datasources/remote/openai_compatible_strategy.dart';
import 'package:flashnote/domain/entities/ai_analysis_result.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';
import 'package:flashnote/domain/services/ai_service.dart';

class AiServiceImpl implements AiService {
  final _openAiStrategy = OpenAiCompatibleStrategy();
  final _claudeStrategy = ClaudeStrategy();

  OpenAiCompatibleStrategy _getOpenAiStrategy(AiPreset preset) =>
      _openAiStrategy;

  @override
  Future<bool> testConnection(AiPreset preset, String apiKey) {
    if (preset.isClaude) {
      return _claudeStrategy.testConnection(preset, apiKey);
    }
    return _getOpenAiStrategy(preset).testConnection(preset, apiKey);
  }

  @override
  Future<AiAnalysisResult> analyze(
      String content, AiPreset preset, String apiKey) {
    if (preset.isClaude) {
      return _claudeStrategy.analyze(content, preset, apiKey);
    }
    return _getOpenAiStrategy(preset).analyze(content, preset, apiKey);
  }

  @override
  Future<MindMapNode> generateMindMap(
      String content, AiPreset preset, String apiKey) {
    if (preset.isClaude) {
      return _claudeStrategy.generateMindMap(content, preset, apiKey);
    }
    return _getOpenAiStrategy(preset).generateMindMap(content, preset, apiKey);
  }

  @override
  Future<String> chat(String content, List<ChatMessage> history,
      AiPreset preset, String apiKey) {
    if (preset.isClaude) {
      return _claudeStrategy.chat(content, history, preset, apiKey);
    }
    return _getOpenAiStrategy(preset).chat(content, history, preset, apiKey);
  }
}
```

- [ ] **Step 4: 验证**

```bash
dart analyze lib/data/datasources/remote/
```

Expected: 无错误。

- [ ] **Step 5: 提交**

```bash
git add lib/data/datasources/remote/
git commit -m "feat: 添加 AI 服务实现（OpenAI 兼容 + Claude 策略）"
```

---

## Task 7: Database 升级 — 添加 mindMapData 列

**Files:**
- Modify: `lib/data/datasources/local/tables/inspiration_table.dart`
- Modify: `lib/data/datasources/local/app_database.dart`

- [ ] **Step 1: 在 inspiration_table 中添加 mindMapData 列**

在 `Inspirations` 表类中添加：

```dart
  TextColumn get mindMapData => text().nullable()();
```

- [ ] **Step 2: 升级数据库版本和迁移**

在 `app_database.dart` 中：
1. 将 `schemaVersion` 从 `1` 改为 `2`
2. 在 `MigrationStrategy` 中添加 `onUpgrade` 回调：

```dart
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(inspirations, inspirations.mindMapData);
          }
        },
      );
```

- [ ] **Step 3: 运行代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `app_database.g.dart` 重新生成，包含 `mindMapData` 列。

- [ ] **Step 4: 验证**

```bash
dart analyze lib/data/datasources/local/
```

Expected: 无错误。

- [ ] **Step 5: 提交**

```bash
git add lib/data/datasources/local/tables/inspiration_table.dart lib/data/datasources/local/app_database.dart
git commit -m "feat: 数据库升级 v2，添加 mindMapData 列"
```

---

## Task 8: Presentation 层 — AI Providers

**Files:**
- Create: `lib/presentation/providers/ai_providers.dart`

- [ ] **Step 1: 创建 AI 相关 Providers**

```dart
// lib/presentation/providers/ai_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flashnote/data/datasources/local/ai_settings_storage.dart';
import 'package:flashnote/data/datasources/remote/ai_service_impl.dart';
import 'package:flashnote/domain/entities/ai_analysis_result.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';
import 'package:flashnote/domain/services/ai_service.dart';

/// SharedPreferences 实例
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// AI 设置存储
final aiSettingsStorageProvider = FutureProvider<AiSettingsStorage>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return AiSettingsStorage(prefs: prefs);
});

/// AI 服务
final aiServiceProvider = Provider<AiService>((ref) {
  return AiServiceImpl();
});

/// 当前选中的预设
final selectedPresetProvider = FutureProvider<AiPreset?>((ref) async {
  final storage = await ref.watch(aiSettingsStorageProvider.future);
  return storage.selectedPreset;
});

/// 当前 API Key
final currentApiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = await ref.watch(aiSettingsStorageProvider.future);
  return storage.currentApiKey;
});

/// AI 配置是否就绪（预设已选 + Key 已填）
final aiConfigReadyProvider = FutureProvider<bool>((ref) async {
  final preset = await ref.watch(selectedPresetProvider.future);
  final apiKey = await ref.watch(currentApiKeyProvider.future);
  return preset != null && apiKey != null && apiKey.isNotEmpty;
});

/// AI 分析结果 Provider（按灵感 ID 缓存）
final aiAnalysisProvider =
    FutureProvider.family<AiAnalysisResult?, int>((ref, inspirationId) async {
  // 分析结果从数据库读取，由页面层直接调用 service
  return null;
});

/// 聊天消息列表 StateProvider
final chatMessagesProvider =
    StateProvider.autoDispose<List<ChatMessage>>((ref) => []);
```

- [ ] **Step 2: 验证**

```bash
dart analyze lib/presentation/providers/ai_providers.dart
```

Expected: 无错误。

- [ ] **Step 3: 提交**

```bash
git add lib/presentation/providers/ai_providers.dart
git commit -m "feat: 添加 AI 相关 Riverpod Providers"
```

---

## Task 9: Settings 页 — AI 配置

**Files:**
- Modify: `lib/presentation/pages/settings/settings_page.dart`

- [ ] **Step 1: 重写 Settings 页，添加 AI 配置区域**

替换整个 `settings_page.dart`：

```dart
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _selectedPresetId;
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = await ref.read(aiSettingsStorageProvider.future);
    final presetId = storage.selectedPresetId;
    final apiKey = await storage.currentApiKey;
    if (mounted) {
      setState(() {
        _selectedPresetId = presetId;
        _apiKeyController.text = apiKey ?? '';
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_selectedPresetId == null) return;
    final storage = await ref.read(aiSettingsStorageProvider.future);
    await storage.setSelectedPreset(_selectedPresetId!);
    await storage.saveApiKey(_selectedPresetId!, _apiKeyController.text.trim());
    // 刷新 providers
    ref.invalidate(selectedPresetProvider);
    ref.invalidate(currentApiKeyProvider);
    ref.invalidate(aiConfigReadyProvider);
  }

  Future<void> _testConnection() async {
    if (_selectedPresetId == null) return;
    final preset = AiPreset.findById(_selectedPresetId!);
    if (preset == null) return;
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _testResult = AppLocalizations.of(context).apiKeyRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    final service = ref.read(aiServiceProvider);
    final success = await service.testConnection(preset, apiKey);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _testResult = success
            ? AppLocalizations.of(context).connectionSuccess
            : AppLocalizations.of(context).connectionFailed;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // AI 配置区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.aiSettings, style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(l10n.aiSettingsDesc, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 16),
          // 预设选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.selectProvider, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          ...AiPreset.builtInPresets.map((preset) => RadioListTile<String>(
                title: Text(preset.name),
                subtitle: Text(preset.model),
                value: preset.id,
                groupValue: _selectedPresetId,
                onChanged: (value) {
                  setState(() {
                    _selectedPresetId = value;
                    _testResult = null;
                  });
                  _saveSettings();
                },
              )),
          const SizedBox(height: 16),
          // API Key 输入
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.apiKey, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                hintText: l10n.apiKeyHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveSettings,
                ),
              ),
              obscureText: true,
              onChanged: (_) => setState(() => _testResult = null),
            ),
          ),
          const SizedBox(height: 16),
          // 测试连接
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _isLoading ? null : _testConnection,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(l10n.testConnection),
                ),
                const SizedBox(width: 16),
                if (_testResult != null)
                  Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testResult == l10n.connectionSuccess
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          // 应用信息
          Center(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Icon(Icons.person_outline_rounded,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(l10n.appName, style: theme.textTheme.titleLarge),
                Text('v1.0.0', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('${l10n.developer}: EchoRan',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 验证**

```bash
dart analyze lib/presentation/pages/settings/settings_page.dart
```

Expected: 无错误。

- [ ] **Step 3: 提交**

```bash
git add lib/presentation/pages/settings/settings_page.dart
git commit -m "feat: Settings 页添加 AI 配置（预设选择、API Key、测试连接）"
```

---

## Task 10: 灵感分析功能

**Files:**
- Create: `lib/presentation/pages/inspiration/ai_analysis_page.dart`
- Modify: `lib/presentation/pages/inspiration/inspiration_detail_page.dart`（启用 AI 分析入口）

- [ ] **Step 1: 创建灵感分析结果页**

```dart
// lib/presentation/pages/inspiration/ai_analysis_page.dart
import 'package:flashnote/domain/entities/ai_analysis_result.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/services/ai_service.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiAnalysisPage extends ConsumerStatefulWidget {
  const AiAnalysisPage({
    super.key,
    required this.inspirationId,
    required this.content,
    this.existingAnalysis,
  });

  final int inspirationId;
  final String content;
  final AiAnalysisResult? existingAnalysis;

  @override
  ConsumerState<AiAnalysisPage> createState() => _AiAnalysisPageState();
}

class _AiAnalysisPageState extends ConsumerState<AiAnalysisPage> {
  AiAnalysisResult? _result;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = widget.existingAnalysis;
    if (_result == null) {
      _analyze();
    }
  }

  Future<void> _analyze() async {
    final preset = await ref.read(selectedPresetProvider.future);
    final apiKey = await ref.read(currentApiKeyProvider.future);

    if (preset == null || apiKey == null || apiKey.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).apiKeyRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(aiServiceProvider);
      final result = await service.analyze(widget.content, preset, apiKey);
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiAnalysisResult),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.reanalyze,
              onPressed: _analyze,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.aiAnalyzing),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _analyze,
                        child: Text(l10n.reanalyze),
                      ),
                    ],
                  ),
                )
              : _result != null
                  ? _buildResult(theme, l10n)
                  : const SizedBox.shrink(),
    );
  }

  Widget _buildResult(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScoreCard(l10n.feasibility, _result!.feasibility, Colors.green),
          const SizedBox(height: 12),
          _buildScoreCard(l10n.potential, _result!.potential, Colors.blue),
          const SizedBox(height: 12),
          _buildScoreCard(l10n.risk, _result!.risk, Colors.orange),
          const SizedBox(height: 24),
          Text(l10n.suggestions, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _result!.suggestions,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, int score, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: score / 10,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(width: 12),
            Text('$score/10',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证分析页**

```bash
dart analyze lib/presentation/pages/inspiration/ai_analysis_page.dart
```

Expected: 无错误。

- [ ] **Step 3: 提交**

```bash
git add lib/presentation/pages/inspiration/ai_analysis_page.dart
git commit -m "feat: 添加灵感分析结果页面"
```

---

## Task 11: 思维导图功能

**Files:**
- Create: `lib/presentation/pages/inspiration/mind_map_page.dart`

- [ ] **Step 1: 创建思维导图页面**

```dart
// lib/presentation/pages/inspiration/mind_map_page.dart
import 'dart:math';
import 'package:flashnote/domain/entities/mind_map_node.dart';
import 'package:flashnote/domain/services/ai_service.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MindMapPage extends ConsumerStatefulWidget {
  const MindMapPage({
    super.key,
    required this.inspirationId,
    required this.content,
  });

  final int inspirationId;
  final String content;

  @override
  ConsumerState<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends ConsumerState<MindMapPage> {
  MindMapNode? _root;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final preset = await ref.read(selectedPresetProvider.future);
    final apiKey = await ref.read(currentApiKeyProvider.future);

    if (preset == null || apiKey == null || apiKey.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).apiKeyRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(aiServiceProvider);
      final result =
          await service.generateMindMap(widget.content, preset, apiKey);
      if (mounted) {
        setState(() {
          _root = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).mindMapError;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mindMap),
        actions: [
          if (_root != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.reanalyze,
              onPressed: _generate,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.generatingMindMap),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _generate,
                        child: Text(l10n.reanalyze),
                      ),
                    ],
                  ),
                )
              : _root != null
                  ? InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(100),
                      minScale: 0.3,
                      maxScale: 3.0,
                      child: CustomPaint(
                        size: const Size(800, 600),
                        painter: MindMapPainter(
                          root: _root!,
                          colorScheme: Theme.of(context).colorScheme,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
    );
  }
}

class MindMapPainter extends CustomPainter {
  MindMapPainter({required this.root, required this.colorScheme});

  final MindMapNode root;
  final ColorScheme colorScheme;

  static const _nodeRadius = 28.0;
  static const _levelGap = 160.0;
  static const _nodeGap = 60.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    _drawNode(canvas, root, center, 0, -pi, pi);
  }

  void _drawNode(
      Canvas canvas, MindMapNode node, Offset center, int depth, double startAngle, double endAngle) {
    final paint = Paint()
      ..color = depth == 0
          ? colorScheme.primary
          : depth == 1
              ? colorScheme.secondary
              : colorScheme.tertiary
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, _nodeRadius - depth * 4, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: node.label,
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 12 - depth.toDouble(),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: _nodeRadius * 2);

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    if (node.children.isEmpty || depth >= 2) return;

    final childCount = node.children.length;
    final angleStep = (endAngle - startAngle) / childCount;

    for (var i = 0; i < childCount; i++) {
      final angle = startAngle + angleStep * (i + 0.5);
      final distance = _levelGap + (2 - depth) * 20;
      final childCenter = Offset(
        center.dx + cos(angle) * distance,
        center.dy + sin(angle) * distance,
      );

      // 画连接线
      final linePaint = Paint()
        ..color = colorScheme.outline.withValues(alpha: 0.4)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(center, childCenter, linePaint);

      _drawNode(
        canvas,
        node.children[i],
        childCenter,
        depth + 1,
        angle - angleStep / 2,
        angle + angleStep / 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

- [ ] **Step 2: 验证**

```bash
dart analyze lib/presentation/pages/inspiration/mind_map_page.dart
```

Expected: 无错误。

- [ ] **Step 3: 提交**

```bash
git add lib/presentation/pages/inspiration/mind_map_page.dart
git commit -m "feat: 添加思维导图页面（AI 生成 + CustomPainter 渲染）"
```

---

## Task 12: AI 对话功能

**Files:**
- Create: `lib/presentation/pages/inspiration/ai_chat_page.dart`

- [ ] **Step 1: 创建 AI 对话页面**

```dart
// lib/presentation/pages/inspiration/ai_chat_page.dart
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/services/ai_service.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({
    super.key,
    required this.inspirationId,
    required this.content,
  });

  final int inspirationId;
  final String content;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _isLoading = true;
    });
    _scrollToBottom();

    final preset = await ref.read(selectedPresetProvider.future);
    final apiKey = await ref.read(currentApiKeyProvider.future);

    if (preset == null || apiKey == null || apiKey.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          role: ChatRole.assistant,
          content: AppLocalizations.of(context).apiKeyRequired,
        ));
        _isLoading = false;
      });
      return;
    }

    try {
      final service = ref.read(aiServiceProvider);
      final response = await service.chat(
        widget.content,
        _messages.sublist(0, _messages.length - 1),
        preset,
        apiKey,
      );
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: ChatRole.assistant, content: response));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: ChatRole.assistant,
            content: AppLocalizations.of(context).messageSendFailed,
          ));
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiChat),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.clearChatHistory,
              onPressed: () {
                setState(() => _messages.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.chatCleared)),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 灵感上下文提示
          Container(
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surfaceContainerHighest,
            width: double.infinity,
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          // 消息列表
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(l10n.aiChatWithInspiration,
                            style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        // Loading indicator
                        return _buildMessageBubble(
                          ChatMessage(
                            role: ChatRole.assistant,
                            content: l10n.aiThinking,
                            isLoading: true,
                          ),
                          theme,
                        );
                      }
                      return _buildMessageBubble(_messages[index], theme);
                    },
                  ),
          ),
          // 输入框
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: l10n.typeMessage,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ThemeData theme) {
    final isUser = message.role == ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: message.isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isUser
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              )
            : SelectableText(
                message.content,
                style: TextStyle(
                  color: isUser
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证**

```bash
dart analyze lib/presentation/pages/inspiration/ai_chat_page.dart
```

Expected: 无错误。

- [ ] **Step 3: 提交**

```bash
git add lib/presentation/pages/inspiration/ai_chat_page.dart
git commit -m "feat: 添加 AI 对话页面（多轮对话、灵感上下文）"
```

---

## Task 13: 详情页集成 + 路由更新

**Files:**
- Modify: `lib/presentation/pages/inspiration/inspiration_detail_page.dart`
- Modify: `lib/app/router.dart`

- [ ] **Step 1: 更新详情页 — 启用 AI 入口 + i18n + 导航**

在 `inspiration_detail_page.dart` 中：

1. 添加必要的 import：
```dart
import 'package:flashnote/domain/entities/ai_analysis_result.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
```

2. 将 AI 能力区域的硬编码中文替换为 l10n，并启用导航：

```dart
                Text(l10n.aiCapabilities, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: Text(l10n.aiAnalysis),
                  subtitle: Text(l10n.aiAnalysisDesc),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => context.push(
                    '/inspiration/${inspiration.id}/ai-analysis',
                    extra: inspiration.content,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: Text(l10n.mindMap),
                  subtitle: Text(l10n.mindMapDesc),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => context.push(
                    '/inspiration/${inspiration.id}/mind-map',
                    extra: inspiration.content,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.chat_outlined),
                  title: Text(l10n.aiChat),
                  subtitle: Text(l10n.aiChatDesc),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => context.push(
                    '/inspiration/${inspiration.id}/chat',
                    extra: inspiration.content,
                  ),
                ),
```

- [ ] **Step 2: 更新路由 — 添加 AI 相关路由**

在 `router.dart` 的 `/inspiration/:id` 路由的 `routes` 中添加：

```dart
        GoRoute(
          path: 'ai-analysis',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            final content = state.extra as String? ?? '';
            return AiAnalysisPage(inspirationId: id, content: content);
          },
        ),
        GoRoute(
          path: 'mind-map',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            final content = state.extra as String? ?? '';
            return MindMapPage(inspirationId: id, content: content);
          },
        ),
        GoRoute(
          path: 'chat',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            final content = state.extra as String? ?? '';
            return AiChatPage(inspirationId: id, content: content);
          },
        ),
```

添加对应的 import：
```dart
import 'package:flashnote/presentation/pages/inspiration/ai_analysis_page.dart';
import 'package:flashnote/presentation/pages/inspiration/mind_map_page.dart';
import 'package:flashnote/presentation/pages/inspiration/ai_chat_page.dart';
```

- [ ] **Step 3: 验证**

```bash
dart analyze lib/presentation/pages/inspiration/inspiration_detail_page.dart lib/app/router.dart
```

Expected: 无错误。

- [ ] **Step 4: 提交**

```bash
git add lib/presentation/pages/inspiration/inspiration_detail_page.dart lib/app/router.dart
git commit -m "feat: 详情页启用 AI 入口，添加思维导图/AI 对话/分析路由"
```

---

## Task 14: 全量测试与最终验证

**Files:**
- 无新文件

- [ ] **Step 1: 代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: 无错误。

- [ ] **Step 2: 运行全部测试**

```bash
flutter test
```

Expected: 所有测试通过。

- [ ] **Step 3: 代码分析**

```bash
dart analyze lib/
```

Expected: 无错误。

- [ ] **Step 4: 编译检查**

```bash
flutter build apk --debug
```

Expected: 编译成功。

- [ ] **Step 5: 功能走查**

手动验证以下流程：
1. 我的 Tab → AI 配置区域 → 选择预设 → 填写 API Key → 测试连接
2. 灵感详情 → AI 分析 → 查看分析结果
3. 灵感详情 → 思维导图 → 查看可视化
4. 灵感详情 → AI 对话 → 多轮对话

- [ ] **Step 6: 最终提交**

```bash
git add -A
git commit -m "feat: S2 阶段完成 — AI 能力集成（分析、思维导图、对话）"
```

---

## S2 完成检查清单

- [ ] dio + flutter_secure_storage 依赖已添加
- [ ] AI 预设配置（6 个服务商）定义完整
- [ ] API Key 使用 flutter_secure_storage 加密存储
- [ ] AI 服务策略模式实现（OpenAI 兼容 + Claude）
- [ ] 灵感分析（可行性/潜力/风险 + 建议）功能正常
- [ ] 思维导图（AI 生成 + 可视化渲染）功能正常
- [ ] AI 对话（多轮、灵感上下文）功能正常
- [ ] Settings 页 AI 配置（预设选择、API Key、测试连接）正常
- [ ] 详情页 AI 入口启用并可导航
- [ ] 数据库升级 v2（mindMapData 列）迁移正常
- [ ] 所有 UI 文本使用 i18n，无硬编码
- [ ] 所有测试通过
