import 'package:flashnote/app/router.dart';
import 'package:flashnote/data/services/global_hotkey_service.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 注册桌面全局热键，并在触发时复用现有窗口与 `/inspiration/new` 路由。
class GlobalHotkeyListener extends StatefulWidget {
  const GlobalHotkeyListener({super.key, required this.child});

  final Widget child;

  @override
  State<GlobalHotkeyListener> createState() => _GlobalHotkeyListenerState();
}

class _GlobalHotkeyListenerState extends State<GlobalHotkeyListener> {
  static final GlobalHotkeyService _service = GlobalHotkeyService();

  @override
  void initState() {
    super.initState();
    if (!_service.isSupported) return;
    _service.setHandler(_onMethodCall);
    // 等首帧挂上 Scaffold 后再注册，失败提示才能显示出来。
    WidgetsBinding.instance.addPostFrameCallback((_) => _register());
  }

  @override
  void dispose() {
    if (_service.isSupported) {
      _service.setHandler(null);
      _service.unregister();
    }
    super.dispose();
  }

  Future<void> _register() async {
    final result = await _service.register(defaultGlobalHotkey);
    if (result.status == HotkeyRegistrationStatus.failed) {
      debugPrint('Global hotkey registration failed: ${result.message}');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.hotkeyRegistrationFailed)));
    }
  }

  Future<Object?> _onMethodCall(MethodCall call) async {
    if (call.method != 'onHotkey') return null;
    final current = router.routeInformationProvider.value.uri.path;
    if (current != '/inspiration/new') {
      router.push('/inspiration/new');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
