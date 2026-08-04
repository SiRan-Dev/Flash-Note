import 'package:flashnote/domain/entities/custom_source.dart';

abstract class SourceRepository {
  Future<List<CustomSource>> getAll();
  Future<int> create(String name, String icon);
  Future<void> update(CustomSource source);
  Future<void> delete(int id);
  Future<void> seedBuiltInSources();
}
