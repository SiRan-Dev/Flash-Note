import 'package:flashnote/core/utils/source_icon_builder.dart';
import 'package:flashnote/core/utils/source_mapper.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/source_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SourceSelector extends ConsumerWidget {
  const SourceSelector({
    super.key,
    this.selectedSource,
    required this.onSelected,
  });

  final String? selectedSource;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourceListProvider);

    return sourcesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('${AppLocalizations.of(context).loadFailed}: $e'),
      data: (sources) {
        final chips = [
          _SourceFilterButton(
            label: AppLocalizations.of(context).all,
            icon: Icons.all_inclusive_rounded,
            selected: selectedSource == null,
            onTap: () => onSelected(null),
          ),
          ...sources.map(
            (source) => _SourceFilterButton(
              label:
                  source.isBuiltIn
                      ? SourceMapper.displayName(context, source.name)
                      : source.name,
              iconWidget: buildSourceIcon(source.icon, size: 18),
              selected: selectedSource == source.name,
              onTap:
                  () => onSelected(
                    selectedSource == source.name ? null : source.name,
                  ),
            ),
          ),
        ];

        return SizedBox(
          width: double.infinity,
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => Center(child: chips[index]),
          ),
        );
      },
    );
  }
}

class _SourceFilterButton extends StatelessWidget {
  const _SourceFilterButton({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background =
        selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.72)
            : Colors.transparent;
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary.withValues(alpha: 0.8)
                      : colorScheme.outlineVariant.withValues(alpha: 0.72),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconWidget != null) ...[
                IconTheme(
                  data: IconThemeData(color: foreground, size: 18),
                  child: iconWidget!,
                ),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
