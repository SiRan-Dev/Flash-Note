import 'package:flashnote/core/utils/app_accent_palette.dart';
import 'package:flutter/material.dart';

BoxDecoration appPanelDecoration(
  ThemeData theme, {
  Color? color,
  Color? borderColor,
  double radius = 24,
  double shadowAlpha = 0.08,
}) {
  return BoxDecoration(
    color: color ?? theme.colorScheme.surface.withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color:
          borderColor ??
          theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: shadowAlpha),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = 24,
    this.shadowAlpha = 0.08,
    this.expand = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final double shadowAlpha;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: expand ? double.infinity : null,
      child: DecoratedBox(
        decoration: appPanelDecoration(
          theme,
          color: color,
          borderColor: borderColor,
          radius: radius,
          shadowAlpha: shadowAlpha,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class AppMetricChip extends StatelessWidget {
  const AppMetricChip({
    super.key,
    required this.icon,
    required this.label,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppAccentPalette.tintSurfaceStrong(theme.colorScheme, accent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
