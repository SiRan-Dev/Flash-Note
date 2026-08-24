import 'package:freezed_annotation/freezed_annotation.dart';

part 'custom_source.freezed.dart';
part 'custom_source.g.dart';

@freezed
abstract class CustomSource with _$CustomSource {
  const factory CustomSource({
    required int id,
    required String name,
    required String icon,
    @Default(0) int sortOrder,
    @Default(false) bool isBuiltIn,
    required DateTime createdAt,
  }) = _CustomSource;

  factory CustomSource.fromJson(Map<String, dynamic> json) =>
      _$CustomSourceFromJson(json);
}
