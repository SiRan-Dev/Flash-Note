import 'package:flashnote/data/datasources/remote/claude_strategy.dart';
import 'package:flashnote/data/datasources/remote/openai_compatible_strategy.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';
import 'package:flashnote/domain/services/ai_service.dart';

class AiServiceImpl implements AiService {
  final _openAiStrategy = OpenAiCompatibleStrategy();
  final _claudeStrategy = ClaudeStrategy();

  @override
  Future<(bool, String?)> testConnection(AiPreset preset, String apiKey) {
    if (preset.isClaude) {
      return _claudeStrategy.testConnection(preset, apiKey);
    }
    return _openAiStrategy.testConnection(preset, apiKey);
  }

  @override
  Stream<String> analyze(String content, AiPreset preset, String apiKey) {
    if (preset.isClaude) {
      return _claudeStrategy.analyze(content, preset, apiKey);
    }
    return _openAiStrategy.analyze(content, preset, apiKey);
  }

  @override
  Future<MindMapNode> generateMindMap(
    String content,
    AiPreset preset,
    String apiKey,
  ) {
    if (preset.isClaude) {
      return _claudeStrategy.generateMindMap(content, preset, apiKey);
    }
    return _openAiStrategy.generateMindMap(content, preset, apiKey);
  }

  @override
  Stream<String> chat(
    String content,
    List<ChatMessage> history,
    AiPreset preset,
    String apiKey,
  ) {
    if (preset.isClaude) {
      return _claudeStrategy.chat(content, history, preset, apiKey);
    }
    return _openAiStrategy.chat(content, history, preset, apiKey);
  }

  @override
  Stream<String> globalChat(
    String userMessage,
    List<ChatMessage> history,
    String systemContext,
    AiPreset preset,
    String apiKey,
  ) {
    if (preset.isClaude) {
      return _claudeStrategy.globalChat(
        userMessage,
        history,
        systemContext,
        preset,
        apiKey,
      );
    }
    return _openAiStrategy.globalChat(
      userMessage,
      history,
      systemContext,
      preset,
      apiKey,
    );
  }

  @override
  Future<List<AiDiscoveredLink>> findRelationships(
    int targetId,
    String targetContent,
    List<(int, String)> candidates,
    AiPreset preset,
    String apiKey,
  ) {
    if (preset.isClaude) {
      return _claudeStrategy.findRelationships(
        targetId,
        targetContent,
        candidates,
        preset,
        apiKey,
      );
    }
    return _openAiStrategy.findRelationships(
      targetId,
      targetContent,
      candidates,
      preset,
      apiKey,
    );
  }

  @override
  Stream<String> generateReport(
    String inspirationsText,
    String period,
    AiPreset preset,
    String apiKey,
  ) {
    if (preset.isClaude) {
      return _claudeStrategy.generateReport(
        inspirationsText,
        period,
        preset,
        apiKey,
      );
    }
    return _openAiStrategy.generateReport(
      inspirationsText,
      period,
      preset,
      apiKey,
    );
  }

  @override
  Stream<String> generateInsights(
    String inspirationsText,
    AiPreset preset,
    String apiKey,
  ) {
    if (preset.isClaude) {
      return _claudeStrategy.generateInsights(inspirationsText, preset, apiKey);
    }
    return _openAiStrategy.generateInsights(inspirationsText, preset, apiKey);
  }
}
