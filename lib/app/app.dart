import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:flashnote/app/router.dart';
import 'package:flashnote/app/theme/app_theme.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/theme_provider.dart';
import 'package:flashnote/presentation/providers/webdav_provider.dart';
import 'package:flashnote/presentation/providers/memory_pressure_provider.dart';
import 'package:flashnote/presentation/widgets/database_gate.dart';
import 'package:flashnote/presentation/widgets/hotkey/global_hotkey_listener.dart';
import 'package:flashnote/presentation/widgets/share_intake/share_intake_listener.dart';
import 'package:flashnote/presentation/widgets/startup_update_checker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class FlashNoteApp extends ConsumerStatefulWidget {
  const FlashNoteApp({super.key});

  @override
  ConsumerState<FlashNoteApp> createState() => _FlashNoteAppState();
}

class _FlashNoteAppState extends ConsumerState<FlashNoteApp> {
  bool _autoSyncAttempted = false;
  final _fairMemoryChannel = const MethodChannel(
    'com.sirandev.flashnote/fairmemory',
  );

  @override
  void initState() {
    super.initState();
    _tryAutoSync();
    _fairMemoryChannel.setMethodCallHandler(_handleFairMemory);
  }

  @override
  void dispose() {
    _fairMemoryChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<Object?> _handleFairMemory(MethodCall call) async {
    if (call.method == 'onTrim') {
      // Release the most memory-heavy native resource Flutter holds: the image
      // cache. Live lists rebuild thumbnails on demand.
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      // Notify providers so screens can flush unsaved drafts to storage.
      final args = call.arguments;
      final isKill = args is Map ? (args['isKill'] as bool? ?? false) : false;
      ref.read(memoryPressureProvider.notifier).notifyTrim(isKill: isKill);
    }
    return null;
  }

  Future<void> _tryAutoSync() async {
    if (_autoSyncAttempted) return;
    _autoSyncAttempted = true;
    try {
      final storage = await ref.read(webdavStorageProvider.future);
      final configured = await storage.isConfigured;
      if (!configured || !storage.autoSync) return;
      final intervalMinutes = storage.syncIntervalMinutes;
      final lastSyncTime = storage.lastSyncTime;
      if (intervalMinutes > 0 && lastSyncTime != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - lastSyncTime;
        if (elapsed < Duration(minutes: intervalMinutes).inMilliseconds) {
          return;
        }
      }
      ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);
      final service = await ref.read(webdavSyncServiceProvider.future);
      await service.mergeSync();
    } catch (_) {
      // Auto-sync failure is silent
    } finally {
      ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.done);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return Consumer(
          builder: (context, ref, _) {
            final themeMode = ref.watch(themeModeProvider);
            final languageMode = ref.watch(languageModeProvider);
            final amoled = ref.watch(amoledBlackProvider);
            final themeSeedColor = ref.watch(themeSeedColorProvider);
            final useDynamicColor = ref.watch(dynamicColorProvider);
            // dynamic_color 2.x provides a material_ui.ColorScheme, which is a
            // distinct type from Flutter's ColorScheme, so convert it here.
            final lightScheme = useDynamicColor ? _toFlutterColorScheme(lightDynamic) : null;
            final darkScheme = useDynamicColor ? _toFlutterColorScheme(darkDynamic) : null;
            final seedColor =
                useDynamicColor && lightDynamic != null && darkDynamic != null
                    ? null
                    : themeSeedColor;

            return MaterialApp.router(
              title: 'Flash Note',
              onGenerateTitle:
                  (context) => AppLocalizations.of(context).appName,
              locale: languageMode.locale,
              theme: AppTheme.light(
                dynamicScheme: lightScheme,
                seedColor: seedColor,
              ),
              darkTheme: AppTheme.dark(
                dynamicScheme: darkScheme,
                seedColor: seedColor,
                amoled: amoled,
              ),
              themeMode: themeMode,
              scrollBehavior: const _FlashNoteScrollBehavior(),
              routerConfig: router,
              builder:
                  (context, child) => DatabaseGate(
                    child: ShareIntakeListener(
                      child: GlobalHotkeyListener(
                        child: StartupUpdateChecker(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('zh'), Locale('en')],
            );
          },
        );
      },
    );
  }
}

class _FlashNoteScrollBehavior extends MaterialScrollBehavior {
  const _FlashNoteScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}

/// Converts a [mui.ColorScheme] (provided by dynamic_color 2.x) into Flutter's
/// [ColorScheme]. Both expose identical Material 3 roles, so this is a 1:1
/// field mapping.
ColorScheme? _toFlutterColorScheme(mui.ColorScheme? scheme) {
  if (scheme == null) return null;
  return ColorScheme(
    brightness: scheme.brightness,
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    primaryContainer: scheme.primaryContainer,
    onPrimaryContainer: scheme.onPrimaryContainer,
    primaryFixed: scheme.primaryFixed,
    primaryFixedDim: scheme.primaryFixedDim,
    onPrimaryFixed: scheme.onPrimaryFixed,
    onPrimaryFixedVariant: scheme.onPrimaryFixedVariant,
    secondary: scheme.secondary,
    secondaryContainer: scheme.secondaryContainer,
    onSecondary: scheme.onSecondary,
    onSecondaryContainer: scheme.onSecondaryContainer,
    secondaryFixed: scheme.secondaryFixed,
    secondaryFixedDim: scheme.secondaryFixedDim,
    onSecondaryFixed: scheme.onSecondaryFixed,
    onSecondaryFixedVariant: scheme.onSecondaryFixedVariant,
    tertiary: scheme.tertiary,
    tertiaryContainer: scheme.tertiaryContainer,
    onTertiary: scheme.onTertiary,
    onTertiaryContainer: scheme.onTertiaryContainer,
    tertiaryFixed: scheme.tertiaryFixed,
    tertiaryFixedDim: scheme.tertiaryFixedDim,
    onTertiaryFixed: scheme.onTertiaryFixed,
    onTertiaryFixedVariant: scheme.onTertiaryFixedVariant,
    error: scheme.error,
    onError: scheme.onError,
    errorContainer: scheme.errorContainer,
    onErrorContainer: scheme.onErrorContainer,
    surface: scheme.surface,
    onSurface: scheme.onSurface,
    surfaceDim: scheme.surfaceDim,
    surfaceBright: scheme.surfaceBright,
    surfaceContainerLowest: scheme.surfaceContainerLowest,
    surfaceContainerLow: scheme.surfaceContainerLow,
    surfaceContainer: scheme.surfaceContainer,
    surfaceContainerHigh: scheme.surfaceContainerHigh,
    surfaceContainerHighest: scheme.surfaceContainerHighest,
    onSurfaceVariant: scheme.onSurfaceVariant,
    outline: scheme.outline,
    outlineVariant: scheme.outlineVariant,
    shadow: scheme.shadow,
    scrim: scheme.scrim,
    inverseSurface: scheme.inverseSurface,
    onInverseSurface: scheme.onInverseSurface,
    inversePrimary: scheme.inversePrimary,
    surfaceTint: scheme.surfaceTint,
  );
}
