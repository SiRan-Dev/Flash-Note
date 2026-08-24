import 'package:flashnote/domain/entities/ai_preset.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/data_export_provider.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flashnote/presentation/providers/predictive_back_provider.dart';
import 'package:flashnote/presentation/providers/review_providers.dart';
import 'package:flashnote/presentation/providers/source_providers.dart';
import 'package:flashnote/presentation/providers/theme_provider.dart';
import 'package:flashnote/presentation/providers/webdav_provider.dart';
import 'package:flashnote/presentation/widgets/app_layout.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _selectedInterfaceId = AiPreset.openAiCompatibleId;
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _isLoading = false;
  String? _testResult;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = await ref.read(aiSettingsStorageProvider.future);
    final presetId = storage.selectedPresetId;
    final apiKey = await storage.currentApiKey;
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _selectedInterfaceId = presetId;
        _apiKeyController.text = apiKey ?? '';
        _baseUrlController.text = storage.baseUrlForInterface(presetId);
        _modelController.text = storage.modelForInterface(presetId);
        _appVersion = info.version;
      });
    }
  }

  Future<void> _saveSettings() async {
    final storage = await ref.read(aiSettingsStorageProvider.future);
    await storage.setSelectedPreset(_selectedInterfaceId);
    await storage.setInterfaceConfig(
      interfaceId: _selectedInterfaceId,
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );
    await storage.saveApiKey(
      _selectedInterfaceId,
      _apiKeyController.text.trim(),
    );

    ref.invalidate(selectedPresetProvider);
    ref.invalidate(currentApiKeyProvider);
    ref.invalidate(aiConfigReadyProvider);
  }

  Future<void> _testConnection() async {
    final url = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    if (url.isEmpty || model.isEmpty || apiKey.isEmpty) {
      setState(() => _testResult = AppLocalizations.of(context).apiKeyRequired);
      return;
    }

    final isAnthropic = _selectedInterfaceId == AiPreset.anthropicCompatibleId;
    final preset = AiPreset(
      id: _selectedInterfaceId,
      name: isAnthropic ? 'Anthropic Compatible' : 'OpenAI Compatible',
      model: model,
      baseUrl: url,
      isClaude: isAnthropic,
    );

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    final service = ref.read(aiServiceProvider);
    final (success, errorMsg) = await service.testConnection(preset, apiKey);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _testResult =
            success
                ? AppLocalizations.of(context).connectionSuccess
                : '${AppLocalizations.of(context).connectionFailed}\n$errorMsg';
      });
    }
  }

  Future<void> _exportData() async {
    final l10n = AppLocalizations.of(context);
    try {
      final service = await ref.read(dataExportServiceProvider.future);
      final result = await service.exportData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result != null ? l10n.exportSuccess : l10n.exportFailed,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.exportFailed}: $e')));
      }
    }
  }

  Future<void> _importData() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.importData),
            content: Text(l10n.importConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      final service = await ref.read(dataExportServiceProvider.future);
      final result = await service.importData();
      if (result.success) {
        // Invalidate all data providers so UI reflects imported data
        ref.invalidate(inspirationListProvider);
        ref.invalidate(homeRecentInspirationsProvider);
        ref.invalidate(projectListProvider);
        ref.invalidate(incompleteTasksProvider);
        ref.invalidate(sourceListProvider);
        ref.invalidate(unreviewedCountProvider);
        ref.invalidate(randomUnreviewedProvider);
        ref.invalidate(followUpInspirationsProvider);
        ref.invalidate(weeklyInspirationsProvider);
        ref.invalidate(monthlyInspirationsProvider);
        ref.invalidate(selectedPresetProvider);
        ref.invalidate(currentApiKeyProvider);
        ref.invalidate(aiConfigReadyProvider);
        ref.invalidate(aiSettingsStorageProvider);
        ref.invalidate(webdavStorageProvider);
        ref.invalidate(webdavSyncServiceProvider);
        await _loadSettings();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? result.aiSettingsChanged
                      ? l10n.importSuccessAiUpdated
                      : l10n.importSuccess
                  : l10n.importFailed,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.importFailed}: $e')));
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final copy = _SettingsCopy.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final amoledBlack = ref.watch(amoledBlackProvider);
    final predictiveBack = ref.watch(predictiveBackProvider);
    final useDynamicColor = ref.watch(dynamicColorProvider);
    final themeSeedColor = ref.watch(themeSeedColorProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: AppLayout.pageInsets(constraints, top: 10, bottom: 28),
            children: [
              // --- Theme Section ---
              _SectionHeader(title: l10n.theme),
              AppPanel(
                padding: const EdgeInsets.all(14),
                radius: 16,
                shadowAlpha: 0.04,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.themeMode, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ThemeModeChip(
                            label: l10n.light,
                            icon: Icons.light_mode_outlined,
                            selected: themeMode == ThemeMode.light,
                            onTap:
                                () => ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ThemeModeChip(
                            label: l10n.dark,
                            icon: Icons.dark_mode_outlined,
                            selected: themeMode == ThemeMode.dark,
                            onTap:
                                () => ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(ThemeMode.dark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ThemeModeChip(
                            label: l10n.system,
                            icon: Icons.brightness_auto_outlined,
                            selected: themeMode == ThemeMode.system,
                            onTap:
                                () => ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(ThemeMode.system),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SettingsActionTile(
                      icon: Icons.color_lens_outlined,
                      title: copy.themePalette,
                      subtitle:
                          useDynamicColor
                              ? copy.themePaletteDynamicDesc
                              : '${copy.themePaletteManualDesc} ${_formatHex(themeSeedColor)}',
                      onTap: () => context.push('/settings/theme-color'),
                      showChevron: true,
                    ),
                    const SizedBox(height: 10),
                    _SettingsSwitchRow(
                      icon: Icons.palette_outlined,
                      title: copy.dynamicColor,
                      subtitle: copy.dynamicColorDesc,
                      value: useDynamicColor,
                      onChanged:
                          (value) => ref
                              .read(dynamicColorProvider.notifier)
                              .toggle(value),
                    ),
                    const SizedBox(height: 10),
                    _SettingsSwitchRow(
                      icon: Icons.contrast_outlined,
                      title: l10n.amoledBlack,
                      subtitle: l10n.amoledBlackDesc,
                      value: amoledBlack,
                      onChanged:
                          (value) => ref
                              .read(amoledBlackProvider.notifier)
                              .toggle(value),
                    ),
                    const SizedBox(height: 10),
                    _SettingsSwitchRow(
                      icon: Icons.swipe_outlined,
                      title: l10n.predictiveBack,
                      subtitle: l10n.predictiveBackDesc,
                      value: predictiveBack,
                      onChanged: (value) {
                        ref
                            .read(predictiveBackProvider.notifier)
                            .toggle(value);
                        const MethodChannel(
                          'com.sirandev.flashnote/predictiveback',
                        ).invokeMethod('setEnabled', {'enabled': value});
                      },
                    ),
                  ],
                ),
              ),

              // --- AI Config Section ---
              _SectionHeader(title: l10n.aiSettings),
              AppPanel(
                padding: const EdgeInsets.all(14),
                radius: 16,
                shadowAlpha: 0.04,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.aiSettingsDesc, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 360;
                        final tileWidth =
                            isNarrow
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              child: _AiInterfaceTile(
                                selected:
                                    _selectedInterfaceId ==
                                    AiPreset.openAiCompatibleId,
                                icon: Icons.hub_outlined,
                                title: copy.openAiCompatible,
                                subtitle: copy.openAiCompatibleDesc,
                                onTap:
                                    () => _selectAiInterface(
                                      AiPreset.openAiCompatibleId,
                                    ),
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: _AiInterfaceTile(
                                selected:
                                    _selectedInterfaceId ==
                                    AiPreset.anthropicCompatibleId,
                                icon: Icons.account_tree_outlined,
                                title: copy.anthropicCompatible,
                                subtitle: copy.anthropicCompatibleDesc,
                                onTap:
                                    () => _selectAiInterface(
                                      AiPreset.anthropicCompatibleId,
                                    ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _baseUrlController,
                      decoration: InputDecoration(
                        labelText: l10n.baseUrl,
                        hintText:
                            _selectedInterfaceId ==
                                    AiPreset.anthropicCompatibleId
                                ? 'https://api.anthropic.com/v1'
                                : l10n.baseUrlHint,
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() => _testResult = null),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _modelController,
                      decoration: InputDecoration(
                        labelText: l10n.modelName,
                        hintText:
                            _selectedInterfaceId ==
                                    AiPreset.anthropicCompatibleId
                                ? 'claude-haiku-4-5-20251001'
                                : l10n.modelNameHint,
                      ),
                      onChanged: (_) => setState(() => _testResult = null),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _apiKeyController,
                            decoration: InputDecoration(
                              labelText: l10n.apiKey,
                              hintText: l10n.apiKeyHint,
                            ),
                            obscureText: true,
                            onChanged:
                                (_) => setState(() => _testResult = null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isLoading ? null : _testConnection,
                          icon:
                              _isLoading
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.wifi_tethering, size: 18),
                          tooltip: l10n.testConnection,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.save, size: 20),
                          onPressed: _saveSettings,
                          tooltip: l10n.save,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_testResult != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      color:
                          _testResult == l10n.connectionSuccess
                              ? Colors.green
                              : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),

              // --- Data Management Section ---
              _SectionHeader(title: l10n.dataManagement),
              AppPanel(
                padding: EdgeInsets.zero,
                radius: 16,
                shadowAlpha: 0.04,
                child: Column(
                  children: [
                    _SettingsActionTile(
                      icon: Icons.upload_file_outlined,
                      title: l10n.exportData,
                      subtitle: copy.attachmentExportNotice,
                      onTap: _exportData,
                    ),
                    _SettingsDivider(),
                    _SettingsActionTile(
                      icon: Icons.download_outlined,
                      title: l10n.importData,
                      subtitle: copy.importDataDesc,
                      onTap: _importData,
                    ),
                  ],
                ),
              ),

              // --- Cloud Sync Section ---
              _SectionHeader(title: l10n.cloudSync),
              AppPanel(
                padding: EdgeInsets.zero,
                radius: 16,
                shadowAlpha: 0.04,
                child: _SettingsActionTile(
                  icon: Icons.cloud_sync_outlined,
                  title: l10n.webdavSettings,
                  subtitle: l10n.webdavSettingsDesc,
                  onTap: () => context.push('/settings/webdav'),
                  showChevron: true,
                ),
              ),

              // --- Source Management Section ---
              _SectionHeader(title: l10n.sourceManagement),
              AppPanel(
                padding: EdgeInsets.zero,
                radius: 16,
                shadowAlpha: 0.04,
                child: _SettingsActionTile(
                  icon: Icons.source_outlined,
                  title: l10n.sourceManagement,
                  subtitle: copy.sourceManagementDesc,
                  onTap: () => context.push('/settings/sources'),
                  showChevron: true,
                ),
              ),

              // --- About Section ---
              _SectionHeader(title: l10n.about),
              AppPanel(
                padding: EdgeInsets.zero,
                radius: 16,
                shadowAlpha: 0.04,
                child: Column(
                  children: [
                    _SettingsActionTile(
                      icon: Icons.badge_outlined,
                      title: l10n.userBackground,
                      subtitle: l10n.userBackgroundDesc,
                      onTap: () => context.push('/settings/background'),
                      showChevron: true,
                    ),
                    _SettingsDivider(),
                    _SettingsActionTile(
                      icon: Icons.info_outline,
                      title: l10n.appName,
                      subtitle: '${l10n.version}: v$_appVersion',
                      onTap: () => context.push('/settings/about'),
                      showChevron: true,
                    ),
                    _SettingsDivider(),
                    _SettingsActionTile(
                      icon: Icons.person_outline,
                      title: l10n.developer,
                      subtitle: 'github.com/SiRan-Dev',
                      onTap:
                          () => launchUrl(
                            Uri.parse('https://github.com/SiRan-Dev'),
                          ),
                      showChevron: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectAiInterface(String interfaceId) async {
    if (_selectedInterfaceId == interfaceId) return;
    final storage = await ref.read(aiSettingsStorageProvider.future);
    final apiKey = await storage.getApiKey(interfaceId);
    setState(() {
      _selectedInterfaceId = interfaceId;
      _apiKeyController.text = apiKey ?? '';
      _baseUrlController.text = storage.baseUrlForInterface(interfaceId);
      _modelController.text = storage.modelForInterface(interfaceId);
      _testResult = null;
    });
    await _saveSettings();
  }
}

class _ThemeModeChip extends StatelessWidget {
  const _ThemeModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.72),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color:
                      selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiInterfaceTile extends StatelessWidget {
  const _AiInterfaceTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color:
          selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.72),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color:
                        selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, size: 20, color: colorScheme.primary),
              ),
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

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showChevron = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, size: 20, color: colorScheme.primary),
              ),
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
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron || onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
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

String _formatHex(Color color) {
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class _SettingsCopy {
  const _SettingsCopy({required this.isZh});

  _SettingsCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get attachmentExportNotice =>
      isZh
          ? '本地导出会包含已添加的附件文件，文件较多时导出体积会明显增大。'
          : 'Local exports include added attachment files, so export size may grow noticeably.';
  String get importDataDesc =>
      isZh
          ? '从备份文件恢复灵感、项目、设置与附件记录。'
          : 'Restore ideas, projects, settings, and attachment records.';
  String get sourceManagementDesc =>
      isZh
          ? '管理捕获灵感时使用的来源类型与图标。'
          : 'Manage source types and icons used when capturing ideas.';
  String get themePalette => isZh ? '主题调色盘' : 'Theme palette';
  String get themePaletteDynamicDesc =>
      isZh
          ? '当前使用系统动态取色，可进入调色盘调整备用色。'
          : 'Using system dynamic color; open the palette to edit the fallback.';
  String get themePaletteManualDesc =>
      isZh ? '当前使用自定义主题色' : 'Using custom theme color';
  String get dynamicColor => isZh ? '动态取色' : 'Dynamic color';
  String get dynamicColorDesc =>
      isZh
          ? '开启后优先使用系统 Material You 取色；关闭后使用下方预设色。'
          : 'When enabled, use the system Material You palette; when off, use a preset below.';
  String get openAiCompatible => isZh ? 'OpenAI 兼容' : 'OpenAI Compatible';
  String get anthropicCompatible =>
      isZh ? 'Anthropic 兼容' : 'Anthropic Compatible';
  String get openAiCompatibleDesc =>
      isZh ? '适用于 OpenAI 格式接口' : 'For OpenAI-style APIs';
  String get anthropicCompatibleDesc =>
      isZh ? '适用于 Anthropic 格式接口' : 'For Anthropic-style APIs';
}
