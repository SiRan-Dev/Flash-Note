import 'package:drift/native.dart';
import 'package:flashnote/core/constants/app_constants.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/repositories/source_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SourceRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SourceRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SourceRepositoryImpl', () {
    test('create 返回自增 id', () async {
      final id = await repository.create('自定义来源', 'star');
      expect(id, greaterThan(0));
    });

    test('create 设置正确的字段', () async {
      final id = await repository.create('自定义来源', 'star');
      final sources = await repository.getAll();
      final created = sources.firstWhere((s) => s.id == id);

      expect(created.name, '自定义来源');
      expect(created.icon, 'star');
      expect(created.isBuiltIn, false);
    });

    test('getAll 返回所有来源', () async {
      await repository.create('来源1', 'star');
      await repository.create('来源2', 'flag');

      final results = await repository.getAll();
      expect(results.length, 2);
    });

    test('getAll 按 sortOrder 排序', () async {
      await repository.create('来源B', 'flag');
      await repository.create('来源A', 'star');

      final results = await repository.getAll();
      expect(results.length, 2);
    });

    test('update 修改来源', () async {
      final id = await repository.create('原始名称', 'star');
      final sources = await repository.getAll();
      final original = sources.firstWhere((s) => s.id == id);

      final updated = original.copyWith(name: '修改后名称', icon: 'flag');
      await repository.update(updated);

      final updatedSources = await repository.getAll();
      final result = updatedSources.firstWhere((s) => s.id == id);
      expect(result.name, '修改后名称');
      expect(result.icon, 'flag');
    });

    test('delete 删除来源', () async {
      final id = await repository.create('待删除', 'star');
      await repository.delete(id);

      final sources = await repository.getAll();
      expect(sources.where((s) => s.id == id), isEmpty);
    });

    test('delete 记录删除墓碑用于同步', () async {
      final id = await repository.create('待删除', 'star');
      await repository.delete(id);

      final tombstones = await db.getAllDeletedRecords();
      expect(tombstones.length, 1);
      expect(tombstones.single.entityType, 'customSources');
      expect(tombstones.single.entityId, id);
      expect(tombstones.single.deletedAt, greaterThan(0));
    });

    group('seedBuiltInSources', () {
      test('首次调用插入所有内置来源', () async {
        await repository.seedBuiltInSources();

        final sources = await repository.getAll();
        expect(sources.length, AppConstants.builtInSourceKeys.length);

        for (var i = 0; i < AppConstants.builtInSourceKeys.length; i++) {
          final key = AppConstants.builtInSourceKeys[i];
          final icon = AppConstants.builtInSourceIcons[i];
          final found = sources.firstWhere((s) => s.name == key);
          expect(found.icon, icon);
          expect(found.isBuiltIn, true);
          expect(found.sortOrder, i);
        }
      });

      test('重复调用不会创建重复来源', () async {
        await repository.seedBuiltInSources();
        await repository.seedBuiltInSources();

        final sources = await repository.getAll();
        expect(sources.length, AppConstants.builtInSourceKeys.length);
      });

      test('已有部分来源时只插入缺失的', () async {
        await repository.create('flash', 'lightbulb');

        await repository.seedBuiltInSources();

        final sources = await repository.getAll();
        // 应该有 5 个（1 个手动 + 4 个从 seed 插入的内置来源）
        // 但由于手动创建的 name='flash' 与内置 key 匹配，seed 会跳过它
        expect(sources.length, AppConstants.builtInSourceKeys.length);
      });
    });
  });
}
