import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flashnote/data/datasources/remote/mind_map_generation.dart';
import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/domain/entities/inspiration_link.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';
import 'package:flashnote/domain/services/ai_service.dart';

class OpenAiCompatibleStrategy {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 3),
    ),
  );

  Map<String, String> _headers(String apiKey) => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  Future<(bool, String?)> testConnection(AiPreset preset, String apiKey) async {
    try {
      final response = await _dio.post(
        '${preset.baseUrl}/chat/completions',
        options: Options(headers: _headers(apiKey)),
        data: {
          'model': preset.model,
          'max_tokens': 1,
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
        },
      );
      return (response.statusCode == 200, null);
    } on DioException catch (e) {
      final msg = e.response?.data?.toString() ?? e.message ?? e.toString();
      return (false, msg);
    } catch (e) {
      return (false, e.toString());
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
      data: {'model': preset.model, 'messages': messages, 'temperature': 0.7},
    );

    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>;
    final choice = choices[0] as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;
    return message['content'] as String;
  }

  Stream<String> analyze(
    String content,
    AiPreset preset,
    String apiKey,
  ) async* {
    const systemPrompt = '''
你是一个创意分析助手。请分析用户提供的灵感，返回 JSON 格式的结果。
返回格式（只返回 JSON，不要其他文字）：
{
  "feasibility": 1-10 的整数,
  "potential": 1-10 的整数,
  "risk": 1-10 的整数,
  "suggestions": "详细的建议文本"
}''';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': content},
    ];

    final response = await _dio.post(
      '${preset.baseUrl}/chat/completions',
      options: Options(
        headers: _headers(apiKey),
        responseType: ResponseType.stream,
      ),
      data: {
        'model': preset.model,
        'messages': messages,
        'temperature': 0.7,
        'stream': true,
      },
    );

    final body = response.data as ResponseBody;
    yield* _parseOpenAiSse(body.stream);
  }

  Future<MindMapNode> generateMindMap(
    String content,
    AiPreset preset,
    String apiKey,
  ) async {
    final raw = await _chat(mindMapSystemPrompt, content, [], preset, apiKey);
    final jsonStr = _extractJson(raw);
    return sanitizeMindMap(
      MindMapNode.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>),
    );
  }

  Stream<String> chat(
    String content,
    List<ChatMessage> history,
    AiPreset preset,
    String apiKey,
  ) async* {
    final systemPrompt =
        '你是一个创意助手。用户正在探讨以下灵感：\n\n$content\n\n请围绕这个灵感与用户进行深入对话。';
    final lastMessage = history.last.content;
    final priorHistory = history.sublist(0, history.length - 1);

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      for (final msg in priorHistory)
        {
          'role': msg.role == ChatRole.user ? 'user' : 'assistant',
          'content': msg.content,
        },
      {'role': 'user', 'content': lastMessage},
    ];

    final response = await _dio.post(
      '${preset.baseUrl}/chat/completions',
      options: Options(
        headers: _headers(apiKey),
        responseType: ResponseType.stream,
      ),
      data: {
        'model': preset.model,
        'messages': messages,
        'temperature': 0.7,
        'stream': true,
      },
    );

    final body = response.data as ResponseBody;
    yield* _parseOpenAiSse(body.stream);
  }

  Stream<String> globalChat(
    String userMessage,
    List<ChatMessage> history,
    String systemContext,
    AiPreset preset,
    String apiKey,
  ) async* {
    final lastMessage = history.last.content;
    final priorHistory = history.sublist(0, history.length - 1);

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemContext},
      for (final msg in priorHistory)
        {
          'role': msg.role == ChatRole.user ? 'user' : 'assistant',
          'content': msg.content,
        },
      {'role': 'user', 'content': lastMessage},
    ];

    final response = await _dio.post(
      '${preset.baseUrl}/chat/completions',
      options: Options(
        headers: _headers(apiKey),
        responseType: ResponseType.stream,
      ),
      data: {
        'model': preset.model,
        'messages': messages,
        'temperature': 0.7,
        'stream': true,
      },
    );

    final body = response.data as ResponseBody;
    yield* _parseOpenAiSse(body.stream);
  }

  Stream<String> _parseOpenAiSse(Stream<Uint8List> byteStream) async* {
    final lines = byteStream
        .transform(
          StreamTransformer<Uint8List, String>.fromHandlers(
            handleData: (data, sink) => sink.add(utf8.decode(data)),
          ),
        )
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final data = line.substring(6);
      if (data == '[DONE]') return;
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final choice = choices[0] as Map<String, dynamic>;
          final delta = choice['delta'] as Map<String, dynamic>?;
          final text = delta?['content'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        }
      } catch (_) {
        // skip malformed SSE lines
      }
    }
  }

  Future<List<AiDiscoveredLink>> findRelationships(
    int targetId,
    String targetContent,
    List<(int, String)> candidates,
    AiPreset preset,
    String apiKey,
  ) async {
    if (candidates.isEmpty) return [];

    final candidatesText = candidates
        .map((c) => '[ID: ${c.$1}] ${c.$2}')
        .join('\n\n');

    const systemPrompt = '''
你是一个灵感关联分析助手。给定一个目标灵感和一组候选灵感，请分析它们之间的关联关系。

关联类型：
- similar: 内容相似或主题相近
- causal: 因果关系（一个导致或影响另一个）
- complementary: 互补关系（互相补充完善）
- opposite: 对立关系（观点或方向相反）

返回格式（只返回 JSON，不要其他文字）：
{
  "links": [
    {"targetId": 候选灵感ID, "linkType": "similar/causal/complementary/opposite", "confidence": 0.0-1.0}
  ]
}

只返回 confidence >= 0.5 的关联。如果没有显著关联，返回空数组。''';

    final userMessage = '''
目标灵感 [ID: $targetId]:
$targetContent

候选灵感:
$candidatesText''';

    final raw = await _chat(systemPrompt, userMessage, [], preset, apiKey);
    final jsonStr = _extractJson(raw);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final links =
        (json['links'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>();

    return links.map<AiDiscoveredLink>((link) {
      final linkTypeStr = link['linkType'] as String;
      final linkType = switch (linkTypeStr) {
        'causal' => LinkType.causal,
        'complementary' => LinkType.complementary,
        'opposite' => LinkType.opposite,
        _ => LinkType.similar,
      };
      return AiDiscoveredLink(
        sourceId: targetId,
        targetId: link['targetId'] as int,
        linkType: linkType,
        confidence: (link['confidence'] as num).toDouble(),
      );
    }).toList();
  }

  Stream<String> generateReport(
    String inspirationsText,
    String period,
    AiPreset preset,
    String apiKey,
  ) async* {
    final systemPrompt = '''
你是一个灵感回顾助手。请根据用户提供的$period灵感记录，生成一份回顾报告。

报告格式要求：
1. 核心主题：提炼$period的主要灵感主题（2-3个）
2. 亮点灵感：挑选最有价值的 3-5 条灵感，简要点评
3. 趋势分析：这段时间的灵感趋势和变化
4. 行动建议：基于这些灵感，给出 2-3 条具体行动建议

输出要求：
- 只输出纯文本，不要使用 Markdown
- 不要输出 #、##、###、**、-、*、``` 等明显 Markdown 标记
- 可以使用“1.”、“2.”这类普通编号
- 小标题直接写文字，不要加井号
''';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': '$period灵感记录：\n\n$inspirationsText'},
    ];

    final response = await _dio.post(
      '${preset.baseUrl}/chat/completions',
      options: Options(
        headers: _headers(apiKey),
        responseType: ResponseType.stream,
      ),
      data: {
        'model': preset.model,
        'messages': messages,
        'temperature': 0.7,
        'stream': true,
      },
    );

    final body = response.data as ResponseBody;
    yield* _parseOpenAiSse(body.stream);
  }

  Stream<String> generateInsights(
    String inspirationsText,
    AiPreset preset,
    String apiKey,
  ) async* {
    const systemPrompt = '''
你是一个灵感分析助手。请逐条阅读数据中的每一条灵感记录，然后分析用户的灵感模式。

数据格式：
1. 灵感记录：每条格式为 "- [YYYY-MM-DD HH:MM] [来源: xxx] [标签: xxx] [已转化为项目: 标题, 进度: 百分比, 状态: xxx] 灵感内容"
2. 灵感关系：如果存在，会在“灵感关系：”后列出，格式为 "- A -> B [关系: 类型 / 语义, 置信度: xx%]"
- 时间在方括号内，格式为 [YYYY-MM-DD HH:MM]
- "已转化为项目"表示该灵感已转为项目，进度和状态反映完成情况
- 没有"已转化为项目"字段的灵感才算未转化为行动
- 关系类型包括：层级、因果、互补、对立、相似；层级关系中 A -> B 表示 A 是 B 的上级/父级线索

请严格按照以下要求分析：
1. 时间模式：逐一列出每条灵感的时间，统计上午(6-12点)/下午(12-18点)/晚上(18-24点)/深夜(0-6点)各有多少条，然后总结规律
2. 来源分析：统计每个来源的灵感数量
3. 主题分布：提炼主要主题
4. 行动转化：逐条判断是否有"已转化为项目"字段，统计已转化和未转化的数量
5. 关系网络：必须指出重要的灵感关系，包括层级主线、因果链、互补组合、对立冲突和相似重复；如果没有关系数据，也要明确说明“当前没有可分析的关系数据”
6. 产品推进：结合灵感关系，指出哪些灵感应该合并、拆解、延展为项目或作为某个项目的任务
7. 遗忘提醒：列出未转化且时间较早的灵感，优先提醒那些在关系网络中连接较多但尚未转化的灵感

输出要求：
- 只输出纯文本，不要使用 Markdown
- 不要输出 #、##、###、**、-、*、``` 等明显 Markdown 标记
- 可以使用“1.”、“2.”这类普通编号
- 小标题直接写文字，不要加井号
''';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': inspirationsText},
    ];

    final response = await _dio.post(
      '${preset.baseUrl}/chat/completions',
      options: Options(
        headers: _headers(apiKey),
        responseType: ResponseType.stream,
      ),
      data: {
        'model': preset.model,
        'messages': messages,
        'temperature': 0.7,
        'stream': true,
      },
    );

    final body = response.data as ResponseBody;
    yield* _parseOpenAiSse(body.stream);
  }

  String _extractJson(String raw) {
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final match = jsonPattern.firstMatch(raw);
    if (match != null) return match.group(0)!;
    return raw.trim();
  }
}
