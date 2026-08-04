import 'package:flashnote/domain/entities/inspiration.dart';

abstract class InspirationRepository {
  Future<List<Inspiration>> getAll();
  Future<List<Inspiration>> search(String query);
  Future<List<Inspiration>> filterBySource(String? source);
  Future<Inspiration?> getById(int id);
  Future<int> create(String content, {String? source, List<String> tags});
  Future<void> update(Inspiration inspiration);
  Future<void> delete(int id);
  Future<void> togglePin(int id);
  Future<void> updateAiAnalysis(int id, String? aiAnalysisJson);
  Future<void> updateMindMapData(int id, String? mindMapDataJson);

  // Review
  Future<void> markReviewed(int id);
  Future<void> toggleNeedsFollowUp(int id, bool value);
  Future<List<Inspiration>> getRandomUnreviewed({int limit = 3});
  Future<List<Inspiration>> getInspirationsNeedingFollowUp();
  Future<List<Inspiration>> getInspirationsSince(DateTime since);
  Future<int> getUnreviewedCount();
}
