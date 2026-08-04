import 'package:flashnote/domain/entities/mind_map_node.dart';

const mindMapSystemPrompt = '''
你是一个思维导图生成助手。请根据用户提供的灵感，生成一个层次自然、结构不对称的主题导图。

只返回 JSON，不要返回解释、Markdown 或代码块。JSON 结构必须是：
{
  "label": "核心命题",
  "children": [
    {
      "label": "主题分支",
      "children": [
        {"label": "延伸点", "children": []}
      ]
    }
  ]
}

要求：
1. 根节点用一句短语概括灵感的核心命题。
2. 整体深度控制在 2 到 4 层，不要机械追求每个分支一样深。
3. 一级主题建议 3 到 6 个，但允许不平均；重要分支可以更深，次要分支可以更浅。
4. 节点文案要简洁、具体、有信息量，避免“主题1”“细节A”“方向二”这类模板化表达。
5. 相邻节点不要重复改写同一句话，不要产出空节点。
6. 输出应更像人在梳理思路，而不是对称的固定树。
''';

MindMapNode sanitizeMindMap(MindMapNode root) {
  final sanitized =
      _sanitizeNode(root, depth: 0) ?? const MindMapNode(label: '核心主题');
  return sanitized;
}

const _maxDepth = 3;

MindMapNode? _sanitizeNode(MindMapNode node, {required int depth}) {
  final label = _normalizeLabel(node.label);
  final children =
      depth >= _maxDepth
          ? const <MindMapNode>[]
          : node.children
              .map((child) => _sanitizeNode(child, depth: depth + 1))
              .whereType<MindMapNode>()
              .toList();

  if (label.isEmpty) {
    if (children.isEmpty) return null;
    if (children.length == 1) return children.first;
    return MindMapNode(label: depth == 0 ? '核心主题' : '延伸点', children: children);
  }

  final dedupedChildren = _dedupeAndCollapse(label, children, depth);
  final limitedChildren =
      dedupedChildren.take(_maxChildrenForDepth(depth)).toList();
  return MindMapNode(label: label, children: limitedChildren);
}

List<MindMapNode> _dedupeAndCollapse(
  String parentLabel,
  List<MindMapNode> children,
  int depth,
) {
  final result = <MindMapNode>[];
  final seen = <String>{};

  for (final child in children) {
    final childLabel = _normalizeLabel(child.label);
    if (childLabel.isEmpty) continue;

    if (_looksRedundant(parentLabel, childLabel)) {
      for (final grandChild in child.children) {
        final key = _normalizeKey(grandChild.label);
        if (key.isEmpty || !seen.add(key)) continue;
        result.add(grandChild);
      }
      continue;
    }

    final key = _normalizeKey(childLabel);
    if (!seen.add(key)) continue;

    if (child.children.length == 1 &&
        _looksRedundant(childLabel, child.children.first.label)) {
      result.add(
        MindMapNode(label: childLabel, children: child.children.first.children),
      );
      continue;
    }

    result.add(child);
  }

  if (depth == 0 && result.length == 1 && result.first.children.isNotEmpty) {
    return result.first.children.take(_maxChildrenForDepth(0)).toList();
  }
  return result;
}

int _maxChildrenForDepth(int depth) {
  if (depth == 0) return 6;
  if (depth == 1) return 5;
  return 4;
}

String _normalizeLabel(String raw) {
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _normalizeKey(String raw) {
  return _normalizeLabel(
    raw,
  ).toLowerCase().replaceAll(RegExp(r'[，。、“”‘’：:；;,.!?\-_/()（）【】\[\]]'), '');
}

bool _looksRedundant(String a, String b) {
  final left = _normalizeKey(a);
  final right = _normalizeKey(b);
  if (left.isEmpty || right.isEmpty) return false;
  if (left == right) return true;
  if (left.length >= 4 && right.length >= 4) {
    return left.contains(right) || right.contains(left);
  }
  return false;
}
