import 'package:flashnote/data/repositories/source_repository_impl.dart';
import 'package:flashnote/domain/entities/custom_source.dart';
import 'package:flashnote/domain/repositories/source_repository.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  return SourceRepositoryImpl(ref.watch(databaseProvider));
});

final sourceListProvider =
    AsyncNotifierProvider<SourceListNotifier, List<CustomSource>>(
        SourceListNotifier.new);

class SourceListNotifier extends AsyncNotifier<List<CustomSource>> {
  @override
  Future<List<CustomSource>> build() async {
    final repo = ref.read(sourceRepositoryProvider);
    await repo.seedBuiltInSources();
    return repo.getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(sourceRepositoryProvider).getAll());
  }
}
