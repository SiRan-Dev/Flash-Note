import 'package:flashnote/data/services/global_hotkey_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.sirandev.flashnote/hotkey');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('Windows 下注册成功会发送固定默认热键', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });

    final service = GlobalHotkeyService();
    final result = await service.register(defaultGlobalHotkey);

    expect(result.status, HotkeyRegistrationStatus.registered);
    expect(captured, isNotNull);
    expect(captured!.method, 'register');
    expect(captured!.arguments, {'modifiers': 3, 'key': 32});
  });

  test('原生注册被占用时返回失败', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => false);

    final service = GlobalHotkeyService();
    final result = await service.register(defaultGlobalHotkey);

    expect(result.status, HotkeyRegistrationStatus.failed);
    expect(result.message, contains('RegisterHotKey'));
  });

  test('非 Windows 平台不调用原生通道', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return true;
    });

    final service = GlobalHotkeyService();
    final result = await service.register(defaultGlobalHotkey);

    expect(result.status, HotkeyRegistrationStatus.unsupported);
    expect(called, isFalse);
  });

  test('原生通道缺失时降级为失败而不是抛异常', () async {
    final service = GlobalHotkeyService();
    final result = await service.register(defaultGlobalHotkey);

    expect(result.status, HotkeyRegistrationStatus.failed);
    expect(result.message, isNotNull);
  });
}
