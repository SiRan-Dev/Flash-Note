import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_analysis_result.freezed.dart';
part 'ai_analysis_result.g.dart';

@freezed
abstract class AiAnalysisResult with _$AiAnalysisResult {
  const factory AiAnalysisResult({
    required int feasibility,
    required int potential,
    required int risk,
    required String suggestions,
  }) = _AiAnalysisResult;

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$AiAnalysisResultFromJson(json);
}
