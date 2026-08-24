import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/domain/entities/project.dart';

/// 将用户背景与全部灵感/项目聚合为一段文本，作为全局 AI 对话的系统上下文（"记忆"）。
/// 保持 context-free：来源显示名由调用方预构建后通过 [sourceLabels] 传入。
class CorpusBuilder {
  /// 语料超出该字符数时截断，避免 token 爆炸（v1 简单处理）。
  static const _maxCorpusLength = 12000;

  String build({
    required String background,
    required List<Inspiration> inspirations,
    required List<Project> projects,
    required Map<String, String> sourceLabels,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('你是用户的长期智能助手，了解用户的全部灵感、项目与个人背景。'
        '请基于以下用户背景与历史数据，连贯、有体系地帮助用户思考与行动。');

    if (background.trim().isNotEmpty) {
      buffer.writeln('\n===== 用户背景 =====');
      buffer.writeln(background.trim());
    }

    if (inspirations.isNotEmpty) {
      final projectMap = {for (final p in projects) p.inspirationId: p};
      buffer.writeln('\n===== 用户灵感库（共 ${inspirations.length} 条）=====');
      final inspirationsText = inspirations
          .map((i) {
            final date =
                '${i.createdAt.year}-${i.createdAt.month.toString().padLeft(2, '0')}-${i.createdAt.day.toString().padLeft(2, '0')} ${i.createdAt.hour.toString().padLeft(2, '0')}:${i.createdAt.minute.toString().padLeft(2, '0')}';
            final source =
                i.source != null
                    ? ' [来源: ${sourceLabels[i.source] ?? i.source}]'
                    : '';
            final tags =
                i.tags.isNotEmpty ? ' [标签: ${i.tags.join(", ")}]' : '';
            final project = i.id != null ? projectMap[i.id] : null;
            String projectStatus = '';
            if (project != null) {
              projectStatus =
                  ' [已转化为项目: ${project.title}, 进度: ${project.progress}%, 状态: ${project.status}]';
            }
            return '- [$date]$source$tags$projectStatus ${i.content}';
          })
          .join('\n');
      buffer.writeln(inspirationsText);
    }

    if (projects.isNotEmpty) {
      buffer.writeln('\n===== 用户项目（共 ${projects.length} 个）=====');
      for (final p in projects) {
        buffer.writeln(
          '- ${p.title}（进度: ${p.progress}%, 状态: ${p.status}）'
          '${p.description.isNotEmpty ? ': ${p.description}' : ''}',
        );
      }
    }

    final result = buffer.toString();
    if (result.length > _maxCorpusLength) {
      return '${result.substring(0, _maxCorpusLength)}\n……（数据较多，已截断部分历史）';
    }
    return result;
  }
}
