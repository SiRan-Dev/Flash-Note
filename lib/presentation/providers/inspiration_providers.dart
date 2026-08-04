import 'package:flashnote/data/repositories/chat_message_repository_impl.dart';
import 'package:flashnote/data/repositories/inspiration_repository_impl.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/domain/repositories/chat_message_repository.dart';
import 'package:flashnote/domain/repositories/inspiration_repository.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inspirationRepositoryProvider = Provider<InspirationRepository>((ref) {
  return InspirationRepositoryImpl(ref.watch(databaseProvider));
});

final chatMessageRepositoryProvider = Provider<ChatMessageRepository>((ref) {
  return ChatMessageRepositoryImpl(ref.watch(databaseProvider));
});

final inspirationListProvider =
    AsyncNotifierProvider<InspirationListNotifier, List<Inspiration>>(
      InspirationListNotifier.new,
    );

final homeRecentInspirationsProvider = FutureProvider<List<Inspiration>>((ref) {
  return ref.watch(inspirationRepositoryProvider).getAll();
});

class InspirationListNotifier extends AsyncNotifier<List<Inspiration>> {
  @override
  Future<List<Inspiration>> build() {
    return ref.read(inspirationRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(inspirationRepositoryProvider).getAll(),
    );
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = await AsyncValue.guard(
        () => ref.read(inspirationRepositoryProvider).getAll(),
      );
    } else {
      state = await AsyncValue.guard(
        () => ref.read(inspirationRepositoryProvider).search(query),
      );
    }
  }

  Future<void> filterBySource(String? source) async {
    state = await AsyncValue.guard(
      () => ref.read(inspirationRepositoryProvider).filterBySource(source),
    );
  }

  Future<void> delete(int id) async {
    await ref.read(inspirationRepositoryProvider).delete(id);
    await refresh();
  }

  Future<void> togglePin(int id) async {
    await ref.read(inspirationRepositoryProvider).togglePin(id);
    await refresh();
  }
}
