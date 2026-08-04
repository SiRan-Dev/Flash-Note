import 'package:flashnote/core/utils/source_mapper.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InspirationCard extends StatelessWidget {
  const InspirationCard({
    super.key,
    required this.inspiration,
    required this.onTap,
  });

  final Inspiration inspiration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MM/dd HH:mm').format(inspiration.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                Row(
                  children: [
                    if (inspiration.isPinned) ...[
                      Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (inspiration.source != null) ...[
                      Chip(
                        label: Text(
                          SourceMapper.displayName(
                            context,
                            inspiration.source!,
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    Text(dateStr, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  inspiration.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                if (inspiration.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        inspiration.tags
                            .map(
                              (tag) => Chip(
                                label: Text(
                                  tag,
                                  style: theme.textTheme.labelSmall,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
