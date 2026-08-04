import 'package:flashnote/core/utils/source_icon_builder.dart';
import 'package:flashnote/core/utils/source_mapper.dart';
import 'package:flashnote/domain/entities/attachment.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/domain/entities/inspiration_link.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/inspiration_link_providers.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flashnote/presentation/providers/source_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flashnote/presentation/widgets/attachment_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class InspirationDetailPage extends ConsumerStatefulWidget {
  const InspirationDetailPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<InspirationDetailPage> createState() =>
      _InspirationDetailPageState();
}

class _InspirationDetailPageState extends ConsumerState<InspirationDetailPage> {
  void _refreshDetail() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(inspirationRepositoryProvider);

    return FutureBuilder<Inspiration?>(
      future: repo.getById(widget.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final inspiration = snapshot.data;
        if (inspiration == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(AppLocalizations.of(context).loadFailed)),
          );
        }

        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final dateStr = DateFormat(
          'yyyy年MM月dd日 HH:mm',
        ).format(inspiration.createdAt);
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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    inspiration.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                  ),
                  onPressed: () async {
                    await ref
                        .read(inspirationRepositoryProvider)
                        .togglePin(inspiration.id);
                    ref.read(inspirationListProvider.notifier).refresh();
                    ref.invalidate(homeRecentInspirationsProvider);
                    // ignore: use_build_context_synchronously
                    if (context.mounted) {
                      // Force rebuild by popping and re-pushing would be complex,
                      // so we just mark the element as needing rebuild
                      (context as Element).markNeedsBuild();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final updated = await context.push<bool>(
                      '/inspiration/${inspiration.id}/edit',
                    );
                    if (updated == true) {
                      ref.read(inspirationListProvider.notifier).refresh();
                      ref.invalidate(homeRecentInspirationsProvider);
                      _refreshDetail();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: Text(l10n.deleteInspiration),
                            content: Text(l10n.deleteInspirationConfirm),
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
                          .read(inspirationRepositoryProvider)
                          .delete(inspiration.id);
                      ref.read(inspirationListProvider.notifier).refresh();
                      ref.invalidate(homeRecentInspirationsProvider);
                      if (context.mounted) context.pop();
                    }
                  },
                ),
              ],
            ),
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InspirationHeroPanel(
                      inspiration: inspiration,
                      dateText: dateStr,
                    ),
                    const SizedBox(height: 14),
                    AppPanel(
                      child: AttachmentSection(
                        ownerType: AttachmentOwnerType.inspiration,
                        ownerId: inspiration.id,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppPanel(
                      child: _RelatedInspirationsSection(
                        inspirationId: inspiration.id,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DetailSectionPanel(
                      icon: Icons.auto_awesome_rounded,
                      title: l10n.aiCapabilities,
                      child: Column(
                        children: [
                          _CapabilityTile(
                            icon: Icons.analytics_outlined,
                            title: l10n.aiAnalysis,
                            subtitle:
                                inspiration.aiAnalysis != null
                                    ? l10n.hasCachedResult
                                    : l10n.aiAnalysisDesc,
                            checked: inspiration.aiAnalysis != null,
                            onTap: () async {
                              await context.push(
                                '/inspiration/${inspiration.id}/ai-analysis',
                                extra: inspiration.content,
                              );
                              _refreshDetail();
                            },
                          ),
                          const SizedBox(height: 10),
                          _CapabilityTile(
                            icon: Icons.account_tree_outlined,
                            title: l10n.mindMap,
                            subtitle:
                                inspiration.mindMapData != null
                                    ? l10n.hasCachedMindMap
                                    : l10n.mindMapDesc,
                            checked: inspiration.mindMapData != null,
                            onTap: () async {
                              await context.push(
                                '/inspiration/${inspiration.id}/mind-map',
                                extra: inspiration.content,
                              );
                              _refreshDetail();
                            },
                          ),
                          const SizedBox(height: 10),
                          _ChatListTile(
                            inspirationId: inspiration.id,
                            content: inspiration.content,
                          ),
                          const SizedBox(height: 10),
                          _CapabilityTile(
                            icon: Icons.folder_outlined,
                            title: l10n.inspirationToProject,
                            subtitle: l10n.createProjectDesc,
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: Text(l10n.inspirationToProject),
                                      content: Text(
                                        l10n.inspirationToProjectConfirm,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, false),
                                          child: Text(l10n.cancel),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
                                          child: Text(l10n.createProject),
                                        ),
                                      ],
                                    ),
                              );
                              if (confirmed == true) {
                                final projectRepo = ref.read(
                                  projectRepositoryProvider,
                                );
                                final taskRepo = ref.read(
                                  taskRepositoryProvider,
                                );

                                final content = inspiration.content;
                                final title =
                                    content.length > 50
                                        ? content.substring(0, 50)
                                        : content;

                                final newProjectId = await projectRepo.create(
                                  title,
                                  description: content,
                                  inspirationId: inspiration.id,
                                );

                                await taskRepo.create(newProjectId, '梳理灵感思路');

                                ref
                                    .read(projectListProvider.notifier)
                                    .refresh();
                                ref.invalidate(incompleteTasksProvider);

                                if (context.mounted) {
                                  context.push('/project/$newProjectId');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InspirationHeroPanel extends StatelessWidget {
  const _InspirationHeroPanel({
    required this.inspiration,
    required this.dateText,
  });

  final Inspiration inspiration;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        inspiration.isPinned
            ? theme.colorScheme.primary.withValues(alpha: 0.42)
            : null;

    return AppPanel(
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (inspiration.isPinned)
                AppMetricChip(
                  icon: Icons.push_pin_rounded,
                  label: AppLocalizations.of(context).pin,
                ),
              if (inspiration.source != null)
                Chip(
                  avatar: _SourceIconChip(sourceName: inspiration.source!),
                  label: Text(
                    SourceMapper.displayName(context, inspiration.source!),
                    style: theme.textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              AppMetricChip(icon: Icons.schedule_rounded, label: dateText),
            ],
          ),
          const SizedBox(height: 18),
          SelectableText(
            inspiration.content,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
          if (inspiration.tags.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  inspiration.tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag, style: theme.textTheme.labelSmall),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSectionPanel extends StatelessWidget {
  const _DetailSectionPanel({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.checked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.56,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (checked) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatListTile extends ConsumerWidget {
  const _ChatListTile({required this.inspirationId, required this.content});

  final int inspirationId;
  final String content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chatAsync = ref.watch(chatMessagesCacheProvider(inspirationId));

    final hasHistory =
        chatAsync.whenOrNull(data: (messages) => messages.isNotEmpty) ?? false;

    return _CapabilityTile(
      icon: Icons.chat_outlined,
      title: l10n.aiChat,
      subtitle: hasHistory ? l10n.hasChatHistory : l10n.aiChatDesc,
      checked: hasHistory,
      onTap:
          () =>
              context.push('/inspiration/$inspirationId/chat', extra: content),
    );
  }
}

class _RelatedInspirationsSection extends ConsumerWidget {
  const _RelatedInspirationsSection({required this.inspirationId});

  final int inspirationId;

  void _showManualLinkDialog(
    BuildContext context,
    WidgetRef ref, {
    LinkType initialType = LinkType.similar,
    bool currentIsParent = true,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (ctx) => _ManualLinkSheet(
            inspirationId: inspirationId,
            initialType: initialType,
            currentIsParent: currentIsParent,
            onLinked:
                () => ref.invalidate(inspirationLinksProvider(inspirationId)),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final linksAsync = ref.watch(inspirationLinksProvider(inspirationId));

    return linksAsync.when(
      loading:
          () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      error: (_, _) => const SizedBox.shrink(),
      data: (links) {
        final parentLinks =
            links
                .where(
                  (link) =>
                      link.linkType == LinkType.parentChild &&
                      link.targetId == inspirationId,
                )
                .toList();
        final childLinks =
            links
                .where(
                  (link) =>
                      link.linkType == LinkType.parentChild &&
                      link.sourceId == inspirationId,
                )
                .toList();
        final relatedLinks =
            links
                .where((link) => link.linkType != LinkType.parentChild)
                .toList();

        if (links.isEmpty) {
          return _RelationshipEmptyState(
            onAddParent:
                () => _showManualLinkDialog(
                  context,
                  ref,
                  initialType: LinkType.parentChild,
                  currentIsParent: false,
                ),
            onAddChild:
                () => _showManualLinkDialog(
                  context,
                  ref,
                  initialType: LinkType.parentChild,
                ),
            onAddRelated: () => _showManualLinkDialog(context, ref),
            onDiscover: () async {
              await ref.read(autoDiscoverLinksProvider(inspirationId).future);
              ref.invalidate(inspirationLinksProvider(inspirationId));
            },
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.hierarchyRelations,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.vertical_align_top_rounded, size: 20),
                  tooltip: l10n.addParentInspiration,
                  onPressed:
                      () => _showManualLinkDialog(
                        context,
                        ref,
                        initialType: LinkType.parentChild,
                        currentIsParent: false,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.subdirectory_arrow_right, size: 20),
                  tooltip: l10n.addChildInspiration,
                  onPressed:
                      () => _showManualLinkDialog(
                        context,
                        ref,
                        initialType: LinkType.parentChild,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_link, size: 20),
                  tooltip: l10n.addRelation,
                  onPressed: () => _showManualLinkDialog(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.auto_fix_high, size: 20),
                  tooltip: l10n.discoverRelations,
                  onPressed: () async {
                    await ref.read(
                      autoDiscoverLinksProvider(inspirationId).future,
                    );
                    ref.invalidate(inspirationLinksProvider(inspirationId));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _RelationshipGroup(
              title: l10n.parentInspirations,
              links: parentLinks,
              currentId: inspirationId,
            ),
            _RelationshipGroup(
              title: l10n.childInspirations,
              links: childLinks,
              currentId: inspirationId,
            ),
            _RelationshipGroup(
              title: l10n.relatedInspirations,
              links: relatedLinks,
              currentId: inspirationId,
            ),
          ],
        );
      },
    );
  }
}

class _RelationshipEmptyState extends StatelessWidget {
  const _RelationshipEmptyState({
    required this.onAddParent,
    required this.onAddChild,
    required this.onAddRelated,
    required this.onDiscover,
  });

  final VoidCallback onAddParent;
  final VoidCallback onAddChild;
  final VoidCallback onAddRelated;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.hierarchyRelations,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.noHierarchyRelations,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: onAddParent,
              icon: const Icon(Icons.vertical_align_top_rounded),
              label: Text(l10n.addParentInspiration),
            ),
            FilledButton.tonalIcon(
              onPressed: onAddChild,
              icon: const Icon(Icons.subdirectory_arrow_right_rounded),
              label: Text(l10n.addChildInspiration),
            ),
            OutlinedButton.icon(
              onPressed: onAddRelated,
              icon: const Icon(Icons.add_link),
              label: Text(l10n.addRelation),
            ),
            OutlinedButton.icon(
              onPressed: onDiscover,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(l10n.discoverRelations),
            ),
          ],
        ),
      ],
    );
  }
}

class _RelationshipGroup extends StatelessWidget {
  const _RelationshipGroup({
    required this.title,
    required this.links,
    required this.currentId,
  });

  final String title;
  final List<InspirationLink> links;
  final int currentId;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...links.map(
            (link) => _RelatedLinkTile(link: link, currentId: currentId),
          ),
        ],
      ),
    );
  }
}

class _RelatedLinkTile extends ConsumerWidget {
  const _RelatedLinkTile({required this.link, required this.currentId});

  final InspirationLink link;
  final int currentId;

  String _linkTypeLabel(LinkType type, AppLocalizations l10n) {
    switch (type) {
      case LinkType.similar:
        return l10n.linkTypeSimilar;
      case LinkType.causal:
        return l10n.linkTypeCausal;
      case LinkType.complementary:
        return l10n.linkTypeComplementary;
      case LinkType.opposite:
        return l10n.linkTypeOpposite;
      case LinkType.parentChild:
        return l10n.linkTypeParentChild;
    }
  }

  IconData _linkTypeIcon(LinkType type) {
    switch (type) {
      case LinkType.similar:
        return Icons.compare_arrows;
      case LinkType.causal:
        return Icons.arrow_right_alt;
      case LinkType.complementary:
        return Icons.add_circle_outline;
      case LinkType.opposite:
        return Icons.swap_horiz;
      case LinkType.parentChild:
        return Icons.account_tree_outlined;
    }
  }

  String _relationshipLabel(InspirationLink link, AppLocalizations l10n) {
    if (link.linkType != LinkType.parentChild) {
      return _linkTypeLabel(link.linkType, l10n);
    }
    final semantic =
        link.relationLabel == null
            ? l10n.relationLabelGeneral
            : _relationLabelText(link.relationLabel!, l10n);
    final role = link.targetId == currentId ? l10n.parentRole : l10n.childRole;
    return '$role · $semantic';
  }

  String? _relationshipDirectionDescription(
    InspirationLink link,
    AppLocalizations l10n,
  ) {
    if (link.linkType != LinkType.parentChild) return null;
    return link.targetId == currentId
        ? l10n.parentRelationDesc
        : l10n.childRelationDesc;
  }

  String _relationLabelText(String label, AppLocalizations l10n) {
    switch (label) {
      case 'belongsTo':
        return l10n.relationLabelBelongsTo;
      case 'breakdown':
        return l10n.relationLabelBreakdown;
      case 'supports':
        return l10n.relationLabelSupports;
      case 'extends':
        return l10n.relationLabelExtends;
      default:
        return l10n.relationLabelGeneral;
    }
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(inspirationLinkRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.delete(link.id);
    ref.invalidate(inspirationLinksProvider(currentId));

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.relationRemoved),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              await repo.restore(link);
              ref.invalidate(inspirationLinksProvider(currentId));
            },
          ),
        ),
      );
  }

  Future<void> _updateRelationLabel(
    BuildContext context,
    WidgetRef ref,
    String? value,
  ) async {
    await ref
        .read(inspirationLinkRepositoryProvider)
        .updateRelationLabel(link.id, value);
    ref.invalidate(inspirationLinksProvider(currentId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final otherId = link.sourceId == currentId ? link.targetId : link.sourceId;

    return FutureBuilder(
      future: ref.read(inspirationRepositoryProvider).getById(otherId),
      builder: (context, snapshot) {
        final other = snapshot.data;
        if (other == null) return const SizedBox.shrink();
        final directionDesc = _relationshipDirectionDescription(link, l10n);
        final relationLabel = _relationshipLabel(link, l10n);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              _linkTypeIcon(link.linkType),
              color: theme.colorScheme.primary,
              size: 20,
            ),
            title: Text(
              other.content.length > 60
                  ? '${other.content.substring(0, 60)}...'
                  : other.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              directionDesc == null
                  ? '$relationLabel · ${(link.confidence * 100).round()}%'
                  : '$relationLabel · $directionDesc',
              style: theme.textTheme.bodySmall,
            ),
            trailing: PopupMenuButton<String>(
              tooltip: l10n.unlinkRelation,
              onSelected: (value) {
                if (value == 'unlink') {
                  _unlink(context, ref);
                } else if (value.startsWith('label:')) {
                  final label = value.substring('label:'.length);
                  _updateRelationLabel(
                    context,
                    ref,
                    label.isEmpty ? null : label,
                  );
                }
              },
              itemBuilder:
                  (_) => [
                    if (link.linkType == LinkType.parentChild) ...[
                      PopupMenuItem(
                        value: 'label:',
                        child: Text(l10n.relationLabelGeneral),
                      ),
                      PopupMenuItem(
                        value: 'label:belongsTo',
                        child: Text(l10n.relationLabelBelongsTo),
                      ),
                      PopupMenuItem(
                        value: 'label:breakdown',
                        child: Text(l10n.relationLabelBreakdown),
                      ),
                      PopupMenuItem(
                        value: 'label:supports',
                        child: Text(l10n.relationLabelSupports),
                      ),
                      PopupMenuItem(
                        value: 'label:extends',
                        child: Text(l10n.relationLabelExtends),
                      ),
                      const PopupMenuDivider(),
                    ],
                    PopupMenuItem(
                      value: 'unlink',
                      child: Text(l10n.unlinkRelation),
                    ),
                  ],
            ),
            onTap: () => context.push('/inspiration/$otherId'),
          ),
        );
      },
    );
  }
}

/// Looks up the source icon by name and renders it in a Chip avatar.
class _SourceIconChip extends ConsumerWidget {
  const _SourceIconChip({required this.sourceName});

  final String sourceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourceListProvider);
    return sourcesAsync.when(
      loading: () => const Icon(Icons.circle_outlined, size: 18),
      error: (_, _) => const Icon(Icons.circle_outlined, size: 18),
      data: (sources) {
        final match = sources.where((s) => s.name == sourceName);
        final icon = match.isNotEmpty ? match.first.icon : 'lightbulb';
        return buildSourceIcon(icon, size: 18);
      },
    );
  }
}

/// Bottom sheet for manually creating an inspiration link.
class _ManualLinkSheet extends ConsumerStatefulWidget {
  const _ManualLinkSheet({
    required this.inspirationId,
    required this.onLinked,
    required this.initialType,
    required this.currentIsParent,
  });

  final int inspirationId;
  final VoidCallback onLinked;
  final LinkType initialType;
  final bool currentIsParent;

  @override
  ConsumerState<_ManualLinkSheet> createState() => _ManualLinkSheetState();
}

class _ManualLinkSheetState extends ConsumerState<_ManualLinkSheet> {
  String _query = '';
  int? _selectedTargetId;
  late LinkType _linkType;
  late bool _currentIsParent;
  String? _relationLabel;

  @override
  void initState() {
    super.initState();
    _linkType = widget.initialType;
    _currentIsParent = widget.currentIsParent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(inspirationRepositoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: l10n.searchInspiration,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      LinkType.values.map((type) {
                        final selected = _linkType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_linkTypeLabel(type, l10n)),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _linkType = type),
                          ),
                        );
                      }).toList(),
                ),
              ),
              if (_linkType == LinkType.parentChild) ...[
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment<bool>(
                      value: true,
                      icon: const Icon(Icons.account_tree_outlined),
                      label: Text(l10n.currentAsParent),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      icon: const Icon(Icons.subdirectory_arrow_right_rounded),
                      label: Text(l10n.currentAsChild),
                    ),
                  ],
                  selected: {_currentIsParent},
                  showSelectedIcon: false,
                  onSelectionChanged:
                      (values) =>
                          setState(() => _currentIsParent = values.first),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currentIsParent
                        ? l10n.currentAsParentDesc
                        : l10n.currentAsChildDesc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _relationLabelOptions(l10n).map((option) {
                          final selected = _relationLabel == option.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(option.label),
                              selected: selected,
                              showCheckmark: false,
                              onSelected:
                                  (_) => setState(
                                    () => _relationLabel = option.value,
                                  ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Inspiration>>(
                  future: repo.getAll(),
                  builder: (context, snapshot) {
                    final all = snapshot.data ?? [];
                    final candidates =
                        all
                            .where(
                              (i) =>
                                  i.id != widget.inspirationId &&
                                  (_query.isEmpty ||
                                      i.content.contains(_query)),
                            )
                            .toList();
                    if (candidates.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.noLinkableInspirations,
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }
                    return FutureBuilder<List<InspirationLink>>(
                      future: ref
                          .read(inspirationLinkRepositoryProvider)
                          .getLinksForInspiration(widget.inspirationId),
                      builder: (context, linkSnapshot) {
                        final links = linkSnapshot.data ?? const [];
                        return RadioGroup<int>(
                          groupValue: _selectedTargetId,
                          onChanged:
                              (value) =>
                                  setState(() => _selectedTargetId = value),
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: candidates.length,
                            itemBuilder: (context, index) {
                              final ins = candidates[index];
                              final isSelected = _selectedTargetId == ins.id;
                              final status = _candidateStatus(
                                ins.id,
                                links,
                                l10n,
                              );
                              final preview =
                                  ins.content.length > 60
                                      ? '${ins.content.substring(0, 60)}...'
                                      : ins.content;
                              return ListTile(
                                leading: Radio<int>(value: ins.id),
                                title: Text(
                                  preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                                subtitle:
                                    status == null
                                        ? null
                                        : Text(
                                          status,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color:
                                                    theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                        ),
                                selected: isSelected,
                                selectedTileColor: theme
                                    .colorScheme
                                    .primaryContainer
                                    .withAlpha(60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.link),
                  label: Text(l10n.addRelation),
                  onPressed:
                      _selectedTargetId == null
                          ? null
                          : () async {
                            final linkRepo = ref.read(
                              inspirationLinkRepositoryProvider,
                            );
                            final selectedId = _selectedTargetId!;
                            final isHierarchy =
                                _linkType == LinkType.parentChild;
                            final sourceId =
                                isHierarchy && !_currentIsParent
                                    ? selectedId
                                    : widget.inspirationId;
                            final targetId =
                                isHierarchy && !_currentIsParent
                                    ? widget.inspirationId
                                    : selectedId;
                            final exists = await linkRepo.exists(
                              sourceId,
                              targetId,
                              linkType: _linkType,
                              directed: isHierarchy,
                            );
                            if (exists) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.relationAlreadyExists),
                                  ),
                                );
                              }
                              return;
                            }
                            if (isHierarchy) {
                              final wouldCycle = await linkRepo
                                  .wouldCreateParentChildCycle(
                                    sourceId,
                                    targetId,
                                  );
                              if (wouldCycle) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.parentChildCycleBlocked,
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            await linkRepo.create(
                              InspirationLink(
                                id: 0,
                                sourceId: sourceId,
                                targetId: targetId,
                                linkType: _linkType,
                                relationLabel:
                                    isHierarchy ? _relationLabel : null,
                                confidence: 1.0,
                                createdAt: DateTime.now(),
                              ),
                            );
                            widget.onLinked();
                            if (context.mounted) Navigator.pop(context);
                          },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _candidateStatus(
    int selectedId,
    List<InspirationLink> links,
    AppLocalizations l10n,
  ) {
    final isHierarchy = _linkType == LinkType.parentChild;
    final sourceId =
        isHierarchy && !_currentIsParent ? selectedId : widget.inspirationId;
    final targetId =
        isHierarchy && !_currentIsParent ? widget.inspirationId : selectedId;

    final exists = links.any((link) {
      final typeMatches = link.linkType == _linkType;
      if (!typeMatches) return false;
      return isHierarchy
          ? link.sourceId == sourceId && link.targetId == targetId
          : (link.sourceId == sourceId && link.targetId == targetId) ||
              (link.sourceId == targetId && link.targetId == sourceId);
    });
    if (exists) return l10n.relationAlreadyExists;

    if (!isHierarchy) return null;
    return _currentIsParent
        ? l10n.currentAsParentDesc
        : l10n.currentAsChildDesc;
  }

  List<_RelationLabelOption> _relationLabelOptions(AppLocalizations l10n) {
    return [
      _RelationLabelOption(null, l10n.relationLabelGeneral),
      _RelationLabelOption('belongsTo', l10n.relationLabelBelongsTo),
      _RelationLabelOption('breakdown', l10n.relationLabelBreakdown),
      _RelationLabelOption('supports', l10n.relationLabelSupports),
      _RelationLabelOption('extends', l10n.relationLabelExtends),
    ];
  }

  String _linkTypeLabel(LinkType type, AppLocalizations l10n) {
    switch (type) {
      case LinkType.similar:
        return l10n.linkTypeSimilar;
      case LinkType.causal:
        return l10n.linkTypeCausal;
      case LinkType.complementary:
        return l10n.linkTypeComplementary;
      case LinkType.opposite:
        return l10n.linkTypeOpposite;
      case LinkType.parentChild:
        return l10n.linkTypeParentChild;
    }
  }
}

class _RelationLabelOption {
  const _RelationLabelOption(this.value, this.label);

  final String? value;
  final String label;
}
