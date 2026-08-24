import 'package:flashnote/domain/entities/attachment.dart';
import 'package:flashnote/domain/entities/project.dart';
import 'package:flashnote/domain/entities/task.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flashnote/presentation/widgets/attachment_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final int projectId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  final _taskController = TextEditingController();

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final projectRepo = ref.watch(projectRepositoryProvider);
    final tasksAsync = ref.watch(taskListProvider(widget.projectId));
    final projectAsync = ref.watch(projectDetailProvider(widget.projectId));

    return PopScope(
      // Allow the default (predictive) back gesture to work. There is no
      // unsaved-state guard here, so we do not intercept the gesture.
      canPop: true,
      child: projectAsync.when(
        loading:
            () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
        error:
            (e, _) => Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('${l10n.loadFailed}: $e')),
            ),
        data: (project) {
          if (project == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(l10n.loadFailed)),
            );
          }

          final isCompleted = project.status == 'completed';
          final isActive = project.status == 'active';
          final progressValue = project.progress / 100.0;
          final navigationIconBrightness =
              theme.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              systemNavigationBarColor: theme.colorScheme.surface,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: navigationIconBrightness,
              systemNavigationBarContrastEnforced: false,
            ),
            child: Scaffold(
              appBar: AppBar(
                title: Text(project.title),
                actions: [
                  // Status toggle button (active <-> paused)
                  IconButton(
                    icon: Icon(
                      isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                    tooltip: isActive ? l10n.paused : l10n.active,
                    onPressed:
                        isCompleted
                            ? null
                            : () async {
                              final newStatus = isActive ? 'paused' : 'active';
                              await projectRepo.updateStatus(
                                project.id,
                                newStatus,
                              );
                              ref.invalidate(projectListProvider);
                              ref.invalidate(
                                projectDetailProvider(widget.projectId),
                              );
                            },
                  ),
                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final updated = await context.push<bool>(
                        '/project/${project.id}/edit',
                      );
                      if (updated == true) {
                        ref.invalidate(projectListProvider);
                        ref.invalidate(projectDetailProvider(widget.projectId));
                      }
                    },
                  ),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: Text(l10n.deleteProject),
                              content: Text(l10n.deleteProjectConfirm),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(l10n.delete),
                                ),
                              ],
                            ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(projectListProvider.notifier)
                            .delete(project.id);
                        if (context.mounted) context.pop();
                      }
                    },
                  ),
                ],
              ),
              body: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        MediaQuery.of(context).padding.bottom + 104,
                      ),
                      children: [
                        _ProjectInfoSection(
                          project: project,
                          theme: theme,
                          l10n: l10n,
                          progressValue: progressValue,
                        ),
                        const SizedBox(height: 14),
                        AppPanel(
                          child: AttachmentSection(
                            ownerType: AttachmentOwnerType.project,
                            ownerId: project.id,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppPanel(
                          child: _TaskSection(
                            tasksAsync: tasksAsync,
                            l10n: l10n,
                            onToggle: (taskId) {
                              ref
                                  .read(
                                    taskListProvider(widget.projectId).notifier,
                                  )
                                  .toggleComplete(taskId);
                            },
                            onDelete: (taskId) {
                              ref
                                  .read(
                                    taskListProvider(widget.projectId).notifier,
                                  )
                                  .deleteTask(taskId);
                            },
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _AddTaskBar(
                        controller: _taskController,
                        l10n: l10n,
                        onAdd: () {
                          final title = _taskController.text.trim();
                          if (title.isNotEmpty) {
                            ref
                                .read(
                                  taskListProvider(widget.projectId).notifier,
                                )
                                .addTask(title);
                            _taskController.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Displays project title, description, progress bar, and status badge.
class _ProjectInfoSection extends StatelessWidget {
  const _ProjectInfoSection({
    required this.project,
    required this.theme,
    required this.l10n,
    required this.progressValue,
  });

  final Project project;
  final ThemeData theme;
  final AppLocalizations l10n;
  final double progressValue;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (project.status) {
      'active' => l10n.active,
      'paused' => l10n.paused,
      'completed' => l10n.completed,
      _ => project.status,
    };

    final statusColor = switch (project.status) {
      'active' => theme.colorScheme.primary,
      'paused' => theme.colorScheme.outline,
      'completed' => theme.colorScheme.tertiary,
      _ => theme.colorScheme.outline,
    };

    return AppPanel(
      borderColor:
          project.isPinned
              ? theme.colorScheme.primary.withValues(alpha: 0.42)
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (project.isPinned) ...[
                Icon(
                  Icons.push_pin_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(project.title, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(statusLabel),
                backgroundColor: statusColor.withValues(alpha: 0.15),
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              project.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.48,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 18, color: statusColor),
              const SizedBox(width: 6),
              Text(
                l10n.progress,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${project.progress}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.tasksAsync,
    required this.l10n,
    required this.onToggle,
    required this.onDelete,
  });

  final AsyncValue<List<Task>> tasksAsync;
  final AppLocalizations l10n;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.tasks,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        tasksAsync.when(
          loading:
              () => const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (e, _) => _InlineState(
                icon: Icons.error_outline_rounded,
                title: l10n.loadFailed,
                subtitle: '$e',
              ),
          data: (tasks) {
            if (tasks.isEmpty) {
              return _InlineState(
                icon: Icons.task_outlined,
                title: l10n.noTasksYet,
                subtitle: l10n.addYourFirstTask,
              );
            }

            final allDone = tasks.every((task) => task.isCompleted);
            return Column(
              children: [
                if (allDone) ...[
                  _CompletionBanner(label: l10n.allTasksCompleted),
                  const SizedBox(height: 10),
                ],
                for (final task in tasks) ...[
                  _TaskTile(
                    task: task,
                    l10n: l10n,
                    onToggle: () => onToggle(task.id),
                    onDelete: () => onDelete(task.id),
                  ),
                  if (task != tasks.last) const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.l10n,
    required this.onToggle,
    required this.onDelete,
  });

  final Task task;
  final AppLocalizations l10n;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.deleteTask),
            content: Text(l10n.deleteTaskConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Checkbox(value: task.isCompleted, onChanged: (_) => onToggle()),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                      color:
                          task.isCompleted
                              ? theme.colorScheme.outline
                              : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.deleteTask,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () async {
                    if (await _confirmDelete(context)) {
                      onDelete();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_rounded,
            size: 18,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.32,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Text input bar at the bottom for adding tasks.
class _AddTaskBar extends StatelessWidget {
  const _AddTaskBar({
    required this.controller,
    required this.l10n,
    required this.onAdd,
  });

  final TextEditingController controller;
  final AppLocalizations l10n;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
      borderSide: BorderSide.none,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
        ),
        child: AppPanel(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          radius: 28,
          shadowAlpha: 0.12,
          borderColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: l10n.taskTitleHint,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder,
                    disabledBorder: inputBorder,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(icon: const Icon(Icons.add), onPressed: onAdd),
            ],
          ),
        ),
      ),
    );
  }
}
