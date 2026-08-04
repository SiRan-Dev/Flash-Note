import 'dart:async';
import 'dart:convert';

import 'package:flashnote/core/utils/app_accent_palette.dart';
import 'package:flashnote/domain/entities/ai_analysis_result.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AiAnalysisPage extends ConsumerStatefulWidget {
  const AiAnalysisPage({
    super.key,
    required this.inspirationId,
    required this.content,
  });

  final int inspirationId;
  final String content;

  @override
  ConsumerState<AiAnalysisPage> createState() => _AiAnalysisPageState();
}

class _AiAnalysisPageState extends ConsumerState<AiAnalysisPage> {
  AiAnalysisResult? _result;
  bool _isLoading = false;
  String? _error;
  String? _streamingText;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadCachedOrAnalyze();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedOrAnalyze() async {
    final cached = await ref.read(
      aiAnalysisCacheProvider(widget.inspirationId).future,
    );
    if (cached != null && mounted) {
      setState(() => _result = cached);
      return;
    }
    if (!mounted) return;
    _analyze();
  }

  Future<void> _analyze() async {
    final preset = await ref.read(selectedPresetProvider.future);
    final apiKey = await ref.read(currentApiKeyProvider.future);

    if (!mounted) return;

    if (preset == null || apiKey == null || apiKey.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).apiKeyRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
      _streamingText = '';
    });

    final buffer = StringBuffer();
    try {
      final service = ref.read(aiServiceProvider);
      _subscription?.cancel();
      final stream = service.analyze(widget.content, preset, apiKey);
      final completer = Completer<void>();
      _subscription = stream.listen(
        (chunk) {
          buffer.write(chunk);
          if (mounted) {
            setState(() => _streamingText = buffer.toString());
          }
        },
        onDone: completer.complete,
        onError: completer.completeError,
      );
      await completer.future;

      if (!mounted) return;
      final jsonStr = _extractJson(buffer.toString());
      final result = AiAnalysisResult.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      setState(() {
        _result = result;
        _isLoading = false;
        _streamingText = null;
      });
      await ref
          .read(inspirationRepositoryProvider)
          .updateAiAnalysis(widget.inspirationId, jsonEncode(result.toJson()));
      ref.invalidate(aiAnalysisCacheProvider(widget.inspirationId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _streamingText = null;
      });
    }
  }

  Future<void> _clearCache() async {
    await ref
        .read(inspirationRepositoryProvider)
        .updateAiAnalysis(widget.inspirationId, null);
    ref.invalidate(aiAnalysisCacheProvider(widget.inspirationId));
    if (!mounted) return;
    setState(() => _result = null);
    _analyze();
  }

  String _extractJson(String raw) {
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final match = jsonPattern.firstMatch(raw);
    if (match != null) return match.group(0)!;
    return raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final copy = _AnalysisCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.aiAnalysisResult),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.clearCache,
              onPressed: _clearCache,
            ),
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.reanalyze,
              onPressed: _analyze,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              _isLoading
                  ? _buildLoading(theme, l10n, copy)
                  : _error != null
                  ? _AnalysisStatePanel(
                    icon: Icons.error_outline_rounded,
                    title: _error!,
                    subtitle: copy.errorSubtitle,
                    accentColor: theme.colorScheme.error,
                    child: FilledButton.icon(
                      onPressed: _analyze,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.reanalyze),
                    ),
                  )
                  : _result != null
                  ? _buildResult(theme, l10n, copy)
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildLoading(
    ThemeData theme,
    AppLocalizations l10n,
    _AnalysisCopy copy,
  ) {
    if (_streamingText != null && _streamingText!.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPanel(
              borderColor: theme.colorScheme.primary.withValues(alpha: 0.24),
              child: Row(
                children: [
                  AppMetricChip(
                    icon: Icons.auto_awesome_rounded,
                    label: copy.streamTitle,
                  ),
                  const Spacer(),
                  Text(
                    l10n.aiAnalyzing,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  SelectableText(
                    _streamingText!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _AnalysisStatePanel(
      icon: Icons.analytics_outlined,
      title: l10n.aiAnalyzing,
      subtitle: copy.loadingSubtitle,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildResult(
    ThemeData theme,
    AppLocalizations l10n,
    _AnalysisCopy copy,
  ) {
    final cards = [
      (
        label: l10n.feasibility,
        score: _result!.feasibility,
        accent: theme.colorScheme.primary,
        icon: Icons.verified_outlined,
      ),
      (
        label: l10n.potential,
        score: _result!.potential,
        accent: theme.colorScheme.tertiary,
        icon: Icons.trending_up_rounded,
      ),
      (
        label: l10n.risk,
        score: _result!.risk,
        accent: theme.colorScheme.error,
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPanel(
            child: Row(
              children: [
                AppMetricChip(
                  icon: Icons.hub_outlined,
                  label: copy.summaryTitle,
                ),
                const Spacer(),
                Text(
                  copy.scoreSummary(cards.map((item) => item.score).toList()),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final card in cards) ...[
            _ScorePanel(
              label: card.label,
              score: card.score,
              accent: card.accent,
              icon: card.icon,
            ),
            const SizedBox(height: 12),
          ],
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppAccentPalette.tintSurfaceStrong(
                          theme.colorScheme,
                          theme.colorScheme.secondary,
                          amount: 0.26,
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.notes_rounded,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.suggestions,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SelectableText(
                  _result!.suggestions,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.label,
    required this.score,
    required this.accent,
    required this.icon,
  });

  final String label;
  final int score;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      borderColor: accent.withValues(alpha: 0.24),
      color: AppAccentPalette.tintSurface(
        theme.colorScheme,
        accent,
        amount: 0.16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppAccentPalette.tintSurfaceStrong(
                    theme.colorScheme,
                    accent,
                    amount: 0.26,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$score/10',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: (score / 10).clamp(0.0, 1.0),
              valueColor: AlwaysStoppedAnimation(accent),
              backgroundColor: accent.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisStatePanel extends StatelessWidget {
  const _AnalysisStatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AppPanel(
          borderColor: accent.withValues(alpha: 0.26),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppAccentPalette.tintSurfaceStrong(
                    theme.colorScheme,
                    accent,
                    amount: 0.26,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisCopy {
  const _AnalysisCopy({required this.isZh});

  _AnalysisCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get loadingSubtitle =>
      isZh ? '正在提炼灵感的可行性、潜力与风险。' : 'Evaluating feasibility, upside, and risk.';
  String get errorSubtitle =>
      isZh
          ? '可以重新触发分析，或者检查当前模型配置。'
          : 'Try the analysis again or verify the current model setup.';
  String get streamTitle => isZh ? '实时分析流' : 'Live analysis stream';
  String get summaryTitle => isZh ? '分析摘要' : 'Analysis summary';

  String scoreSummary(List<int> scores) {
    final average =
        scores.isEmpty
            ? 0
            : (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(
              1,
            );
    return isZh ? '均值 $average / 10' : 'Avg $average / 10';
  }
}
