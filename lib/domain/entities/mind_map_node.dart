import 'package:freezed_annotation/freezed_annotation.dart';

part 'mind_map_node.freezed.dart';
part 'mind_map_node.g.dart';

@freezed
class MindMapNode with _$MindMapNode {
  const factory MindMapNode({
    required String label,
    @Default([]) List<MindMapNode> children,
  }) = _MindMapNode;

  factory MindMapNode.fromJson(Map<String, dynamic> json) =>
      _$MindMapNodeFromJson(json);
}
