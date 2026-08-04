import 'dart:async';

import 'package:flashnote/app/router.dart';
import 'package:flashnote/data/services/update_service.dart';
import 'package:flashnote/presentation/providers/update_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class StartupUpdateChecker extends ConsumerStatefulWidget {
  const StartupUpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupUpdateChecker> createState() =>
      _StartupUpdateCheckerState();
}

class _StartupUpdateCheckerState extends ConsumerState<StartupUpdateChecker> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked) return;
    _checked = true;
    try {
      final autoCheck = await ref.read(autoCheckUpdatesProvider.future);
      if (!autoCheck) return;
      final release = await ref.read(updateServiceProvider).checkForUpdate();
      final context = rootNavigatorKey.currentContext;
      if (!mounted || context == null || !context.mounted || release == null) {
        return;
      }
      await showUpdatePrompt(context, ref, release);
    } catch (_) {
      // Startup update checks should never block normal app launch.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showUpdatePrompt(
  BuildContext context,
  WidgetRef ref,
  UpdateRelease release,
) async {
  final copy = _UpdateCopy.of(context);
  final info = await PackageInfo.fromPlatform();
  final releaseNotes = _formatReleaseNotes(release.body);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: Text(copy.updateAvailable),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.versionLine(info.version, release.version)),
              if (release.asset != null) ...[
                const SizedBox(height: 8),
                Text(copy.assetLine(release.asset!.name)),
              ],
              if (releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(child: Text(releaseNotes)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(copy.later),
            ),
            if (release.asset == null && release.htmlUrl.isNotEmpty)
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  launchUrl(
                    Uri.parse(release.htmlUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Text(copy.openRelease),
              )
            else
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _downloadAndInstall(context, ref, release);
                },
                child: Text(copy.updateNow),
              ),
          ],
        ),
  );
}

String _formatReleaseNotes(String raw) {
  final withoutDownloadSection = _removeDownloadSections(raw);
  final lines =
      withoutDownloadSection
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n')
          .map(_formatReleaseNoteLine)
          .where((line) => line.trim().isNotEmpty)
          .toList();

  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _removeDownloadSections(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final kept = <String>[];
  var skipping = false;

  for (final line in lines) {
    final trimmed = line.trim();
    final heading = RegExp(r'^\s{0,3}#{1,6}\s+(.+)$').firstMatch(trimmed);
    if (heading != null) {
      final title = heading.group(1)!.replaceAll(RegExp('[*_`#]'), '').trim();
      final normalizedTitle = title.toLowerCase();
      final isDownloadHeading =
          normalizedTitle == 'downloads' ||
          normalizedTitle == 'download' ||
          normalizedTitle == 'assets' ||
          normalizedTitle == '安装包' ||
          normalizedTitle == '下载' ||
          normalizedTitle == '下载地址';
      skipping = isDownloadHeading;
      if (skipping) continue;
    }

    if (skipping) continue;
    kept.add(line);
  }

  return kept.join('\n');
}

String _formatReleaseNoteLine(String line) {
  var result = line.trimRight();
  if (_isMarkdownTableLine(result)) return '';

  result = result.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s*'), '');
  result = result.replaceFirst(RegExp(r'^\s*>\s*'), '');
  result = result.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '• ');
  result = result.replaceFirstMapped(
    RegExp(r'^\s*(\d+)\.\s+'),
    (match) => '${match.group(1)}. ',
  );
  result = result.replaceAllMapped(
    RegExp(r'\[(.*?)\]\((.*?)\)'),
    (match) => match.group(1) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp('`([^`]*)`'),
    (match) => match.group(1) ?? '',
  );
  result = result.replaceAll(RegExp(r'(\*\*|__|~~)'), '');
  return result.trimRight();
}

bool _isMarkdownTableLine(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) return false;
  return true;
}

Future<void> _downloadAndInstall(
  BuildContext context,
  WidgetRef ref,
  UpdateRelease release,
) async {
  final asset = release.asset;
  if (asset == null) return;
  final copy = _UpdateCopy.of(context);
  final service = ref.read(updateServiceProvider);

  final canInstall = await service.canRequestPackageInstalls();
  if (!context.mounted) return;
  if (!canInstall) {
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(copy.permissionTitle),
            content: Text(copy.permissionBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(copy.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  service.openInstallPermissionSettings();
                },
                child: Text(copy.openSettings),
              ),
            ],
          ),
    );
    return;
  }

  final progress = ValueNotifier<double?>(0);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: Text(copy.downloading),
            content: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (context, value, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: value),
                    const SizedBox(height: 12),
                    Text(
                      value == null
                          ? copy.downloading
                          : '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    ),
                  ],
                );
              },
            ),
          ),
    ),
  );

  try {
    final path = await service.downloadApk(
      asset,
      onProgress: (received, total) {
        progress.value = total <= 0 ? null : received / total;
      },
    );
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    await service.installApk(path);
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(copy.updateFailed),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(copy.ok),
              ),
            ],
          ),
    );
  }
}

class _UpdateCopy {
  const _UpdateCopy({required this.isZh});

  _UpdateCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get updateAvailable => isZh ? '发现新版本' : 'Update available';
  String get later => isZh ? '稍后' : 'Later';
  String get updateNow => isZh ? '立即更新' : 'Update now';
  String get openRelease => isZh ? '打开发布页' : 'Open release';
  String get downloading => isZh ? '正在下载更新' : 'Downloading update';
  String get permissionTitle => isZh ? '需要安装权限' : 'Install permission needed';
  String get permissionBody =>
      isZh
          ? '请允许 FlashNote 安装未知应用，然后回到应用再次更新。'
          : 'Allow FlashNote to install unknown apps, then return and update again.';
  String get openSettings => isZh ? '去设置' : 'Open settings';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get updateFailed => isZh ? '更新失败' : 'Update failed';
  String get ok => isZh ? '确定' : 'OK';

  String versionLine(String current, String latest) =>
      isZh
          ? '当前版本：v$current\n最新版本：v$latest'
          : 'Current: v$current\nLatest: v$latest';

  String assetLine(String assetName) =>
      isZh ? '将下载适合当前设备的安装包：$assetName' : 'Selected package: $assetName';
}
