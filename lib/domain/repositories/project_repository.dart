import 'package:flashnote/domain/entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAll();
  Future<Project?> getById(int id);
  Future<int> create(String title, {String description = '', int? inspirationId});
  Future<void> update(Project project);
  Future<void> delete(int id);
  Future<void> togglePin(int id);
  Future<void> updateStatus(int id, String status);
  Future<void> updateProgress(int id, int progress);
}
