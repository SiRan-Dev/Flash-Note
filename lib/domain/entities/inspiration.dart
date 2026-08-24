import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'inspiration.freezed.dart';
part 'inspiration.g.dart';

@freezed
abstract class Inspiration with _$Inspiration {
  const factory Inspiration({
    required int id,
    required String content,
    String? source,
    @Default([]) List<String> tags,
    String? aiAnalysis,
    String? mindMapData,
    @Default(false) bool isPinned,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? reviewedAt,
    @Default(false) bool needsFollowUp,
  }) = _Inspiration;

  const Inspiration._();

  factory Inspiration.fromJson(Map<String, dynamic> json) =>
      _$InspirationFromJson(json);

  String get tagsJson => jsonEncode(tags);

  static List<String> tagsFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list.map((e) => e.toString()).toList();
  }
}
