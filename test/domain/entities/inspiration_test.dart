import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Inspiration', () {
    test('创建默认灵感', () {
      final now = DateTime.now();
      final inspiration = Inspiration(
        id: 0,
        content: '测试灵感',
        createdAt: now,
        updatedAt: now,
      );

      expect(inspiration.content, '测试灵感');
      expect(inspiration.source, isNull);
      expect(inspiration.tags, isEmpty);
      expect(inspiration.aiAnalysis, isNull);
      expect(inspiration.isPinned, false);
    });

    test('copyWith 修改内容', () {
      final now = DateTime.now();
      final original = Inspiration(
        id: 1,
        content: '原始内容',
        createdAt: now,
        updatedAt: now,
      );

      final copied = original.copyWith(content: '修改后内容', isPinned: true);

      expect(copied.content, '修改后内容');
      expect(copied.isPinned, true);
      expect(copied.id, 1);
    });

    test('tags JSON 序列化', () {
      final now = DateTime.now();
      final inspiration = Inspiration(
        id: 1,
        content: '测试',
        tags: ['标签1', '标签2'],
        createdAt: now,
        updatedAt: now,
      );

      expect(inspiration.tagsJson, '["标签1","标签2"]');
    });

    test('tags 从 JSON 反序列化', () {
      final result = Inspiration.tagsFromJson('["标签1","标签2"]');
      expect(result, ['标签1', '标签2']);
    });

    test('tags 空 JSON 返回空列表', () {
      final result = Inspiration.tagsFromJson('[]');
      expect(result, isEmpty);
    });
  });
}
