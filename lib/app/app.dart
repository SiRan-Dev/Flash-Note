import 'package:dynamic_color/dynamic_color.dart';
import 'package:flashnote/app/router.dart';
import 'package:flashnote/app/theme/app_theme.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/theme_provider.dart';
import 'package:flashnote/presentation/providers/webdav_provider.dart';
import 'package:flashnote/presentation/widgets/startup_update_checker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlashNoteApp extends ConsumerStatefulWidget {
  const FlashNoteApp({super.key});

  @override
  ConsumerState<FlashNoteApp> createState() => _FlashNoteAppState();
}

class _FlashNoteAppState extends ConsumerState<FlashNoteApp> {
  bool _autoSyncAttempted = false;

  @override
  void initState() {
    super.initState();
    _tryAutoSync();
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
            final lightScheme = useDynamicColor ? lightDynamic : null;
            final darkScheme = useDynamicColor ? darkDynamic : null;
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
                  (context, child) => StartupUpdateChecker(
                    child: child ?? const SizedBox.shrink(),
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
