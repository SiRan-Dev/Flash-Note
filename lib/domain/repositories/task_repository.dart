import 'package:flashnote/domain/entities/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getByProjectId(int projectId);
  Future<Task?> getById(int id);
  Future<int> create(int projectId, String title);
  Future<void> toggleComplete(int id);
  Future<void> delete(int id);
  Future<void> togglePin(int id);
  Future<int> getCompletedCount(int projectId);
  Future<int> getTotalCount(int projectId);
  Future<List<Task>> getAllIncomplete();
}
