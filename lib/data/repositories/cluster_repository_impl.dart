import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/app_database.dart' as db;
import 'package:flashnote/domain/entities/cluster.dart' as domain;
import 'package:flashnote/domain/repositories/cluster_repository.dart';

class ClusterRepositoryImpl implements ClusterRepository {
  final db.AppDatabase _db;

  ClusterRepositoryImpl(this._db);

  domain.Cluster _fromRow(db.Cluster row) {
    return domain.Cluster(
      id: row.id,
      name: row.name,
      description: row.description,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  @override
  Future<List<domain.Cluster>> getAll() async {
    final rows = await _db.getAllClusters();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<domain.Cluster?> getById(int id) async {
    final row = await _db.getClusterById(id);
    return row != null ? _fromRow(row) : null;
  }

  @override
  Future<int> create(domain.Cluster cluster) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = db.ClustersCompanion.insert(
      name: cluster.name,
      description: Value(cluster.description),
      createdAt: now,
      updatedAt: now,
    );
    return _db.insertCluster(entry);
  }

  @override
  Future<int> update(domain.Cluster cluster) async {
    final entry = db.ClustersCompanion(
      id: Value(cluster.id),
      name: Value(cluster.name),
      description: Value(cluster.description),
      createdAt: Value(cluster.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await _db.updateCluster(entry);
    return cluster.id;
  }

  @override
  Future<int> delete(int id) async {
    await _db.markRecordDeleted('clusters', id);
    return _db.deleteCluster(id);
  }
}
