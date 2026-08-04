import 'dart:convert';

import 'package:flashnote/data/datasources/local/ai_settings_storage.dart';
import 'package:flashnote/data/datasources/remote/ai_service_impl.dart';
import 'package:flashnote/domain/entities/ai_analysis_result.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';
import 'package:flashnote/domain/services/ai_service.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// AI 分析结果缓存 Provider（从数据库读取）
final aiAnalysisCacheProvider =
    FutureProvider.family<AiAnalysisResult?, int>((ref, inspirationId) async {
  final repo = ref.watch(inspirationRepositoryProvider);
  final inspiration = await repo.getById(inspirationId);
  if (inspiration?.aiAnalysis == null) return null;
  try {
    return AiAnalysisResult.fromJson(
        jsonDecode(inspiration!.aiAnalysis!) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// 思维导图缓存 Provider（从数据库读取）
final mindMapCacheProvider =
    FutureProvider.family<MindMapNode?, int>((ref, inspirationId) async {
  final repo = ref.watch(inspirationRepositoryProvider);
  final inspiration = await repo.getById(inspirationId);
  if (inspiration?.mindMapData == null) return null;
  try {
    return MindMapNode.fromJson(
        jsonDecode(inspiration!.mindMapData!) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// 聊天记录缓存 Provider（从数据库读取）
final chatMessagesCacheProvider =
    FutureProvider.family<List<ChatMessage>, int>((ref, inspirationId) {
  final repo = ref.watch(chatMessageRepositoryProvider);
  return repo.getByInspirationId(inspirationId);
});
