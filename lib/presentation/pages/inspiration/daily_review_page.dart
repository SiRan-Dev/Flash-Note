import 'package:flashnote/core/utils/source_mapper.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/providers/review_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DailyReviewPage extends ConsumerStatefulWidget {
  const DailyReviewPage({super.key});

  @override
  ConsumerState<DailyReviewPage> createState() => _DailyReviewPageState();
}

class _DailyReviewPageState extends ConsumerState<DailyReviewPage> {
  int _currentIndex = 0;
  List<Inspiration> _inspirations = [];
  bool _initialized = false;
  bool _reviewCompleted = false;

  Widget _buildCompletedState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 96,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.allReviewed,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.allReviewedDesc,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final randomAsync = ref.watch(randomUnreviewedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyReview),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: randomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (inspirations) {
          if (_reviewCompleted || (_initialized && _inspirations.isEmpty)) {
            return _buildCompletedState(theme, l10n);
          }

          if (inspirations.isEmpty) {
            return _buildCompletedState(theme, l10n);
          }

          // Only capture list on first load; thereafter manage locally
          if (!_initialized) {
            _inspirations = List.from(inspirations);
            _currentIndex = 0;
            _initialized = true;
            _reviewCompleted = false;
          }

          if (_currentIndex >= _inspirations.length) {
            _currentIndex = _inspirations.length - 1;
          }
          if (_inspirations.isEmpty) {
            return _buildCompletedState(theme, l10n);
          }

          final current = _inspirations[_currentIndex];
          final source = current.source?.trim();
          final hasSource = source != null && source.isNotEmpty;

          return Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      '${_currentIndex + 1} / ${_inspirations.length}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _inspirations.length,
                      ),
                    ),
                  ],
                ),
              ),
              // Inspiration card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: AppPanel(
                    padding: EdgeInsets.zero,
                    radius: 28,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap:
                            () => context
                                .push('/inspiration/${current.id}')
                                .then((_) {
                                  ref.invalidate(randomUnreviewedProvider);
                                  _initialized = false;
                                }),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          child: Column(
                            children: [
                              if (hasSource) ...[
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.72),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      SourceMapper.displayName(context, source),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                              ],
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      current.content,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(height: 1.42),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                DateFormat(
                                  'yyyy年MM月dd日 HH:mm',
                                ).format(current.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final newValue = !current.needsFollowUp;
                          await ref
                              .read(inspirationRepositoryProvider)
                              .toggleNeedsFollowUp(current.id, newValue);
                          ref.invalidate(followUpInspirationsProvider);
                          if (!mounted) return;
                          // Update local copy
                          final idx = _inspirations.indexWhere(
                            (i) => i.id == current.id,
                          );
                          if (idx != -1) {
                            _inspirations[idx] = _inspirations[idx].copyWith(
                              needsFollowUp: newValue,
                            );
                          }
                          setState(() {});
                        },
                        icon: Icon(
                          current.needsFollowUp
                              ? Icons.flag
                              : Icons.flag_outlined,
                        ),
                        label: Text(
                          current.needsFollowUp
                              ? l10n.followingUp
                              : l10n.markFollowUp,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await ref
                              .read(inspirationRepositoryProvider)
                              .markReviewed(current.id);
                          ref.invalidate(unreviewedCountProvider);
                          ref.invalidate(randomUnreviewedProvider);
                          if (!mounted) return;
                          _inspirations.removeAt(_currentIndex);
                          if (_inspirations.isEmpty) {
                            setState(() {
                              _reviewCompleted = true;
                            });
                          } else {
                            if (_currentIndex >= _inspirations.length) {
                              _currentIndex = _inspirations.length - 1;
                            }
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: Text(l10n.markReviewed),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
