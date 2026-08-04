import 'package:flutter/material.dart';

class AppAccentPalette {
  const AppAccentPalette._();

  static List<Color> fromScheme(ColorScheme scheme) {
    return [
      scheme.primary,
      _mix(scheme.primary, scheme.secondary, 0.42),
      scheme.secondary,
      _mix(scheme.secondary, scheme.tertiary, 0.45),
      scheme.tertiary,
      _mix(scheme.primary, scheme.tertiary, 0.58),
      scheme.error,
    ];
  }

  static Color accentAt(ColorScheme scheme, int index) {
    final palette = fromScheme(scheme);
    return palette[index % palette.length];
  }

  static Color tintSurface(
    ColorScheme scheme,
    Color accent, {
    double amount = 0.14,
  }) {
    return Color.alphaBlend(
      accent.withValues(alpha: amount),
      scheme.surfaceContainerHigh,
    );
  }

  static Color tintSurfaceStrong(
    ColorScheme scheme,
    Color accent, {
    double amount = 0.2,
  }) {
    return Color.alphaBlend(
      accent.withValues(alpha: amount),
      scheme.surfaceContainerHighest,
    );
  }

  static Color onAccent(Color accent) {
    return ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : const Color(0xFF111111);
  }

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
}
