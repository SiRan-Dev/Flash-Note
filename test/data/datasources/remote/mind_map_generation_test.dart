import 'package:flashnote/data/datasources/remote/mind_map_generation.dart';
import 'package:flashnote/domain/entities/mind_map_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeMindMap', () {
    test('移除空节点并压缩空根占位', () {
      const root = MindMapNode(
        label: '  ',
        children: [MindMapNode(label: '机会空间')],
      );

      final sanitized = sanitizeMindMap(root);

      expect(sanitized.label, '机会空间');
      expect(sanitized.children, isEmpty);
    });

    test('去重并压缩与父节点重复的中间层', () {
      const root = MindMapNode(
        label: '智能笔记',
        children: [
          MindMapNode(
            label: '智能笔记',
            children: [MindMapNode(label: '碎片捕捉'), MindMapNode(label: '项目推进')],
          ),
          MindMapNode(label: '碎片捕捉'),
        ],
      );

      final sanitized = sanitizeMindMap(root);
      final labels = sanitized.children.map((node) => node.label).toList();

      expect(labels, ['碎片捕捉', '项目推进']);
    });

    test('限制过深结构并裁剪超大分支', () {
      final root = MindMapNode(
        label: '创意系统',
        children: List.generate(
          8,
          (index) => MindMapNode(
            label: '分支$index',
            children: [
              MindMapNode(
                label: '二级$index',
                children: [
                  MindMapNode(
                    label: '三级$index',
                    children: [MindMapNode(label: '四级$index')],
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final sanitized = sanitizeMindMap(root);

      expect(sanitized.children.length, 6);
      expect(
        sanitized.children.first.children.first.children.first.children,
        isEmpty,
      );
    });
  });
}
