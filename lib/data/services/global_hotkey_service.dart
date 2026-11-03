import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Win32 modifier flags, mirrored here so the Dart side owns the shortcut.
const int _modifierAlt = 0x0001;
const int _modifierControl = 0x0002;

/// 一个全局热键定义。当前先固定默认值，后续再做可配置。
class GlobalHotkeyDefinition {
  const GlobalHotkeyDefinition({
    required this.label,
    required this.modifiers,
    required this.virtualKey,
  });

  final String label;
  final int modifiers;
  final int virtualKey;
}

/// Ctrl + Alt + Space，避免和常见输入法/系统快捷键冲突。
const GlobalHotkeyDefinition defaultGlobalHotkey = GlobalHotkeyDefinition(
  label: 'Ctrl + Alt + Space',
  modifiers: _modifierControl | _modifierAlt,
  virtualKey: 0x20, // VK_SPACE
);

enum HotkeyRegistrationStatus { registered, failed, unsupported }

class HotkeyRegistrationResult {
  const HotkeyRegistrationResult(this.status, {this.message});

  final HotkeyRegistrationStatus status;
  final String? message;

  bool get isRegistered => status == HotkeyRegistrationStatus.registered;
}

/// 通过 Windows runner 的 MethodChannel 注册系统级热键。
///
/// Linux/macOS 暂未实现原生注册，直接返回 unsupported；Android/iOS 不适用。
class GlobalHotkeyService {
  GlobalHotkeyService({
    MethodChannel channel = const MethodChannel(
      'com.sirandev.flashnote/hotkey',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  void setHandler(Future<Object?> Function(MethodCall call)? handler) {
    _channel.setMethodCallHandler(handler);
  }

  Future<HotkeyRegistrationResult> register(
    GlobalHotkeyDefinition hotkey,
  ) async {
    if (!isSupported) {
      return const HotkeyRegistrationResult(
        HotkeyRegistrationStatus.unsupported,
      );
    }
    try {
      final registered = await _channel.invokeMethod<bool>('register', {
        'modifiers': hotkey.modifiers,
        'key': hotkey.virtualKey,
      });
      if (registered == true) {
        return const HotkeyRegistrationResult(
          HotkeyRegistrationStatus.registered,
        );
      }
      return const HotkeyRegistrationResult(
        HotkeyRegistrationStatus.failed,
        message: 'RegisterHotKey returned false',
      );
    } on MissingPluginException catch (error) {
      return HotkeyRegistrationResult(
        HotkeyRegistrationStatus.failed,
        message: error.message ?? 'hotkey channel is unavailable',
      );
    } on PlatformException catch (error) {
      return HotkeyRegistrationResult(
        HotkeyRegistrationStatus.failed,
        message: error.message ?? error.code,
      );
    } catch (error) {
      return HotkeyRegistrationResult(
        HotkeyRegistrationStatus.failed,
        message: '$error',
      );
    }
  }

  Future<void> unregister() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('unregister');
    } catch (error) {
      debugPrint('Global hotkey unregister failed: $error');
    }
  }
}
