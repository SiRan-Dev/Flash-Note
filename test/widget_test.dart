import 'package:drift/native.dart';
import 'package:flashnote/app/app.dart';
import 'package:flashnote/data/datasources/local/app_database.dart'
    show AppDatabase;
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/domain/entities/project.dart';
import 'package:flashnote/domain/entities/task.dart';
import 'package:flashnote/domain/repositories/inspiration_repository.dart';
import 'package:flashnote/domain/repositories/project_repository.dart';
import 'package:flashnote/domain/repositories/task_repository.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FlashNoteApp can be instantiated', (WidgetTester tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          inspirationRepositoryProvider.overrideWithValue(
            _FakeInspirationRepository(),
          ),
          projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
        ],
        child: const FlashNoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlashNoteApp), findsOneWidget);
  });
}

class _FakeInspirationRepository implements InspirationRepository {
  final _items = <Inspiration>[];

  @override
  Future<int> create(
    String content, {
    String? source,
    List<String> tags = const [],
  }) async {
    final now = DateTime(2026);
    final item = Inspiration(
      id: _items.length + 1,
      content: content,
      source: source,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
    _items.add(item);
    return item.id;
  }

  @override
  Future<void> delete(int id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<List<Inspiration>> filterBySource(String? source) async {
    if (source == null) return _items;
    return _items.where((item) => item.source == source).toList();
  }

  @override
  Future<List<Inspiration>> getAll() async => _items;

  @override
  Future<Inspiration?> getById(int id) async {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<Inspiration>> getInspirationsNeedingFollowUp() async =>
      _items.where((item) => item.needsFollowUp).toList();

  @override
  Future<List<Inspiration>> getInspirationsSince(DateTime since) async =>
      _items.where((item) => item.createdAt.isAfter(since)).toList();

  @override
  Future<List<Inspiration>> getRandomUnreviewed({int limit = 3}) async =>
      _items.take(limit).toList();

  @override
  Future<int> getUnreviewedCount() async => _items.length;

  @override
  Future<void> markReviewed(int id) async {}

  @override
  Future<List<Inspiration>> search(String query) async {
    return _items.where((item) => item.content.contains(query)).toList();
  }

  @override
  Future<void> toggleNeedsFollowUp(int id, bool value) async {}

  @override
  Future<void> togglePin(int id) async {}

  @override
  Future<void> update(Inspiration inspiration) async {}

  @override
  Future<void> updateAiAnalysis(int id, String? aiAnalysisJson) async {}

  @override
  Future<void> updateMindMapData(int id, String? mindMapDataJson) async {}
}

class _FakeProjectRepository implements ProjectRepository {
  @override
  Future<int> create(
    String title, {
    String description = '',
    int? inspirationId,
  }) async => 1;

  @override
  Future<void> delete(int id) async {}

  @override
  Future<List<Project>> getAll() async => const <Project>[];

  @override
  Future<Project?> getById(int id) async => null;

  @override
  Future<void> togglePin(int id) async {}

  @override
  Future<void> update(Project project) async {}

  @override
  Future<void> updateProgress(int id, int progress) async {}

  @override
  Future<void> updateStatus(int id, String status) async {}
}

class _FakeTaskRepository implements TaskRepository {
  @override
  Future<int> create(int projectId, String title) async => 1;

  @override
  Future<void> delete(int id) async {}

  @override
  Future<List<Task>> getAllIncomplete() async => const <Task>[];

  @override
  Future<List<Task>> getByProjectId(int projectId) async => const <Task>[];

  @override
  Future<int> getCompletedCount(int projectId) async => 0;

  @override
  Future<Task?> getById(int id) async => null;

  @override
  Future<int> getTotalCount(int projectId) async => 0;

  @override
  Future<void> toggleComplete(int id) async {}

  @override
  Future<void> togglePin(int id) async {}
}
