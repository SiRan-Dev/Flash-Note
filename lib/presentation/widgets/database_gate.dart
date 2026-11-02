import 'package:flashnote/data/datasources/local/connection/migration_backup_registry.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Blocks the app until the database has been opened successfully.
///
/// drift 在迁移失败后会把该连接的后续查询全部标记为失败；如果这时继续渲染
/// 正常页面，用户只会看到空白或反复报错。这里统一在入口处等待数据库就绪，
/// 失败时展示可重试的恢复页。
class DatabaseGate extends ConsumerWidget {
  const DatabaseGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(databaseInitializationProvider);

    return state.when(
      data: (_) => child,
      loading: () => const _DatabaseLoadingScreen(),
      error: (error, stackTrace) => DatabaseUpgradeFailurePage(
        error: error,
        onRetry: () {
          // 旧连接（含迁移错误状态）已经不可用，必须整体重建。
          // databaseInitializationProvider 依赖它，会随之重新执行。
          ref.invalidate(databaseProvider);
        },
      ),
    );
  }
}

class _DatabaseLoadingScreen extends StatelessWidget {
  const _DatabaseLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Shown when the database could not be opened or a schema upgrade failed.
///
/// The page states what happened, where the pre-migration backup is (if one
/// was created), and offers a retry that rebuilds the database connection.
class DatabaseUpgradeFailurePage extends StatefulWidget {
  const DatabaseUpgradeFailurePage({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  State<DatabaseUpgradeFailurePage> createState() =>
      _DatabaseUpgradeFailurePageState();
}

class _DatabaseUpgradeFailurePageState
    extends State<DatabaseUpgradeFailurePage> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final copy = _FailureCopy.of(context);
    final backup = MigrationBackupRegistry.lastBackup;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    copy.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(copy.body, textAlign: TextAlign.center),
                  if (backup != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      copy.backupLocationTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(backup.path),
                    const SizedBox(height: 4),
                    Text(
                      copy.backupPathHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: backup.path),
                          );
                          if (!mounted) return;
                          setState(() => _copied = true);
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(_copied ? copy.copied : copy.copyPath),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    Text(
                      kIsWeb ? copy.noBackupWeb : copy.noBackup,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: widget.onRetry,
                    child: Text(copy.retry),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    copy.technicalDetails,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    '${widget.error}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureCopy {
  const _FailureCopy({required this.isZh});

  _FailureCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get title => isZh ? '数据库升级失败' : 'Database upgrade failed';

  String get body => isZh
      ? '升级在完成前被打断，改动已回滚，原有数据未被修改。你可以先复制备份路径留底，然后重试。'
      : 'The upgrade was interrupted before completing. Changes were '
            'rolled back and your existing data was not modified. You can '
            'copy the backup path for safekeeping, then retry.';

  String get backupLocationTitle => isZh ? '升级前备份位置' : 'Backup location';

  String get backupPathHint => isZh
      ? '该目录包含升级前的 flashnote.db 及 -wal / -shm 文件，可用于手动恢复。'
      : 'This folder contains flashnote.db and its -wal / -shm files from '
            'before the upgrade, for manual recovery.';

  String get noBackup => isZh
      ? '未创建升级前备份（未检测到需要升级的本地数据库文件）。'
      : 'No pre-upgrade backup was created.';

  String get noBackupWeb => isZh
      ? '浏览器端数据库存在 IndexedDB 中，没有可复制的文件备份；升级失败时改动已回滚，原数据保持不变。'
      : 'The web database lives in IndexedDB, so there is no file backup '
            'to copy. Failed upgrades were rolled back, leaving your data '
            'unchanged.';

  String get copyPath => isZh ? '复制备份路径' : 'Copy backup path';

  String get copied => isZh ? '已复制' : 'Copied';

  String get retry => isZh ? '重试' : 'Retry';

  String get technicalDetails => isZh ? '错误详情' : 'Technical details';
}
