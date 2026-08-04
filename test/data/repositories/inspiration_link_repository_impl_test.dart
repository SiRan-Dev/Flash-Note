import 'package:drift/native.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/repositories/inspiration_link_repository_impl.dart';
import 'package:flashnote/domain/entities/inspiration_link.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InspirationLinkRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = InspirationLinkRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createLink(
    int sourceId,
    int targetId,
    domain.LinkType type, {
    String? relationLabel,
  }) {
    return repository.create(
      domain.InspirationLink(
        id: 0,
        sourceId: sourceId,
        targetId: targetId,
        linkType: type,
        relationLabel: relationLabel,
        confidence: 1,
        createdAt: DateTime(2026, 5, 16),
      ),
    );
  }

  group('InspirationLinkRepositoryImpl hierarchy', () {
    test('getParentLink 返回子灵感的父子关系', () async {
      await createLink(1, 2, domain.LinkType.parentChild);
      await createLink(3, 2, domain.LinkType.similar);

      final parentLink = await repository.getParentLink(2);

      expect(parentLink, isNotNull);
      expect(parentLink!.sourceId, 1);
      expect(parentLink.targetId, 2);
      expect(parentLink.linkType, domain.LinkType.parentChild);
    });

    test('允许一个子灵感拥有多个父灵感', () async {
      await createLink(
        1,
        3,
        domain.LinkType.parentChild,
        relationLabel: 'belongsTo',
      );
      await createLink(2, 3, domain.LinkType.parentChild);

      final parentLinks =
          (await repository.getLinksByTargetId(3))
              .where((link) => link.linkType == domain.LinkType.parentChild)
              .toList();

      expect(parentLinks, hasLength(2));
      expect(parentLinks.map((link) => link.sourceId), containsAll([1, 2]));
      expect(
        parentLinks.firstWhere((link) => link.sourceId == 1).relationLabel,
        'belongsTo',
      );
      expect(await repository.wouldCreateParentChildCycle(4, 3), isFalse);
    });

    test('updateRelationLabel 修改层级语义', () async {
      final id = await createLink(1, 2, domain.LinkType.parentChild);

      await repository.updateRelationLabel(id, 'supports');

      final link = await repository.getById(id);
      expect(link?.relationLabel, 'supports');
    });

    test('restore 恢复被撤销删除的关系', () async {
      final id = await createLink(
        1,
        2,
        domain.LinkType.parentChild,
        relationLabel: 'breakdown',
      );
      final link = await repository.getById(id);

      await repository.delete(id);
      await repository.restore(link!);

      final restored = await repository.getById(id);
      expect(restored, isNotNull);
      expect(restored!.relationLabel, 'breakdown');
    });

    test('wouldCreateParentChildCycle 阻止反向成环', () async {
      await createLink(1, 2, domain.LinkType.parentChild);
      await createLink(2, 3, domain.LinkType.parentChild);

      expect(await repository.wouldCreateParentChildCycle(3, 1), isTrue);
      expect(await repository.wouldCreateParentChildCycle(3, 4), isFalse);
    });

    test('deleteParentChild 只删除指定方向的父子关系', () async {
      await createLink(1, 2, domain.LinkType.parentChild);
      await createLink(2, 1, domain.LinkType.similar);

      final deleted = await repository.deleteParentChild(1, 2);

      expect(deleted, 1);
      expect(
        await repository.exists(
          1,
          2,
          linkType: domain.LinkType.parentChild,
          directed: true,
        ),
        isFalse,
      );
      expect(
        await repository.exists(1, 2, linkType: domain.LinkType.similar),
        isTrue,
      );
    });
  });
}
