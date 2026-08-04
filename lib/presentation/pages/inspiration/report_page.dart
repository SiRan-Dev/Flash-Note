import 'dart:async';

import 'package:flashnote/core/utils/ai_text_formatter.dart';
import 'package:flashnote/core/utils/app_accent_palette.dart';
import 'package:flashnote/core/utils/source_mapper.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flashnote/presentation/providers/review_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum ReportType { weekly, monthly, insights }

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key, required this.type});

  final ReportType type;

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  String _reportContent = '';
  bool _isGenerating = false;
  StreamSubscription<String>? _subscription;

  String get _displayReportContent => normalizeAiPlainText(_reportContent);

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final db = ref.read(databaseProvider);
    final cached = await db.getLatestReportByType(widget.type.name);
    if (cached != null && mounted) {
      setState(() => _reportContent = normalizeAiPlainText(cached.content));
    }
  }

  Future<void> _saveCache(String content) async {
    final db = ref.read(databaseProvider);
    final preset = await ref.read(selectedPresetProvider.future);
    await db.upsertLatestReport(
      widget.type.name,
      normalizeAiPlainText(content),
      model: preset?.model ?? '',
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _title(AppLocalizations l10n) {
    switch (widget.type) {
      case ReportType.weekly:
        return l10n.weeklyReport;
      case ReportType.monthly:
        return l10n.monthlyReport;
      case ReportType.insights:
        return l10n.insights;
    }
  }

  Future<void> _generate() async {
    if (_isGenerating) return;

    final aiReady = await ref.read(aiConfigReadyProvider.future);
    if (!aiReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).apiKeyRequired)),
        );
      }
      return;
    }

    final preset = await ref.read(selectedPresetProvider.future);
    final apiKey = await ref.read(currentApiKeyProvider.future);
    if (preset == null || apiKey == null) return;

    setState(() {
      _isGenerating = true;
      _reportContent = '';
    });

    final inspirations =
        widget.type == ReportType.monthly
            ? await ref.read(monthlyInspirationsProvider.future)
            : await ref.read(weeklyInspirationsProvider.future);

    if (inspirations.isEmpty) {
      setState(() {
        _isGenerating = false;
        _reportContent = AppLocalizations.of(context).noInspirationsForReport;
      });
      return;
    }

    final projects = await ref.read(projectListProvider.future);
    final projectMap = {for (final p in projects) p.inspirationId: p};

    final inspirationsText = inspirations
        .map((i) {
          final date =
              '${i.createdAt.year}-${i.createdAt.month.toString().padLeft(2, '0')}-${i.createdAt.day.toString().padLeft(2, '0')} ${i.createdAt.hour.toString().padLeft(2, '0')}:${i.createdAt.minute.toString().padLeft(2, '0')}';
          final source =
              i.source != null
                  ? ' [来源: ${SourceMapper.displayName(context, i.source!)}]'
                  : '';
          final tags = i.tags.isNotEmpty ? ' [标签: ${i.tags.join(", ")}]' : '';
          final project = projectMap[i.id];
          String projectStatus = '';
          if (project != null) {
            projectStatus =
                ' [已转化为项目: ${project.title}, 进度: ${project.progress}%, 状态: ${project.status}]';
          }
          return '- [$date]$source$tags$projectStatus ${i.content}';
        })
        .join('\n');
    final relationshipText = await _buildRelationshipContext(
      inspirations.map((i) => i.id).toSet(),
    );
    final text =
        relationshipText.isEmpty
            ? inspirationsText
            : '$inspirationsText\n\n灵感关系：\n$relationshipText';

    final aiService = ref.read(aiServiceProvider);

    if (widget.type == ReportType.insights) {
      _subscription?.cancel();
      final stream = aiService.generateInsights(text, preset, apiKey);
      _subscription = stream.listen(
        (chunk) {
          if (mounted) {
            setState(() => _reportContent += chunk);
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isGenerating = false;
              _reportContent = normalizeAiPlainText(_reportContent);
            });
            _saveCache(_reportContent);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _isGenerating = false;
              _reportContent +=
                  '\n\n[${AppLocalizations.of(context).loadFailed}: $e]';
            });
          }
        },
      );
    } else {
      _subscription?.cancel();
      final period = widget.type == ReportType.weekly ? '本周' : '本月';
      final stream = aiService.generateReport(text, period, preset, apiKey);
      _subscription = stream.listen(
        (chunk) {
          if (mounted) {
            setState(() => _reportContent += chunk);
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isGenerating = false;
              _reportContent = normalizeAiPlainText(_reportContent);
            });
            _saveCache(_reportContent);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _isGenerating = false;
              _reportContent +=
                  '\n\n[${AppLocalizations.of(context).loadFailed}: $e]';
            });
          }
        },
      );
    }
  }

  Future<void> _resetAndGenerate() async {
    final db = ref.read(databaseProvider);
    await db.deleteAllReports();
    if (!mounted) return;
    setState(() => _reportContent = '');
    _generate();
  }

  Future<String> _buildRelationshipContext(
    Set<int> reportInspirationIds,
  ) async {
    final db = ref.read(databaseProvider);
    final inspirations = await ref.read(inspirationListProvider.future);
    final inspirationMap = {for (final i in inspirations) i.id: i};
    final links = await db.getAllInspirationLinks();
    if (links.isEmpty) return '';

    String snippet(int id) {
      final content = inspirationMap[id]?.content.trim();
      if (content == null || content.isEmpty) return '灵感#$id';
      return content.length > 36 ? '${content.substring(0, 36)}...' : content;
    }

    return links
        .where(
          (link) =>
              (reportInspirationIds.contains(link.sourceId) ||
                  reportInspirationIds.contains(link.targetId)) &&
              inspirationMap.containsKey(link.sourceId) &&
              inspirationMap.containsKey(link.targetId),
        )
        .map((link) {
          final type = _linkTypeLabel(link.linkType);
          final label = _relationLabel(link.relationLabel);
          final confidence = (link.confidence * 100).round();
          return '- ${snippet(link.sourceId)} -> ${snippet(link.targetId)} [关系: $type$label, 置信度: $confidence%]';
        })
        .join('\n');
  }

  String _linkTypeLabel(String type) {
    return switch (type) {
      'parentChild' || 'parent_child' => '层级',
      'causal' => '因果',
      'complementary' => '互补',
      'opposite' => '对立',
      _ => '相似',
    };
  }

  String _relationLabel(String? label) {
    return switch (label) {
      'belongsTo' => ' / 归属',
      'breakdown' => ' / 拆解',
      'supports' => ' / 支撑',
      'extends' => ' / 延展',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final copy = _ReportCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(l10n)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              _reportContent.isEmpty && !_isGenerating
                  ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: AppPanel(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppAccentPalette.tintSurfaceStrong(
                                  theme.colorScheme,
                                  theme.colorScheme.primary,
                                  amount: 0.26,
                                ),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.article_outlined,
                                size: 28,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              copy.emptyTitle(widget.type),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              copy.emptySubtitle(widget.type),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _generate,
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: Text(l10n.generateReport),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppPanel(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 420;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        compact
                                            ? constraints.maxWidth
                                            : constraints.maxWidth - 116,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      AppMetricChip(
                                        icon: Icons.article_outlined,
                                        label: copy.metricLabel(widget.type),
                                      ),
                                      if (_isGenerating)
                                        AppMetricChip(
                                          icon: Icons.auto_awesome_rounded,
                                          label: copy.generating,
                                          accentColor:
                                              theme.colorScheme.tertiary,
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 108,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton.filledTonal(
                                        onPressed:
                                            _reportContent.isNotEmpty &&
                                                    !_isGenerating
                                                ? _resetAndGenerate
                                                : null,
                                        tooltip: l10n.regenerate,
                                        icon: const Icon(Icons.refresh_rounded),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filledTonal(
                                        onPressed:
                                            _reportContent.isNotEmpty
                                                ? () {
                                                  Clipboard.setData(
                                                    ClipboardData(
                                                      text:
                                                          _displayReportContent,
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        copy.copied,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                : null,
                                        tooltip: copy.copy,
                                        icon: const Icon(Icons.copy_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: AppPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isGenerating && _reportContent.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 14),
                                  child: LinearProgressIndicator(),
                                ),
                              if (_isGenerating && _reportContent.isEmpty)
                                Expanded(
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 16),
                                        Text(copy.generating),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      _displayReportContent,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(height: 1.58),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _ReportCopy {
  const _ReportCopy({required this.isZh});

  _ReportCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get generating => isZh ? '正在生成' : 'Generating';
  String get copy => isZh ? '复制' : 'Copy';
  String get copied => isZh ? '已复制' : 'Copied';

  String metricLabel(ReportType type) {
    return switch (type) {
      ReportType.weekly => isZh ? '本周灵感报告' : 'Weekly report',
      ReportType.monthly => isZh ? '本月灵感报告' : 'Monthly report',
      ReportType.insights => isZh ? '洞察总结' : 'Insights',
    };
  }

  String emptyTitle(ReportType type) {
    return switch (type) {
      ReportType.weekly => isZh ? '生成本周灵感回顾' : "Generate this week's report",
      ReportType.monthly => isZh ? '生成本月灵感回顾' : "Generate this month's report",
      ReportType.insights => isZh ? '生成阶段性洞察总结' : 'Generate insight summary',
    };
  }

  String emptySubtitle(ReportType type) {
    return switch (type) {
      ReportType.weekly =>
        isZh
            ? '汇总本周的灵感、标签和项目转化，形成一份可读报告。'
            : "Summarize this week's ideas, tags, and project conversion.",
      ReportType.monthly =>
        isZh
            ? '从更长周期里整理关键趋势、主题和转化结果。'
            : 'Capture longer-running themes, trends, and conversions.',
      ReportType.insights =>
        isZh
            ? '让 AI 提炼更值得继续推进的主题和信号。'
            : 'Extract the strongest themes and signals worth pursuing.',
    };
  }
}
