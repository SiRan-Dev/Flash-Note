import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/entities/inspiration_link.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';

/// AI 发现的灵感关联结果
class AiDiscoveredLink {
  final int sourceId;
  final int targetId;
  final LinkType linkType;
  final double confidence;

  const AiDiscoveredLink({
    required this.sourceId,
    required this.targetId,
    required this.linkType,
    required this.confidence,
  });
}

abstract class AiService {
  /// 测试当前配置的 AI 服务连接
  /// 返回 (success, errorMessage)
  Future<(bool, String?)> testConnection(AiPreset preset, String apiKey);

  /// 分析灵感（流式）
  Stream<String> analyze(String content, AiPreset preset, String apiKey);

  /// 生成思维导图
  Future<MindMapNode> generateMindMap(
    String content,
    AiPreset preset,
    String apiKey,
  );

  /// AI 对话（流式）
  Stream<String> chat(
    String content,
    List<ChatMessage> history,
    AiPreset preset,
    String apiKey,
  );

  /// 分析灵感之间的关联关系
  Future<List<AiDiscoveredLink>> findRelationships(
    int targetId,
    String targetContent,
    List<(int, String)> candidates,
    AiPreset preset,
    String apiKey,
  );

  /// 生成灵感回顾报告（周报/月报）
  /// [inspirationsText] 灵感列表的文本摘要
  /// [period] 报告周期，如 "本周" / "本月"
  Stream<String> generateReport(
    String inspirationsText,
    String period,
    AiPreset preset,
    String apiKey,
  );

  /// 生成 AI 洞察
  Stream<String> generateInsights(
    String inspirationsText,
    AiPreset preset,
    String apiKey,
  );
}
