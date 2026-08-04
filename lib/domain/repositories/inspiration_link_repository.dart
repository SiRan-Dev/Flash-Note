import 'package:flashnote/domain/entities/inspiration_link.dart';

abstract class InspirationLinkRepository {
  Future<List<InspirationLink>> getLinksForInspiration(int inspirationId);
  Future<List<InspirationLink>> getLinksBySourceId(int sourceId);
  Future<List<InspirationLink>> getLinksByTargetId(int targetId);
  Future<InspirationLink?> getById(int id);
  Future<InspirationLink?> getParentLink(int childId);
  Future<InspirationLink?> getLinkBetween(
    int sourceId,
    int targetId, {
    LinkType? linkType,
    bool directed = false,
  });
  Future<int> create(InspirationLink link);
  Future<int> restore(InspirationLink link);
  Future<int> updateRelationLabel(int id, String? relationLabel);
  Future<int> delete(int id);
  Future<int> deleteParentChild(int parentId, int childId);
  Future<int> deleteForInspiration(int inspirationId);
  Future<bool> exists(
    int sourceId,
    int targetId, {
    LinkType? linkType,
    bool directed = false,
  });
  Future<bool> wouldCreateParentChildCycle(int parentId, int childId);
}
