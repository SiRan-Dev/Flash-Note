import 'package:flashnote/core/utils/source_mapper.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flashnote/presentation/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: AppLayout.pageInsets(constraints, top: 24, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recent Inspirations
                  _SectionHeader(title: l10n.recentInspirations),
                  const SizedBox(height: 12),
                  _RecentInspirationsList(),
                  const SizedBox(height: 16),

                  _PrimaryCaptureAction(),
                  const SizedBox(height: 32),

                  _TodayTodosSection(),

                  // Quick Actions
                  _SectionHeader(title: l10n.quickActions),
                  const SizedBox(height: 12),
                  _QuickActions(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PrimaryCaptureAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => context.push('/inspiration/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          l10n.captureInspiration,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _RecentInspirationsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final inspirationsAsync = ref.watch(homeRecentInspirationsProvider);

    return inspirationsAsync.when(
      loading:
          () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, _) => SizedBox(
            height: 120,
            child: Center(child: Text(l10n.loadFailed)),
          ),
      data: (inspirations) {
        if (inspirations.isEmpty) {
          return SizedBox(
            height: 120,
            child: Center(child: Text(l10n.noInspirationYet)),
          );
        }

        final recent = inspirations.take(5).toList();
        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder:
                (context, index) =>
                    _RecentInspirationCard(inspiration: recent[index]),
          ),
        );
      },
    );
  }
}

class _RecentInspirationCard extends StatelessWidget {
  const _RecentInspirationCard({required this.inspiration});

  final Inspiration inspiration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 200,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/inspiration/${inspiration.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inspiration.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                if (inspiration.source != null)
                  Text(
                    SourceMapper.displayName(context, inspiration.source!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayTodosSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(incompleteTasksProvider);
    final projectsAsync = ref.watch(projectListProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(l10n.loadFailed)),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return projectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(l10n.loadFailed)),
          data: (projects) {
            final projectMap = {for (final p in projects) p.id: p};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: l10n.todayTodos),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final project = projectMap[task.projectId];
                    return ListTile(
                      leading: Icon(
                        Icons.circle_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(task.title),
                      subtitle: project != null ? Text(project.title) : null,
                      onTap: () => context.push('/project/${task.projectId}'),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final actions = [
      _QuickActionData(
        title: l10n.dailyReview,
        subtitle: l10n.dailyReviewDesc,
        icon: Icons.today_outlined,
        route: '/daily-review',
      ),
      _QuickActionData(
        title: l10n.knowledgeGraph,
        subtitle: l10n.knowledgeGraphDesc,
        icon: Icons.account_tree_outlined,
        route: '/knowledge-graph',
      ),
      _QuickActionData(
        title: l10n.weeklyReport,
        subtitle: l10n.weeklyReportDesc,
        icon: Icons.assessment_outlined,
        route: '/report/weekly',
      ),
      _QuickActionData(
        title: l10n.insights,
        subtitle: l10n.insightsDesc,
        icon: Icons.lightbulb_outline,
        route: '/report/insights',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final columns = isWide ? 2 : 1;
        final spacing = isWide ? 12.0 : 10.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: _QuickActionCard(action: action),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _QuickActionData action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(action.route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(action.icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
