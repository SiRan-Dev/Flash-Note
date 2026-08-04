import 'package:drift/drift.dart';
import 'package:flashnote/core/constants/app_constants.dart';
import 'package:flashnote/data/datasources/local/app_database.dart' as db;
import 'package:flashnote/domain/entities/custom_source.dart' as domain;
import 'package:flashnote/domain/repositories/source_repository.dart';

class SourceRepositoryImpl implements SourceRepository {
  final db.AppDatabase _db;

  SourceRepositoryImpl(this._db);

  /// 将 drift 行转换为领域实体
  domain.CustomSource _fromRow(db.CustomSource row) {
    return domain.CustomSource(
      id: row.id,
      name: row.name,
      icon: row.icon,
      sortOrder: row.sortOrder,
      isBuiltIn: row.isBuiltIn,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }

  @override
  Future<List<domain.CustomSource>> getAll() async {
    final rows = await _db.getAllSources();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> create(String name, String icon) async {
    // 让自定义来源排到内置来源之后
    final existing = await _db.getAllSources();
    final maxSortOrder =
        existing.isEmpty
            ? 0
            : existing.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b);
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = db.CustomSourcesCompanion.insert(
      name: name,
      icon: icon,
      createdAt: now,
      sortOrder: Value(maxSortOrder + 1),
    );
    return _db.insertSource(entry);
  }

  @override
  Future<void> update(domain.CustomSource source) async {
    final entry = db.CustomSourcesCompanion(
      id: Value(source.id),
      name: Value(source.name),
      icon: Value(source.icon),
      sortOrder: Value(source.sortOrder),
      isBuiltIn: Value(source.isBuiltIn),
      createdAt: Value(source.createdAt.millisecondsSinceEpoch),
    );
    await _db.updateSource(entry);
  }

  @override
  Future<void> delete(int id) async {
    await _db.markRecordDeleted('customSources', id);
    await _db.deleteSource(id);
  }

  @override
  Future<void> seedBuiltInSources() async {
    final existing = await _db.getAllSources();
    final existingNames = existing.map((s) => s.name).toSet();

    for (var i = 0; i < AppConstants.builtInSourceKeys.length; i++) {
      final key = AppConstants.builtInSourceKeys[i];
      if (existingNames.contains(key)) continue;

      final icon = AppConstants.builtInSourceIcons[i];
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = db.CustomSourcesCompanion.insert(
        name: key,
        icon: icon,
        createdAt: now,
        isBuiltIn: const Value(true),
        sortOrder: Value(i),
      );
      await _db.insertSource(entry);
    }
  }
}
