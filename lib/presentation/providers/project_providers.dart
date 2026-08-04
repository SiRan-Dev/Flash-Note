import 'package:flashnote/data/repositories/project_repository_impl.dart';
import 'package:flashnote/data/repositories/task_repository_impl.dart';
import 'package:flashnote/domain/entities/project.dart';
import 'package:flashnote/domain/entities/task.dart';
import 'package:flashnote/domain/repositories/project_repository.dart';
import 'package:flashnote/domain/repositories/task_repository.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(ref.watch(databaseProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(databaseProvider));
});

final projectListProvider =
    AsyncNotifierProvider<ProjectListNotifier, List<Project>>(
      ProjectListNotifier.new,
    );

class ProjectListNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() {
    return ref.read(projectRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(projectRepositoryProvider).getAll(),
    );
  }

  Future<void> delete(int id) async {
    await ref.read(projectRepositoryProvider).delete(id);
    await refresh();
  }

  Future<void> togglePin(int id) async {
    await ref.read(projectRepositoryProvider).togglePin(id);
    await refresh();
  }
}

final projectDetailProvider =
    AsyncNotifierProvider.family<ProjectDetailNotifier, Project?, int>(
      ProjectDetailNotifier.new,
    );

class ProjectDetailNotifier extends FamilyAsyncNotifier<Project?, int> {
  @override
  Future<Project?> build(int projectId) {
    return ref.read(projectRepositoryProvider).getById(projectId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(projectRepositoryProvider).getById(arg),
    );
  }
}

final incompleteTasksProvider =
    AsyncNotifierProvider<IncompleteTasksNotifier, List<Task>>(
      IncompleteTasksNotifier.new,
    );

class IncompleteTasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() {
    return ref.read(taskRepositoryProvider).getAllIncomplete();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).getAllIncomplete(),
    );
  }
}

final taskListProvider =
    AsyncNotifierProvider.family<TaskListNotifier, List<Task>, int>(
      TaskListNotifier.new,
    );

class TaskListNotifier extends FamilyAsyncNotifier<List<Task>, int> {
  @override
  Future<List<Task>> build(int projectId) {
    return ref.read(taskRepositoryProvider).getByProjectId(projectId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).getByProjectId(arg),
    );
  }

  Future<void> addTask(String title) async {
    await ref.read(taskRepositoryProvider).create(arg, title);
    ref.invalidate(incompleteTasksProvider);
    // Auto-update project progress
    await _updateProjectProgress();
    await refresh();
  }

  Future<void> toggleComplete(int taskId) async {
    await ref.read(taskRepositoryProvider).toggleComplete(taskId);
    ref.invalidate(incompleteTasksProvider);
    await _updateProjectProgress();
    await refresh();
  }

  Future<void> deleteTask(int taskId) async {
    await ref.read(taskRepositoryProvider).delete(taskId);
    ref.invalidate(incompleteTasksProvider);
    await _updateProjectProgress();
    await refresh();
  }

  Future<void> _updateProjectProgress() async {
    final taskRepo = ref.read(taskRepositoryProvider);
    final projectRepo = ref.read(projectRepositoryProvider);
    final total = await taskRepo.getTotalCount(arg);
    if (total == 0) {
      await projectRepo.updateProgress(arg, 0);
      return;
    }
    final completed = await taskRepo.getCompletedCount(arg);
    final progress = (completed / total * 100).round();
    await projectRepo.updateProgress(arg, progress);
    // Auto-set status to completed if all tasks done
    if (progress == 100) {
      await projectRepo.updateStatus(arg, 'completed');
    }
    // Sync project list & detail pages
    ref.invalidate(projectListProvider);
    ref.invalidate(projectDetailProvider(arg));
  }
}
