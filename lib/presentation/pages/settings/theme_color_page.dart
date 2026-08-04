import 'package:flashnote/presentation/providers/theme_provider.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeColorPage extends ConsumerStatefulWidget {
  const ThemeColorPage({super.key});

  @override
  ConsumerState<ThemeColorPage> createState() => _ThemeColorPageState();
}

class _ThemeColorPageState extends ConsumerState<ThemeColorPage> {
  late final TextEditingController _hexController;
  late HSVColor _hsvColor;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    final seedColor = ref.read(themeSeedColorProvider);
    _hsvColor = HSVColor.fromColor(seedColor);
    _hexController = TextEditingController(text: _formatHex(seedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _setColor(Color color, {bool updateHex = true}) {
    final normalized = color.withAlpha(0xFF);
    setState(() {
      _hsvColor = HSVColor.fromColor(normalized);
      _hexError = null;
      if (updateHex) {
        _hexController.text = _formatHex(normalized);
      }
    });
    ref.read(themeSeedColorProvider.notifier).setColor(normalized);
  }

  void _setHsv(HSVColor value) {
    _setColor(value.toColor());
  }

  void _applyHex(String value) {
    final parsed = _parseHex(value);
    if (parsed == null) {
      setState(() => _hexError = _Copy.of(context).invalidHex);
      return;
    }
    _setColor(parsed, updateHex: false);
  }

  static String _formatHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color? _parseHex(String value) {
    var normalized = value.trim().replaceFirst('#', '');
    if (normalized.length == 3) {
      normalized = normalized.split('').map((c) => '$c$c').join();
    }
    if (normalized.length != 6) return null;
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = _Copy.of(context);
    final useDynamicColor = ref.watch(dynamicColorProvider);
    final selectedColor = ref.watch(themeSeedColorProvider);
    final lightPreviewScheme = ColorScheme.fromSeed(seedColor: selectedColor);
    final darkPreviewScheme = ColorScheme.fromSeed(
      seedColor: selectedColor,
      brightness: Brightness.dark,
    );

    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          AppPanel(
            padding: const EdgeInsets.all(14),
            radius: 22,
            shadowAlpha: 0.04,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsToggleTile(
                  icon: Icons.auto_awesome_outlined,
                  title: copy.dynamicColor,
                  subtitle: copy.dynamicColorDesc,
                  value: useDynamicColor,
                  onChanged:
                      (value) =>
                          ref.read(dynamicColorProvider.notifier).toggle(value),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.currentColor,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatHex(selectedColor),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (useDynamicColor) ...[
                  const SizedBox(height: 12),
                  _Notice(text: copy.dynamicNotice),
                ],
              ],
            ),
          ),
          _SectionHeader(title: copy.presets),
          AppPanel(
            padding: const EdgeInsets.all(14),
            radius: 22,
            shadowAlpha: 0.04,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in themeSeedColorPresets)
                  _ColorSwatch(
                    color: color,
                    selected: color.toARGB32() == selectedColor.toARGB32(),
                    onTap: () => _setColor(color),
                  ),
              ],
            ),
          ),
          _SectionHeader(title: copy.customColor),
          AppPanel(
            padding: const EdgeInsets.all(14),
            radius: 22,
            shadowAlpha: 0.04,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ColorField(
                  hsvColor: _hsvColor,
                  onChanged:
                      (saturation, value) => _setHsv(
                        _hsvColor.withSaturation(saturation).withValue(value),
                      ),
                ),
                const SizedBox(height: 14),
                _ColorSlider(
                  label: copy.hue,
                  value: _hsvColor.hue,
                  min: 0,
                  max: 360,
                  displayValue: _hsvColor.hue.round().toString(),
                  onChanged: (value) => _setHsv(_hsvColor.withHue(value)),
                ),
                _ColorSlider(
                  label: copy.saturation,
                  value: _hsvColor.saturation,
                  min: 0,
                  max: 1,
                  displayValue: '${(_hsvColor.saturation * 100).round()}%',
                  onChanged:
                      (value) => _setHsv(_hsvColor.withSaturation(value)),
                ),
                _ColorSlider(
                  label: copy.brightness,
                  value: _hsvColor.value,
                  min: 0,
                  max: 1,
                  displayValue: '${(_hsvColor.value * 100).round()}%',
                  onChanged: (value) => _setHsv(_hsvColor.withValue(value)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hexController,
                  decoration: InputDecoration(
                    labelText: copy.hex,
                    hintText: '#2979FF',
                    errorText: _hexError,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_rounded),
                      tooltip: copy.apply,
                      onPressed: () => _applyHex(_hexController.text),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[#a-fA-F0-9]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: _applyHex,
                ),
              ],
            ),
          ),
          _SectionHeader(title: copy.preview),
          _PreviewPanel(
            title: copy.lightPreview,
            scheme: lightPreviewScheme,
            copy: copy,
          ),
          const SizedBox(height: 12),
          _PreviewPanel(
            title: copy.darkPreview,
            scheme: darkPreviewScheme,
            copy: copy,
          ),
        ],
      ),
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField({required this.hsvColor, required this.onChanged});

  final HSVColor hsvColor;
  final void Function(double saturation, double value) onChanged;

  void _updateFromPosition(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final saturation = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - localPosition.dy / size.height).clamp(0.0, 1.0);
    onChanged(saturation, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseHueColor = HSVColor.fromAHSV(1, hsvColor.hue, 1, 1).toColor();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width * 0.58).clamp(168.0, 260.0);
        return GestureDetector(
          onPanDown:
              (details) => _updateFromPosition(
                details.localPosition,
                Size(width, height),
              ),
          onPanUpdate:
              (details) => _updateFromPosition(
                details.localPosition,
                Size(width, height),
              ),
          child: Semantics(
            label: _Copy.of(context).colorField,
            child: SizedBox(
              width: width,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: CustomPaint(
                    painter: _ColorFieldPainter(
                      hueColor: baseHueColor,
                      handleAlignment: Alignment(
                        hsvColor.saturation * 2 - 1,
                        1 - hsvColor.value * 2,
                      ),
                      handleColor: hsvColor.toColor(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColorFieldPainter extends CustomPainter {
  const _ColorFieldPainter({
    required this.hueColor,
    required this.handleAlignment,
    required this.handleColor,
  });

  final Color hueColor;
  final Alignment handleAlignment;
  final Color handleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final huePaint =
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white, hueColor],
          ).createShader(rect);
    canvas.drawRect(rect, huePaint);

    final valuePaint =
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
          ).createShader(rect);
    canvas.drawRect(rect, valuePaint);

    final handle = handleAlignment.alongSize(size);
    final outerPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    final shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;
    final fillPaint = Paint()..color = handleColor;
    canvas.drawCircle(handle, 11, shadowPaint);
    canvas.drawCircle(handle, 8, fillPaint);
    canvas.drawCircle(handle, 11, outerPaint);
  }

  @override
  bool shouldRepaint(covariant _ColorFieldPainter oldDelegate) {
    return oldDelegate.hueColor != hueColor ||
        oldDelegate.handleAlignment != handleAlignment ||
        oldDelegate.handleColor != handleColor;
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.title,
    required this.scheme,
    required this.copy,
  });

  final String title;
  final ColorScheme scheme;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(14),
      radius: 22,
      shadowAlpha: 0.04,
      color: scheme.surface,
      borderColor: scheme.outlineVariant.withValues(alpha: 0.72),
      child: Theme(
        data: Theme.of(context).copyWith(colorScheme: scheme),
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _PreviewChip(
                      color: scheme.primaryContainer,
                      foreground: scheme.onPrimaryContainer,
                      label: copy.primary,
                    ),
                    const SizedBox(width: 8),
                    _PreviewChip(
                      color: scheme.secondaryContainer,
                      foreground: scheme.onSecondaryContainer,
                      label: copy.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.palette_outlined),
                  label: Text(copy.previewAction),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                width: selected ? 2 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  selected
                      ? Icon(
                        Icons.check_rounded,
                        color:
                            ThemeData.estimateBrightnessForColor(color) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black,
                      )
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              displayValue,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.64),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.color,
    required this.foreground,
    required this.label,
  });

  final Color color;
  final Color foreground;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _Copy {
  const _Copy({required this.isZh});

  _Copy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get title => isZh ? '主题调色盘' : 'Theme Palette';
  String get dynamicColor => isZh ? '动态取色' : 'Dynamic color';
  String get dynamicColorDesc =>
      isZh
          ? '开启后优先使用系统 Material You 取色；关闭后使用此页面选择的颜色。'
          : 'When enabled, use the system Material You palette; when off, use the color selected here.';
  String get dynamicNotice =>
      isZh
          ? '当前开启动态取色。你仍然可以调整预设色，它会在关闭动态取色或设备不支持动态取色时生效。'
          : 'Dynamic color is on. You can still adjust the preset; it applies when dynamic color is off or unavailable.';
  String get currentColor => isZh ? '当前预设色' : 'Current preset';
  String get presets => isZh ? '基础预设' : 'Base presets';
  String get customColor => isZh ? '自定义颜色' : 'Custom color';
  String get colorField => isZh ? '拖动选择颜色' : 'Drag to choose color';
  String get hue => isZh ? '色相' : 'Hue';
  String get saturation => isZh ? '饱和度' : 'Saturation';
  String get brightness => isZh ? '明度' : 'Brightness';
  String get hex => isZh ? 'HEX 数值' : 'HEX value';
  String get apply => isZh ? '应用' : 'Apply';
  String get invalidHex => isZh ? '请输入有效的 HEX 颜色' : 'Enter a valid HEX color';
  String get preview => isZh ? '效果预览' : 'Preview';
  String get lightPreview => isZh ? '浅色模式' : 'Light mode';
  String get darkPreview => isZh ? '深色模式' : 'Dark mode';
  String get primary => isZh ? '主色' : 'Primary';
  String get secondary => isZh ? '辅色' : 'Secondary';
  String get previewAction => isZh ? '预览按钮' : 'Preview button';
}
