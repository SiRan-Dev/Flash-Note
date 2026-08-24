import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/theme_provider.dart';
import 'package:flashnote/presentation/providers/update_provider.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flashnote/presentation/widgets/startup_update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutAppPage extends ConsumerStatefulWidget {
  const AboutAppPage({super.key});

  @override
  ConsumerState<AboutAppPage> createState() => _AboutAppPageState();
}

class _AboutAppPageState extends ConsumerState<AboutAppPage> {
  String _version = '';
  String _buildNumber = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _checkUpdates() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _checking = true);
    try {
      final release = await ref.read(updateServiceProvider).checkForUpdate();
      if (!mounted) return;
      setState(() => _checking = false);
      if (release == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.aboutAlreadyLatest)));
        return;
      }
      await showUpdatePrompt(context, ref, release);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.aboutCheckFailed}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageMode = ref.watch(languageModeProvider);
    final autoCheckUpdates =
        ref.watch(autoCheckUpdatesProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          AppPanel(
            radius: 22,
            shadowAlpha: 0.04,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.flash_on_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.aboutDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppPanel(
            padding: EdgeInsets.zero,
            radius: 22,
            shadowAlpha: 0.04,
            child: Column(
              children: [
                _AboutActionTile(
                  icon: Icons.info_outline,
                  title: l10n.aboutCurrentVersion,
                  subtitle: 'v$_version ($_buildNumber)',
                ),
                const _AboutDivider(),
                _AboutLanguageTile(
                  mode: languageMode,
                  onChanged:
                      (mode) => ref
                          .read(languageModeProvider.notifier)
                          .setLanguageMode(mode),
                ),
                const _AboutDivider(),
                _AboutActionTile(
                  icon: Icons.system_update_alt_rounded,
                  title: l10n.aboutCheckUpdates,
                  subtitle: l10n.aboutCheckUpdatesDesc,
                  trailing:
                      _checking
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.chevron_right_rounded),
                  onTap: _checking ? null : _checkUpdates,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AboutSwitchRow(
            icon: Icons.update_rounded,
            title: l10n.aboutAutoCheckUpdates,
            subtitle: l10n.aboutAutoCheckUpdatesDesc,
            value: autoCheckUpdates,
            onChanged: (value) async {
              final storage = await ref.read(
                updateSettingsStorageProvider.future,
              );
              await storage.setAutoCheckUpdates(value);
              ref.invalidate(autoCheckUpdatesProvider);
            },
          ),
          const SizedBox(height: 14),
          AppPanel(
            padding: EdgeInsets.zero,
            radius: 22,
            shadowAlpha: 0.04,
            child: Column(
              children: [
                _AboutActionTile(
                  icon: Icons.code_rounded,
                  title: l10n.aboutOpenSource,
                  subtitle: 'github.com/SiRan-Dev/FlashNote',
                  onTap:
                      () => launchUrl(
                        Uri.parse('https://github.com/SiRan-Dev/FlashNote'),
                        mode: LaunchMode.externalApplication,
                      ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                ),
                const _AboutDivider(),
                _AboutActionTile(
                  icon: Icons.new_releases_outlined,
                  title: l10n.aboutReleases,
                  subtitle: l10n.aboutReleasesDesc,
                  onTap:
                      () => launchUrl(
                        Uri.parse(
                          'https://github.com/SiRan-Dev/FlashNote/releases',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutLanguageTile extends StatelessWidget {
  const _AboutLanguageTile({required this.mode, required this.onChanged});

  final AppLanguageMode mode;
  final ValueChanged<AppLanguageMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickLanguage(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              const _AboutIcon(icon: Icons.language_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.language,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _languageModeLabel(l10n, mode),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  void _pickLanguage(BuildContext context) {
    final selection =
        MediaQuery.sizeOf(context).width >= 600
            ? showDialog<AppLanguageMode>(
              context: context,
              builder:
                  (context) => _LanguageModeDialog(
                    mode: mode,
                    onSelected: Navigator.of(context).pop,
                  ),
            )
            : showModalBottomSheet<AppLanguageMode>(
              context: context,
              showDragHandle: true,
              builder:
                  (context) => _LanguageModeSheet(
                    mode: mode,
                    onSelected: Navigator.of(context).pop,
                  ),
            );
    selection.then((selected) {
      if (selected != null && selected != mode) {
        onChanged(selected);
      }
    });
  }
}

class _LanguageModeDialog extends StatelessWidget {
  const _LanguageModeDialog({required this.mode, required this.onSelected});

  final AppLanguageMode mode;
  final ValueChanged<AppLanguageMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: _LanguageModePickerContent(
          mode: mode,
          onSelected: onSelected,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        ),
      ),
    );
  }
}

class _LanguageModeSheet extends StatelessWidget {
  const _LanguageModeSheet({required this.mode, required this.onSelected});

  final AppLanguageMode mode;
  final ValueChanged<AppLanguageMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: _LanguageModePickerContent(
        mode: mode,
        onSelected: onSelected,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}

class _LanguageModePickerContent extends StatelessWidget {
  const _LanguageModePickerContent({
    required this.mode,
    required this.onSelected,
    required this.padding,
  });

  final AppLanguageMode mode;
  final ValueChanged<AppLanguageMode> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Text(
              l10n.language,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          AppPanel(
            padding: EdgeInsets.zero,
            radius: 18,
            shadowAlpha: 0.04,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LanguageOptionTile(
                    icon: Icons.phone_android_rounded,
                    title: l10n.system,
                    selected: mode == AppLanguageMode.system,
                    onTap: () => onSelected(AppLanguageMode.system),
                  ),
                  const _AboutDivider(),
                  _LanguageOptionTile(
                    icon: Icons.translate_rounded,
                    title: l10n.chinese,
                    selected: mode == AppLanguageMode.zh,
                    onTap: () => onSelected(AppLanguageMode.zh),
                  ),
                  const _AboutDivider(),
                  _LanguageOptionTile(
                    icon: Icons.language_rounded,
                    title: l10n.english,
                    selected: mode == AppLanguageMode.en,
                    onTap: () => onSelected(AppLanguageMode.en),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color:
          selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              _AboutIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.check_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutSwitchRow extends StatelessWidget {
  const _AboutSwitchRow({
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.64),
            ),
          ),
          child: Row(
            children: [
              _AboutIcon(icon: icon),
              const SizedBox(width: 12),
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
        ),
      ),
    );
  }
}

class _AboutActionTile extends StatelessWidget {
  const _AboutActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              _AboutIcon(icon: icon),
              const SizedBox(width: 12),
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutIcon extends StatelessWidget {
  const _AboutIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, size: 20, color: colorScheme.primary),
    );
  }
}

class _AboutDivider extends StatelessWidget {
  const _AboutDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 68,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

String _languageModeLabel(AppLocalizations l10n, AppLanguageMode mode) {
  return switch (mode) {
    AppLanguageMode.system => l10n.system,
    AppLanguageMode.zh => l10n.chinese,
    AppLanguageMode.en => l10n.english,
  };
}
