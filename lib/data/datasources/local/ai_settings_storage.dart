import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettingsStorage {
  AiSettingsStorage({
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
  }) : _prefs = prefs,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _selectedPresetKey = 'ai_selected_preset';
  static const _apiKeyPrefix = 'ai_api_key_';
  static const _customBaseUrlKey = 'ai_custom_base_url';
  static const _customModelKey = 'ai_custom_model';
  static const _customIsClaudeKey = 'ai_custom_is_claude';
  static const _openAiBaseUrlKey = 'ai_openai_compatible_base_url';
  static const _openAiModelKey = 'ai_openai_compatible_model';
  static const _anthropicBaseUrlKey = 'ai_anthropic_compatible_base_url';
  static const _anthropicModelKey = 'ai_anthropic_compatible_model';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  static const defaultOpenAiBaseUrl = 'https://api.openai.com/v1';
  static const defaultOpenAiModel = 'gpt-5-mini';
  static const defaultAnthropicBaseUrl = 'https://api.anthropic.com/v1';
  static const defaultAnthropicModel = 'claude-haiku-4-5-20251001';

  /// 获取当前选中的接口 ID
  String get selectedPresetId {
    return AiPreset.normalizeInterfaceId(
      _prefs.getString(_selectedPresetKey),
      legacyIsClaude: customIsClaude,
    );
  }

  /// 获取当前选中的接口配置
  AiPreset get selectedPreset {
    return presetForInterface(selectedPresetId);
  }

  AiPreset presetForInterface(String interfaceId) {
    final id = AiPreset.normalizeInterfaceId(interfaceId);
    final isAnthropic = id == AiPreset.anthropicCompatibleId;
    return AiPreset(
      id: id,
      name: isAnthropic ? 'Anthropic Compatible' : 'OpenAI Compatible',
      model: modelForInterface(id),
      baseUrl: baseUrlForInterface(id),
      isClaude: isAnthropic,
    );
  }

  /// 设置选中的接口
  Future<void> setSelectedPreset(String presetId) async {
    await _prefs.setString(
      _selectedPresetKey,
      AiPreset.normalizeInterfaceId(presetId),
    );
  }

  /// 获取指定预设的 API Key
  Future<String?> getApiKey(String presetId) async {
    final id = AiPreset.normalizeInterfaceId(presetId);
    final key = await _secureStorage.read(key: '$_apiKeyPrefix$id');
    if (key != null && key.isNotEmpty) return key;

    for (final legacyId in _legacyKeyIdsFor(id)) {
      final legacyKey = await _secureStorage.read(
        key: '$_apiKeyPrefix$legacyId',
      );
      if (legacyKey != null && legacyKey.isNotEmpty) return legacyKey;
    }
    return null;
  }

  /// 获取当前选中预设的 API Key
  Future<String?> get currentApiKey {
    return getApiKey(selectedPresetId);
  }

  /// 保存 API Key
  Future<void> saveApiKey(String presetId, String apiKey) {
    final id = AiPreset.normalizeInterfaceId(presetId);
    return _secureStorage.write(key: '$_apiKeyPrefix$id', value: apiKey);
  }

  /// 删除 API Key
  Future<void> deleteApiKey(String presetId) {
    final id = AiPreset.normalizeInterfaceId(presetId);
    return _secureStorage.delete(key: '$_apiKeyPrefix$id');
  }

  /// Custom AI settings
  String get customBaseUrl => _prefs.getString(_customBaseUrlKey) ?? '';
  String get customModel => _prefs.getString(_customModelKey) ?? '';
  bool get customIsClaude => _prefs.getBool(_customIsClaudeKey) ?? false;

  Future<void> setCustomBaseUrl(String url) =>
      _prefs.setString(_customBaseUrlKey, url);
  Future<void> setCustomModel(String model) =>
      _prefs.setString(_customModelKey, model);
  Future<void> setCustomIsClaude(bool value) =>
      _prefs.setBool(_customIsClaudeKey, value);

  String baseUrlForInterface(String interfaceId) {
    final id = AiPreset.normalizeInterfaceId(interfaceId);
    if (id == AiPreset.anthropicCompatibleId) {
      final saved = _prefs.getString(_anthropicBaseUrlKey);
      if (saved != null && saved.isNotEmpty) return saved;
      if (customIsClaude && customBaseUrl.isNotEmpty) return customBaseUrl;
      return defaultAnthropicBaseUrl;
    }

    final saved = _prefs.getString(_openAiBaseUrlKey);
    if (saved != null && saved.isNotEmpty) return saved;
    if (!customIsClaude && customBaseUrl.isNotEmpty) return customBaseUrl;
    return defaultOpenAiBaseUrl;
  }

  String modelForInterface(String interfaceId) {
    final id = AiPreset.normalizeInterfaceId(interfaceId);
    if (id == AiPreset.anthropicCompatibleId) {
      final saved = _prefs.getString(_anthropicModelKey);
      if (saved != null && saved.isNotEmpty) return saved;
      if (customIsClaude && customModel.isNotEmpty) return customModel;
      return defaultAnthropicModel;
    }

    final saved = _prefs.getString(_openAiModelKey);
    if (saved != null && saved.isNotEmpty) return saved;
    if (!customIsClaude && customModel.isNotEmpty) return customModel;
    return defaultOpenAiModel;
  }

  Future<void> setInterfaceConfig({
    required String interfaceId,
    required String baseUrl,
    required String model,
  }) async {
    final id = AiPreset.normalizeInterfaceId(interfaceId);
    if (id == AiPreset.anthropicCompatibleId) {
      await _prefs.setString(_anthropicBaseUrlKey, baseUrl);
      await _prefs.setString(_anthropicModelKey, model);
      return;
    }
    await _prefs.setString(_openAiBaseUrlKey, baseUrl);
    await _prefs.setString(_openAiModelKey, model);
  }

  List<String> _legacyKeyIdsFor(String interfaceId) {
    if (interfaceId == AiPreset.anthropicCompatibleId) {
      return const ['claude', 'custom'];
    }
    return const ['openai', 'gemini', 'deepseek', 'tongyi', 'zhipu', 'custom'];
  }
}
