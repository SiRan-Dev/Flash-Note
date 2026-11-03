import 'package:flashnote/data/services/attachment_file_store.dart';
import 'package:flashnote/data/services/share_intake_controller.dart';
import 'package:flashnote/data/services/share_intake_service.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/attachment_providers.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 接收 Android 原生侧投递的分享内容，并复用仓库写入灵感。
///
/// 该组件只会被放在 DatabaseGate 就绪之后，因此收到分享时数据库已可用。
class ShareIntakeListener extends ConsumerStatefulWidget {
  const ShareIntakeListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareIntakeListener> createState() =>
      _ShareIntakeListenerState();
}

class _ShareIntakeListenerState extends ConsumerState<ShareIntakeListener> {
  static const MethodChannel _channel = MethodChannel(
    'com.sirandev.flashnote/share',
  );

  ShareIntakeController? _controller;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    _channel.setMethodCallHandler(_onMethodCall);
    _channel.invokeMethod<void>('ready').catchError((Object error) {
      debugPrint('Share intake channel unavailable: $error');
    });
  }

  @override
  void dispose() {
    if (_supported) _channel.setMethodCallHandler(null);
    super.dispose();
  }

  ShareIntakeController get _intakeController {
    return _controller ??= ShareIntakeController(
      ShareIntakeService(
        inspirationRepository: ref.read(inspirationRepositoryProvider),
        attachmentRepository: ref.read(attachmentRepositoryProvider),
        fileImporter: AttachmentFileStore(),
      ),
    );
  }

  Future<Object?> _onMethodCall(MethodCall call) async {
    if (call.method == 'onShareReceived') {
      await _handleShare(call.arguments);
    }
    return null;
  }

  Future<void> _handleShare(Object? arguments) async {
    final share = IncomingShare.fromMap(arguments);
    final l10n = AppLocalizations.of(context);
    final result = await _intakeController.handle(
      share,
      fallbackContent: l10n.sharedImageContent,
    );
    if (!mounted) return;

    if (result.status == ShareIntakeStatus.saved) {
      ref.read(inspirationListProvider.notifier).refresh();
      ref.invalidate(homeRecentInspirationsProvider);
    }

    final message = switch (result.status) {
      ShareIntakeStatus.saved when result.failedAttachmentCount > 0 =>
        l10n.sharePartialFailure(result.failedAttachmentCount),
      ShareIntakeStatus.saved => l10n.shareSaved,
      ShareIntakeStatus.empty => l10n.shareEmpty,
      ShareIntakeStatus.failed => l10n.shareFailed,
      ShareIntakeStatus.duplicate => null,
    };
    if (message == null) return;

    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
