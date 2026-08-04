import 'package:flashnote/domain/entities/cluster.dart';

abstract class ClusterRepository {
  Future<List<Cluster>> getAll();
  Future<Cluster?> getById(int id);
  Future<int> create(Cluster cluster);
  Future<int> update(Cluster cluster);
  Future<int> delete(int id);
}
