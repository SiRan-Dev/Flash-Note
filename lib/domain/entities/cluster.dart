import 'package:freezed_annotation/freezed_annotation.dart';

part 'cluster.freezed.dart';
part 'cluster.g.dart';

@freezed
class Cluster with _$Cluster {
  const factory Cluster({
    required int id,
    required String name,
    @Default('') String description,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Cluster;

  factory Cluster.fromJson(Map<String, dynamic> json) =>
      _$ClusterFromJson(json);
}
