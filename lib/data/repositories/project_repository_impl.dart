import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/app_database.dart' as db;
import 'package:flashnote/domain/entities/project.dart' as domain;
import 'package:flashnote/domain/repositories/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final db.AppDatabase _db;

  ProjectRepositoryImpl(this._db);

  /// 将 drift 行转换为领域实体
  domain.Project _fromRow(db.Project row) {
    return domain.Project(
      id: row.id,
      inspirationId: row.inspirationId,
      title: row.title,
      description: row.description,
      progress: row.progress,
      status: row.status,
      isPinned: row.isPinned,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  @override
  Future<List<domain.Project>> getAll() async {
    final rows = await _db.getAllProjects();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<domain.Project?> getById(int id) async {
    final row = await _db.getProjectById(id);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<int> create(
    String title, {
    String description = '',
    int? inspirationId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = db.ProjectsCompanion.insert(
      title: title,
      createdAt: now,
      updatedAt: now,
      description: Value(description),
      inspirationId:
          inspirationId != null ? Value(inspirationId) : const Value.absent(),
    );
    return _db.insertProject(entry);
  }

  @override
  Future<void> update(domain.Project project) async {
    final entry = db.ProjectsCompanion(
      id: Value(project.id),
      inspirationId: Value(project.inspirationId),
      title: Value(project.title),
      description: Value(project.description),
      progress: Value(project.progress),
      status: Value(project.status),
      isPinned: Value(project.isPinned),
      createdAt: Value(project.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await _db.updateProject(entry);
  }

  @override
  Future<void> delete(int id) async {
    await _db.markRecordDeleted('projects', id);
    await _db.deleteProject(id);
  }

  @override
  Future<void> togglePin(int id) async {
    final project = await getById(id);
    if (project == null) return;

    final entry = db.ProjectsCompanion(
      isPinned: Value(!project.isPinned),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await _db.updateProjectPartial(id, entry);
  }

  @override
  Future<void> updateStatus(int id, String status) async {
    final entry = db.ProjectsCompanion(
      status: Value(status),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await _db.updateProjectPartial(id, entry);
  }

  @override
  Future<void> updateProgress(int id, int progress) async {
    final entry = db.ProjectsCompanion(
      progress: Value(progress),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await _db.updateProjectPartial(id, entry);
  }
}
