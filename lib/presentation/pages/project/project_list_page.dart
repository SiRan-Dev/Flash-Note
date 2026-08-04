import 'package:flashnote/domain/entities/project.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flashnote/presentation/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _ProjectSortMode {
  pinnedFirst,
  recentlyUpdated,
  newestCreated,
  oldestCreated,
  progressHigh,
  progressLow,
}

class ProjectListPage extends ConsumerStatefulWidget {
  const ProjectListPage({super.key});

  @override
  ConsumerState<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends ConsumerState<ProjectListPage> {
  _ProjectSortMode _sortMode = _ProjectSortMode.pinnedFirst;

  Future<void> _openCreateProjectPage() async {
    await context.push('/project/new');
    if (!mounted) return;
    ref.read(projectListProvider.notifier).refresh();
  }

  Future<void> _openProjectDetail(int id) async {
    await context.push('/project/$id');
    if (!mounted) return;
    ref.read(projectListProvider.notifier).refresh();
  }

  void _showContextMenu(BuildContext context, Project project) {
    final l10n = AppLocalizations.of(context);
    final copy = _ProjectListCopy.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.sort_rounded),
                  title: Text(copy.sortBy),
                  subtitle: Text(copy.projectSortLabel(_sortMode)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSortSheet(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    project.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  ),
                  title: Text(project.isPinned ? l10n.unpin : l10n.pin),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(projectListProvider.notifier)
                        .togglePin(project.id);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    l10n.delete,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, l10n, project);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showSortSheet(BuildContext context) {
    final copy = _ProjectListCopy.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      copy.sortBy,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                RadioGroup<_ProjectSortMode>(
                  groupValue: _sortMode,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortMode = value);
                    Navigator.pop(ctx);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final mode in _ProjectSortMode.values)
                        RadioListTile<_ProjectSortMode>(
                          value: mode,
                          title: Text(copy.projectSortLabel(mode)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  List<Project> _sortProjects(List<Project> projects) {
    final sorted = [...projects];
    int byRecentlyUpdated(Project a, Project b) =>
        b.updatedAt.compareTo(a.updatedAt);
    int byNewestCreated(Project a, Project b) =>
        b.createdAt.compareTo(a.createdAt);
    int byOldestCreated(Project a, Project b) =>
        a.createdAt.compareTo(b.createdAt);
    int byProgressHigh(Project a, Project b) {
      final progressCompare = b.progress.compareTo(a.progress);
      if (progressCompare != 0) return progressCompare;
      return byRecentlyUpdated(a, b);
    }

    int byProgressLow(Project a, Project b) {
      final progressCompare = a.progress.compareTo(b.progress);
      if (progressCompare != 0) return progressCompare;
      return byRecentlyUpdated(a, b);
    }

    int byPinnedFirst(Project a, Project b) {
      final pinCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pinCompare != 0) return pinCompare;
      return byRecentlyUpdated(a, b);
    }

    sorted.sort(switch (_sortMode) {
      _ProjectSortMode.pinnedFirst => byPinnedFirst,
      _ProjectSortMode.recentlyUpdated => byRecentlyUpdated,
      _ProjectSortMode.newestCreated => byNewestCreated,
      _ProjectSortMode.oldestCreated => byOldestCreated,
      _ProjectSortMode.progressHigh => byProgressHigh,
      _ProjectSortMode.progressLow => byProgressLow,
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final projectListAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.projects)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return projectListAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.loadFailed, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed:
                            () =>
                                ref
                                    .read(projectListProvider.notifier)
                                    .refresh(),
                        child: Text(l10n.reanalyze),
                      ),
                    ],
                  ),
                ),
            data: (projects) {
              if (projects.isEmpty) {
                return _EmptyState(
                  theme: theme,
                  l10n: l10n,
                  onCreate: _openCreateProjectPage,
                );
              }
              final sortedProjects = _sortProjects(projects);
              return RefreshIndicator(
                onRefresh:
                    () => ref.read(projectListProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: AppLayout.pageInsets(constraints),
                  itemCount: sortedProjects.length,
                  itemBuilder: (context, index) {
                    final project = sortedProjects[index];
                    return _ProjectCard(
                      project: project,
                      theme: theme,
                      l10n: l10n,
                      onTap: () => _openProjectDetail(project.id),
                      onLongPress: () => _showContextMenu(context, project),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateProjectPage,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    Project project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.deleteProject),
            content: Text(l10n.deleteProjectConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await ref.read(projectListProvider.notifier).delete(project.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.theme,
    required this.l10n,
    required this.onCreate,
  });

  final ThemeData theme;
  final AppLocalizations l10n;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(l10n.noProjectsYet, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(l10n.createYourFirstProject),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Project card
// ---------------------------------------------------------------------------

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.theme,
    required this.l10n,
    required this.onTap,
    required this.onLongPress,
  });

  final Project project;
  final ThemeData theme;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onSecondaryTap: onLongPress,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
                // Title row with pin icon and status badge
                Row(
                  children: [
                    if (project.isPinned) ...[
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        project.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: project.status, l10n: l10n),
                  ],
                ),
                // Description snippet
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    project.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: project.progress / 100,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${project.progress}%',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.l10n});

  final String status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => (l10n.active, Colors.green),
      'paused' => (l10n.paused, Colors.orange),
      'completed' => (l10n.completed, Colors.grey),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ProjectListCopy {
  const _ProjectListCopy({required this.isZh});

  _ProjectListCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get sortBy => isZh ? '排序方式' : 'Sort by';

  String projectSortLabel(_ProjectSortMode mode) {
    return switch (mode) {
      _ProjectSortMode.pinnedFirst => isZh ? '置顶优先' : 'Pinned first',
      _ProjectSortMode.recentlyUpdated => isZh ? '最近更新' : 'Recently updated',
      _ProjectSortMode.newestCreated => isZh ? '最新创建' : 'Newest created',
      _ProjectSortMode.oldestCreated => isZh ? '最早创建' : 'Oldest created',
      _ProjectSortMode.progressHigh => isZh ? '进度从高到低' : 'Progress high to low',
      _ProjectSortMode.progressLow => isZh ? '进度从低到高' : 'Progress low to high',
    };
  }
}
