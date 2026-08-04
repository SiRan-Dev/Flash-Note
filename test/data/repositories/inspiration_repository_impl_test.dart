import 'package:drift/native.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/repositories/inspiration_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InspirationRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = InspirationRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('InspirationRepositoryImpl', () {
    test('create 返回自增 id', () async {
      final id = await repository.create('测试内容');
      expect(id, greaterThan(0));
    });

    test('create 带 source 和 tags', () async {
      final id = await repository.create(
        '测试内容',
        source: 'flash',
        tags: ['标签1', '标签2'],
      );
      final result = await repository.getById(id);
      expect(result, isNotNull);
      expect(result!.source, 'flash');
      expect(result.tags, ['标签1', '标签2']);
    });

    test('getAll 返回所有灵感', () async {
      await repository.create('灵感1');
      await repository.create('灵感2');
      await repository.create('灵感3');

      final results = await repository.getAll();
      expect(results.length, 3);
    });

    test('getAll 按置顶和创建时间排序', () async {
      final id1 = await repository.create('灵感1');
      await repository.create('灵感2');
      await repository.togglePin(id1);

      final results = await repository.getAll();
      expect(results.first.id, id1);
      expect(results.first.isPinned, true);
    });

    test('search 按内容搜索', () async {
      await repository.create('Flutter 开发');
      await repository.create('Dart 编程');
      await repository.create('Flutter 布局');

      final results = await repository.search('Flutter');
      expect(results.length, 2);
    });

    test('search 无匹配返回空列表', () async {
      await repository.create('测试内容');

      final results = await repository.search('不存在');
      expect(results, isEmpty);
    });

    test('filterBySource 按来源过滤', () async {
      await repository.create('灵感1', source: 'flash');
      await repository.create('灵感2', source: 'reading');
      await repository.create('灵感3', source: 'flash');

      final results = await repository.filterBySource('flash');
      expect(results.length, 2);
      for (final r in results) {
        expect(r.source, 'flash');
      }
    });

    test('filterBySource null 返回所有灵感', () async {
      await repository.create('灵感1', source: 'flash');
      await repository.create('灵感2');

      final results = await repository.filterBySource(null);
      expect(results.length, 2);
    });

    test('getById 返回对应灵感', () async {
      final id = await repository.create('测试内容');
      final result = await repository.getById(id);

      expect(result, isNotNull);
      expect(result!.id, id);
      expect(result.content, '测试内容');
    });

    test('getById 不存在返回 null', () async {
      final result = await repository.getById(999);
      expect(result, isNull);
    });

    test('update 修改灵感内容', () async {
      final id = await repository.create('原始内容');
      final original = await repository.getById(id);
      final updated = original!.copyWith(content: '修改后内容');

      await repository.update(updated);
      final result = await repository.getById(id);

      expect(result!.content, '修改后内容');
    });

    test('update 修改 tags', () async {
      final id = await repository.create('测试', tags: ['旧标签']);
      final original = await repository.getById(id);
      final updated = original!.copyWith(tags: ['新标签1', '新标签2']);

      await repository.update(updated);
      final result = await repository.getById(id);

      expect(result!.tags, ['新标签1', '新标签2']);
    });

    test('delete 删除灵感', () async {
      final id = await repository.create('待删除');
      await repository.delete(id);

      final result = await repository.getById(id);
      expect(result, isNull);
    });

    test('delete 记录删除墓碑用于同步', () async {
      final id = await repository.create('待删除');
      await repository.delete(id);

      final tombstones = await db.getAllDeletedRecords();
      expect(tombstones.length, 1);
      expect(tombstones.single.entityType, 'inspirations');
      expect(tombstones.single.entityId, id);
      expect(tombstones.single.deletedAt, greaterThan(0));
    });

    test('togglePin 切换置顶状态', () async {
      final id = await repository.create('测试');
      expect((await repository.getById(id))!.isPinned, false);

      await repository.togglePin(id);
      expect((await repository.getById(id))!.isPinned, true);

      await repository.togglePin(id);
      expect((await repository.getById(id))!.isPinned, false);
    });

    test('创建灵感自动设置时间戳', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      final id = await repository.create('测试');
      final after = DateTime.now().millisecondsSinceEpoch;

      final result = await repository.getById(id);
      expect(
        result!.createdAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(before),
      );
      expect(result.createdAt.millisecondsSinceEpoch, lessThanOrEqualTo(after));
      expect(
        result.updatedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(before),
      );
      expect(result.updatedAt.millisecondsSinceEpoch, lessThanOrEqualTo(after));
    });
  });
}
