import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/app_database.dart' as db;
import 'package:flashnote/domain/entities/task.dart' as domain;
import 'package:flashnote/domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final db.AppDatabase _db;

  TaskRepositoryImpl(this._db);

  /// 将 drift 行转换为领域实体
  domain.Task _fromRow(db.Task row) {
    return domain.Task(
      id: row.id,
      projectId: row.projectId,
      title: row.title,
      isCompleted: row.isCompleted,
      isPinned: row.isPinned,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  @override
  Future<List<domain.Task>> getByProjectId(int projectId) async {
    final rows = await _db.getTasksByProjectId(projectId);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<domain.Task?> getById(int id) async {
    final row = await _db.getTaskById(id);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<int> create(int projectId, String title) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = db.TasksCompanion.insert(
      projectId: projectId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    return _db.insertTask(entry);
  }

  @override
  Future<void> toggleComplete(int id) async {
    final task = await getById(id);
    if (task == null) return;

    final entry = db.TasksCompanion(
      isPinned: Value(task.isPinned),
      isCompleted: Value(!task.isCompleted),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await _db.updateTaskPartial(id, entry);
  }

  @override
  Future<void> delete(int id) async {
    await _db.markRecordDeleted('tasks', id);
    await _db.deleteTask(id);
  }

  @override
  Future<void> togglePin(int id) async {
    final task = await getById(id);
    if (task == null) return;

    final entry = db.TasksCompanion(
      isPinned: Value(!task.isPinned),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await _db.updateTaskPartial(id, entry);
  }

  @override
  Future<int> getCompletedCount(int projectId) {
    return _db.getCompletedTaskCount(projectId);
  }

  @override
  Future<int> getTotalCount(int projectId) {
    return _db.getTotalTaskCount(projectId);
  }

  @override
  Future<List<domain.Task>> getAllIncomplete() async {
    final rows = await _db.getAllIncompleteTasks();
    return rows.map(_fromRow).toList();
  }
}
