import 'package:flashnote/core/utils/source_icon_builder.dart';
import 'package:flashnote/core/utils/source_mapper.dart';
import 'package:flashnote/domain/entities/custom_source.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/source_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _presetIcons = [
  'lightbulb',
  'menu_book',
  'chat',
  'search',
  'flag',
  'star',
  'book',
  'code',
  'camera',
  'music_note',
  'palette',
  'science',
  'psychology',
  'auto_awesome',
  'bookmark',
  'work',
  'school',
  'favorite',
  'bolt',
  'eco',
  'rocket_launch',
  'edit_note',
  'gps_fixed',
  'home',
  'public',
  'schedule',
  'sports_esports',
  'directions_run',
  'restaurant',
  'coffee',
];

class SourceManagementPage extends ConsumerStatefulWidget {
  const SourceManagementPage({super.key});

  @override
  ConsumerState<SourceManagementPage> createState() =>
      _SourceManagementPageState();
}

class _SourceManagementPageState extends ConsumerState<SourceManagementPage> {
  /// 弹出 icon 选择器，返回选中的 icon 字符串，取消返回 null
  Future<String?> _pickIcon({String currentIcon = 'lightbulb'}) {
    final copy = _SourceCopy.of(context);
    return showDialog<String>(
      context: context,
      builder: (context) {
        String selected = currentIcon;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(copy.pickIcon),
              content: SizedBox(
                width: 320,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _presetIcons.map((icon) {
                        return _IconChoiceButton(
                          icon: icon,
                          selected: icon == selected,
                          onTap: () => setDialogState(() => selected = icon),
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: Text(AppLocalizations.of(context).save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddDialog() async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    String selectedIcon = 'lightbulb';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(l10n.addSource),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EditableIconPreview(
                      icon: selectedIcon,
                      onTap: () async {
                        final picked = await _pickIcon(
                          currentIcon: selectedIcon,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedIcon = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.sourceName,
                        hintText: l10n.sourceNameHint,
                      ),
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.save),
                  ),
                ],
              );
            },
          ),
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      final repo = ref.read(sourceRepositoryProvider);
      await repo.create(nameController.text.trim(), selectedIcon);
      ref.invalidate(sourceListProvider);
    }
  }

  Future<void> _showEditDialog(CustomSource source) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: source.name);
    String selectedIcon = source.icon;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(l10n.editSource),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EditableIconPreview(
                      icon: selectedIcon,
                      onTap: () async {
                        final picked = await _pickIcon(
                          currentIcon: selectedIcon,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedIcon = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.sourceName,
                        hintText: l10n.sourceNameHint,
                      ),
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.save),
                  ),
                ],
              );
            },
          ),
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      final repo = ref.read(sourceRepositoryProvider);
      await repo.update(
        source.copyWith(name: nameController.text.trim(), icon: selectedIcon),
      );
      ref.invalidate(sourceListProvider);
    }
  }

  Future<void> _showDeleteDialog(CustomSource source) async {
    final l10n = AppLocalizations.of(context);

    if (source.isBuiltIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cannotDeleteBuiltIn)));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.deleteSource),
            content: Text(l10n.deleteSourceConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.deleteSource),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final repo = ref.read(sourceRepositoryProvider);
      await repo.delete(source.id);
      ref.invalidate(sourceListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copy = _SourceCopy.of(context);
    final sourcesAsync = ref.watch(sourceListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.sourceManagement),
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: _SourceStateMessage(
                icon: Icons.error_outline,
                title: l10n.loadFailed,
                subtitle: error.toString(),
              ),
            ),
        data: (sources) {
          // 排序：内置来源按 sortOrder 排前面，自定义来源排后面
          final builtIn =
              sources.where((s) => s.isBuiltIn).toList()
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final custom = sources.where((s) => !s.isBuiltIn).toList();
          final sorted = [...builtIn, ...custom];

          if (sorted.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _SourceStateMessage(
                icon: Icons.source_outlined,
                title: l10n.sourceManagement,
                subtitle: copy.emptyDesc,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
            children: [
              AppPanel(
                padding: EdgeInsets.zero,
                radius: 22,
                shadowAlpha: 0.04,
                child: Column(
                  children: [
                    for (var index = 0; index < sorted.length; index++) ...[
                      _SourceTile(
                        source: sorted[index],
                        title:
                            sorted[index].isBuiltIn
                                ? SourceMapper.displayName(
                                  context,
                                  sorted[index].name,
                                )
                                : sorted[index].name,
                        subtitle:
                            sorted[index].isBuiltIn
                                ? copy.builtInSource
                                : copy.customSource,
                        onEdit:
                            sorted[index].isBuiltIn
                                ? null
                                : () => _showEditDialog(sorted[index]),
                        onDelete:
                            sorted[index].isBuiltIn
                                ? null
                                : () => _showDeleteDialog(sorted[index]),
                      ),
                      if (index != sorted.length - 1) const _SettingsDivider(),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: l10n.addSource,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomSource source;
  final String title;
  final String subtitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: buildSourceIcon(source.icon, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (source.isBuiltIn) ...[
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (source.isBuiltIn)
            Icon(
              Icons.lock_outline,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: AppLocalizations.of(context).editSource,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: colorScheme.error,
              ),
              onPressed: onDelete,
              tooltip: AppLocalizations.of(context).deleteSource,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconChoiceButton extends StatelessWidget {
  const _IconChoiceButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color:
          selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.68,
              ),
      borderRadius: BorderRadius.zero,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.64,
                      ),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Icon(sourceMaterialIcons[icon], size: 22),
        ),
      ),
    );
  }
}

class _EditableIconPreview extends StatelessWidget {
  const _EditableIconPreview({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      borderRadius: BorderRadius.zero,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.64),
            ),
          ),
          alignment: Alignment.center,
          child: buildSourceIcon(icon, size: 32),
        ),
      ),
    );
  }
}

class _SourceStateMessage extends StatelessWidget {
  const _SourceStateMessage({
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
    return AppPanel(
      padding: const EdgeInsets.all(18),
      radius: 22,
      shadowAlpha: 0.04,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
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

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 70,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

class _SourceCopy {
  const _SourceCopy({required this.isZh});

  _SourceCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get pickIcon => isZh ? '选择图标' : 'Choose icon';
  String get builtInSource => isZh ? '内置来源' : 'Built-in source';
  String get customSource => isZh ? '自定义来源' : 'Custom source';
  String get emptyDesc => isZh ? '还没有可用来源。' : 'No sources available yet.';
}
