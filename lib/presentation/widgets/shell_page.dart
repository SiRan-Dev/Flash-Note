import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/webdav_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ShellPage extends ConsumerWidget {
  const ShellPage({super.key, required this.child});

  final Widget child;

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/inspirations')) return 1;
    if (location.startsWith('/projects')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/inspirations');
      case 2:
        context.go('/projects');
      case 3:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            height: syncStatus == SyncStatus.syncing ? 3 : 0,
            child: syncStatus == SyncStatus.syncing
                ? const LinearProgressIndicator(minHeight: 3)
                : const SizedBox.shrink(),
          ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: SafeArea(
        // Only guard the bottom: the top is irrelevant for a bottom bar, and
        // use viewPadding so the keyboard (viewInsets) does not shrink it.
        top: false,
        bottom: true,
        child:         NavigationBar(
          // Reserve space for the system gesture/navigation bar so destinations
          // are not obscured when the app runs edge-to-edge.
          selectedIndex: _getCurrentIndex(context),
          onDestinationSelected: (index) => _onTap(context, index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l10n.home,
            ),
            NavigationDestination(
              icon: const Icon(Icons.lightbulb_outline_rounded),
              selectedIcon: const Icon(Icons.lightbulb_rounded),
              label: l10n.inspirations,
            ),
            NavigationDestination(
              icon: const Icon(Icons.folder_outlined),
              selectedIcon: const Icon(Icons.folder_rounded),
              label: l10n.projects,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.settings,
            ),
          ],
        ),
      ),
    );
  }
}
