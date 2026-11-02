import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flashnote/presentation/providers/review_providers.dart';
import 'package:flashnote/presentation/providers/source_providers.dart';
import 'package:flashnote/presentation/providers/webdav_provider.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WebDavSettingsPage extends ConsumerStatefulWidget {
  const WebDavSettingsPage({super.key});

  @override
  ConsumerState<WebDavSettingsPage> createState() => _WebDavSettingsPageState();
}

class _WebDavSettingsPageState extends ConsumerState<WebDavSettingsPage> {
  final _serverUrlController = TextEditingController();
  final _remotePathController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _autoSync = false;
  bool _syncAttachments = false;
  int _syncIntervalMinutes = 0;
  bool _isLoading = false;
  bool _isTesting = false;
  String? _testResult;
  String? _syncResult;
  int? _lastSyncTime;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = await ref.read(webdavStorageProvider.future);
    final username = await storage.username;
    final password = await storage.password;
    if (mounted) {
      setState(() {
        _serverUrlController.text = storage.serverUrl;
        _remotePathController.text = storage.remotePath;
        _usernameController.text = username ?? '';
        _passwordController.text = password ?? '';
        _autoSync = storage.autoSync;
        _syncAttachments = storage.syncAttachments;
        _syncIntervalMinutes = storage.syncIntervalMinutes;
        _lastSyncTime = storage.lastSyncTime;
        _initialized = true;
      });
    }
  }

  Future<void> _saveSettings() async {
    final storage = await ref.read(webdavStorageProvider.future);
    await storage.setServerUrl(_serverUrlController.text.trim());
    await storage.setRemotePath(_remotePathController.text.trim());
    await storage.setUsername(_usernameController.text.trim());
    await storage.setPassword(_passwordController.text.trim());
    await storage.setAutoSync(_autoSync);
    await storage.setSyncAttachments(_syncAttachments);
    await storage.setSyncIntervalMinutes(_syncIntervalMinutes);
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _testResult = l10n.webdavNotConfigured);
      return;
    }

    await _saveSettings();
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final service = await ref.read(webdavSyncServiceProvider.future);
      final (success, msg) = await service.testConnection();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = success ? l10n.connectionTestSuccess : msg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = '${l10n.connectionTestFailed}: $e';
        });
      }
    }
  }

  Future<void> _performSync(String mode) async {
    final l10n = AppLocalizations.of(context);
    final copy = _WebDavCopy.of(context);

    // Confirm dialog
    String confirmMsg;
    switch (mode) {
      case 'pull':
        confirmMsg = l10n.syncPullConfirm;
      case 'push':
        confirmMsg = l10n.syncPushConfirm;
      default:
        confirmMsg = l10n.syncMergeConfirm;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            content: Text('$confirmMsg\n\n${copy.attachmentSyncNotice}'),
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

    await _saveSettings();
    setState(() {
      _isLoading = true;
      _syncResult = null;
    });

    try {
      final service = await ref.read(webdavSyncServiceProvider.future);
      final result = switch (mode) {
        'pull' => await service.pullFromRemote(),
        'push' => await service.pushToRemote(),
        _ => await service.mergeSync(),
      };

      if (mounted) {
        setState(() {
          _isLoading = false;
          _syncResult = result.message;
          if (result.isSuccess) {
            _lastSyncTime = DateTime.now().millisecondsSinceEpoch;
          }
        });

        // Refresh all data providers after sync
        if (result.isSuccess) {
          ref.invalidate(inspirationListProvider);
          ref.invalidate(homeRecentInspirationsProvider);
          ref.invalidate(projectListProvider);
          ref.invalidate(sourceListProvider);
          ref.invalidate(incompleteTasksProvider);
          ref.invalidate(unreviewedCountProvider);
          ref.invalidate(randomUnreviewedProvider);
          ref.invalidate(followUpInspirationsProvider);
          ref.invalidate(weeklyInspirationsProvider);
          ref.invalidate(monthlyInspirationsProvider);
          // Also refresh AI settings so API keys and preset selection update
          ref.invalidate(selectedPresetProvider);
          ref.invalidate(currentApiKeyProvider);
          ref.invalidate(aiConfigReadyProvider);
          ref.invalidate(aiSettingsStorageProvider);
          ref.invalidate(webdavStorageProvider);
          ref.invalidate(webdavSyncServiceProvider);
          await _loadSettings();

          if (mounted) {
            final syncMessage =
                result.credentialsRequired
                    ? '${l10n.syncSuccess}\n${l10n.credentialsNotIncluded}'
                    : result.aiSettingsChanged
                    ? l10n.syncCompletedRefresh
                    : l10n.syncSuccess;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(syncMessage),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _syncResult = '${l10n.syncFailed}: $e';
        });
      }
    }
  }

  String _formatSyncTime(int? timestamp) {
    if (timestamp == null) return AppLocalizations.of(context).neverSynced;
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _remotePathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final copy = _WebDavCopy.of(context);

    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(l10n.webdavSettings),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.webdavSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          AppPanel(
            padding: const EdgeInsets.all(14),
            radius: 22,
            shadowAlpha: 0.04,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _IconBox(icon: Icons.cloud_sync_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${l10n.webdavSettingsDesc}\n${copy.attachmentSyncNotice}',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),

          _SectionHeader(title: copy.connectionInfo),
          AppPanel(
            padding: const EdgeInsets.all(14),
            radius: 22,
            shadowAlpha: 0.04,
            child: Column(
              children: [
                TextField(
                  controller: _serverUrlController,
                  decoration: InputDecoration(
                    labelText: l10n.serverUrl,
                    hintText: l10n.serverUrlHint,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() => _testResult = null),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _remotePathController,
                  decoration: InputDecoration(
                    labelText: l10n.remotePath,
                    hintText: l10n.remotePathHint,
                  ),
                  onChanged: (_) => setState(() => _testResult = null),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: l10n.username,
                    hintText: l10n.usernameHint,
                  ),
                  onChanged: (_) => setState(() => _testResult = null),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    hintText: l10n.passwordHint,
                  ),
                  obscureText: true,
                  onChanged: (_) => setState(() => _testResult = null),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon:
                          _isTesting
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.wifi_tethering, size: 18),
                      label: Text(l10n.testConnection),
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 10),
                  _ResultNotice(
                    text: _testResult!,
                    success: _testResult == l10n.connectionTestSuccess,
                  ),
                ],
              ],
            ),
          ),

          _SectionHeader(title: copy.syncPreferences),
          AppPanel(
            padding: const EdgeInsets.all(14),
            radius: 22,
            shadowAlpha: 0.04,
            child: Column(
              children: [
                _SettingsToggleTile(
                  icon: Icons.attachment_outlined,
                  title: copy.syncAttachmentsTitle,
                  subtitle: copy.syncAttachmentsDesc,
                  value: _syncAttachments,
                  onChanged: (value) {
                    setState(() => _syncAttachments = value);
                    _saveSettings();
                  },
                ),
                const SizedBox(height: 10),
                _SettingsToggleTile(
                  icon: Icons.sync_outlined,
                  title: l10n.autoSync,
                  subtitle: l10n.autoSyncDesc,
                  value: _autoSync,
                  onChanged: (value) {
                    setState(() => _autoSync = value);
                    _saveSettings();
                  },
                ),
                if (_autoSync) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: _syncIntervalMinutes,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.syncInterval),
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(l10n.syncIntervalOff),
                      ),
                      DropdownMenuItem(
                        value: 5,
                        child: Text(l10n.syncInterval5m),
                      ),
                      DropdownMenuItem(
                        value: 15,
                        child: Text(l10n.syncInterval15m),
                      ),
                      DropdownMenuItem(
                        value: 30,
                        child: Text(l10n.syncInterval30m),
                      ),
                      DropdownMenuItem(
                        value: 60,
                        child: Text(l10n.syncInterval1h),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _syncIntervalMinutes = value);
                        _saveSettings();
                      }
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${l10n.lastSyncTime}: ${_formatSyncTime(_lastSyncTime)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _SectionHeader(title: l10n.cloudSync),
          if (_syncResult != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ResultNotice(
                text: _syncResult!,
                success:
                    _syncResult!.contains('成功') ||
                    _syncResult!.toLowerCase().contains('success'),
              ),
            ),
          AppPanel(
            padding: EdgeInsets.zero,
            radius: 22,
            shadowAlpha: 0.04,
            child: Column(
              children: [
                _SyncActionTile(
                  icon: Icons.cloud_download_outlined,
                  title: l10n.syncPull,
                  subtitle: l10n.syncPullDesc,
                  loading: _isLoading,
                  onTap: _isLoading ? null : () => _performSync('pull'),
                ),
                _SettingsDivider(),
                _SyncActionTile(
                  icon: Icons.cloud_upload_outlined,
                  title: l10n.syncPush,
                  subtitle: l10n.syncPushDesc,
                  loading: _isLoading,
                  onTap: _isLoading ? null : () => _performSync('push'),
                ),
                _SettingsDivider(),
                _SyncActionTile(
                  icon: Icons.cloud_sync_outlined,
                  title: l10n.syncMerge,
                  subtitle: l10n.syncMergeDesc,
                  loading: _isLoading,
                  onTap: _isLoading ? null : () => _performSync('merge'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, size: 20, color: theme.colorScheme.primary),
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

class _SyncActionTile extends StatelessWidget {
  const _SyncActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
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
                child:
                    loading
                        ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(icon, size: 20, color: colorScheme.primary),
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

class _ResultNotice extends StatelessWidget {
  const _ResultNotice({required this.text, required this.success});

  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = success ? Colors.green : theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
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

class _WebDavCopy {
  const _WebDavCopy({required this.isZh});

  _WebDavCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get attachmentSyncNotice =>
      isZh
          ? '可在下方开关控制 WebDAV 是否上传附件文件内容。关闭时只同步附件记录，不上传文件本体。'
          : 'Use the switch below to control whether WebDAV uploads attachment file content. When off, only attachment records are synced.';

  String get syncAttachmentsTitle => isZh ? '同步附件文件' : 'Sync attachment files';
  String get syncAttachmentsDesc =>
      isZh
          ? '开启后会备份所有已添加附件，不限制文件类型，但会增加上传流量和同步文件体积。'
          : 'When enabled, all added attachments are backed up without file type limits, increasing upload traffic and sync file size.';
  String get connectionInfo => isZh ? '连接信息' : 'Connection';
  String get syncPreferences => isZh ? '同步偏好' : 'Sync preferences';
}
