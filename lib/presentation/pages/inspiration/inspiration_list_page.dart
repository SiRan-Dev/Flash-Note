import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/widgets/app_layout.dart';
import 'package:flashnote/presentation/widgets/inspiration_card.dart';
import 'package:flashnote/presentation/widgets/source_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _InspirationSortMode {
  pinnedFirst,
  newestCreated,
  oldestCreated,
  recentlyUpdated,
}

class InspirationListPage extends ConsumerStatefulWidget {
  const InspirationListPage({super.key});

  @override
  ConsumerState<InspirationListPage> createState() =>
      _InspirationListPageState();
}

class _InspirationListPageState extends ConsumerState<InspirationListPage> {
  String? _selectedSource;
  String _searchQuery = '';
  bool _showSearch = false;
  _InspirationSortMode _sortMode = _InspirationSortMode.pinnedFirst;

  Future<void> _openCapturePage() async {
    await context.push('/inspiration/new');
    if (!mounted) return;
    ref.read(inspirationListProvider.notifier).refresh();
    ref.invalidate(homeRecentInspirationsProvider);
  }

  Future<void> _openInspirationDetail(int id) async {
    await context.push('/inspiration/$id');
    if (!mounted) return;
    ref.read(inspirationListProvider.notifier).refresh();
    ref.invalidate(homeRecentInspirationsProvider);
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    int id,
    bool isPinned,
  ) {
    final l10n = AppLocalizations.of(context);
    final copy = _InspirationListCopy.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.sort_rounded),
                  title: Text(copy.sortBy),
                  subtitle: Text(copy.inspirationSortLabel(_sortMode)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSortSheet(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  ),
                  title: Text(isPinned ? l10n.unpin : l10n.pin),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(inspirationListProvider.notifier).togglePin(id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    l10n.delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (dialogCtx) => AlertDialog(
                            title: Text(l10n.deleteInspiration),
                            content: Text(l10n.deleteInspirationConfirm),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.pop(dialogCtx, false),
                                child: Text(l10n.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx, true),
                                child: Text(l10n.delete),
                              ),
                            ],
                          ),
                    );
                    if (confirmed == true) {
                      ref.read(inspirationListProvider.notifier).delete(id);
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showSortSheet(BuildContext context) {
    final copy = _InspirationListCopy.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      copy.sortBy,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                RadioGroup<_InspirationSortMode>(
                  groupValue: _sortMode,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortMode = value);
                    Navigator.pop(ctx);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final mode in _InspirationSortMode.values)
                        RadioListTile<_InspirationSortMode>(
                          value: mode,
                          title: Text(copy.inspirationSortLabel(mode)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  List<Inspiration> _sortInspirations(List<Inspiration> inspirations) {
    final sorted = [...inspirations];
    int byNewestCreated(Inspiration a, Inspiration b) =>
        b.createdAt.compareTo(a.createdAt);
    int byOldestCreated(Inspiration a, Inspiration b) =>
        a.createdAt.compareTo(b.createdAt);
    int byRecentlyUpdated(Inspiration a, Inspiration b) =>
        b.updatedAt.compareTo(a.updatedAt);
    int byPinnedFirst(Inspiration a, Inspiration b) {
      final pinCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pinCompare != 0) return pinCompare;
      return byNewestCreated(a, b);
    }

    sorted.sort(switch (_sortMode) {
      _InspirationSortMode.pinnedFirst => byPinnedFirst,
      _InspirationSortMode.newestCreated => byNewestCreated,
      _InspirationSortMode.oldestCreated => byOldestCreated,
      _InspirationSortMode.recentlyUpdated => byRecentlyUpdated,
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inspirationsAsync = ref.watch(inspirationListProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            _showSearch
                ? TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.searchInspiration,
                    border: InputBorder.none,
                  ),
                  onChanged: (query) {
                    setState(() => _searchQuery = query);
                    ref.read(inspirationListProvider.notifier).search(query);
                  },
                )
                : Text(l10n.inspirations),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  ref.read(inspirationListProvider.notifier).refresh();
                }
              });
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final selectorPadding = AppLayout.pageInsets(
            constraints,
            top: 8,
            bottom: 8,
          );
          final listPadding = AppLayout.pageInsets(constraints);
          return Column(
            children: [
              Padding(
                padding: selectorPadding,
                child: SourceSelector(
                  selectedSource: _selectedSource,
                  onSelected: (source) {
                    setState(() => _selectedSource = source);
                    ref
                        .read(inspirationListProvider.notifier)
                        .filterBySource(source);
                  },
                ),
              ),
              Expanded(
                child: inspirationsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (e, _) => Center(child: Text('${l10n.loadFailed}: $e')),
                  data: (inspirations) {
                    final sortedInspirations = _sortInspirations(inspirations);
                    if (sortedInspirations.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? l10n.noMatchFound
                                  : l10n.noInspirationYet,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (_searchQuery.isEmpty) ...[
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _openCapturePage,
                                icon: const Icon(Icons.add),
                                label: Text(l10n.captureInspiration),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh:
                          () =>
                              ref
                                  .read(inspirationListProvider.notifier)
                                  .refresh(),
                      child: ListView.builder(
                        padding: listPadding,
                        itemCount: sortedInspirations.length,
                        itemBuilder: (context, index) {
                          final inspiration = sortedInspirations[index];
                          return GestureDetector(
                            onSecondaryTap:
                                () => _showContextMenu(
                                  context,
                                  ref,
                                  inspiration.id,
                                  inspiration.isPinned,
                                ),
                            onLongPress:
                                () => _showContextMenu(
                                  context,
                                  ref,
                                  inspiration.id,
                                  inspiration.isPinned,
                                ),
                            child: InspirationCard(
                              inspiration: inspiration,
                              onTap:
                                  () => _openInspirationDetail(inspiration.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCapturePage,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _InspirationListCopy {
  const _InspirationListCopy({required this.isZh});

  _InspirationListCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get sortBy => isZh ? '排序方式' : 'Sort by';

  String inspirationSortLabel(_InspirationSortMode mode) {
    return switch (mode) {
      _InspirationSortMode.pinnedFirst => isZh ? '置顶优先' : 'Pinned first',
      _InspirationSortMode.newestCreated => isZh ? '最新创建' : 'Newest created',
      _InspirationSortMode.oldestCreated => isZh ? '最早创建' : 'Oldest created',
      _InspirationSortMode.recentlyUpdated =>
        isZh ? '最近更新' : 'Recently updated',
    };
  }
}
