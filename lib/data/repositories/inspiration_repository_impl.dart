import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/app_database.dart' as db;
import 'package:flashnote/domain/entities/inspiration.dart' as domain;
import 'package:flashnote/domain/repositories/inspiration_repository.dart';

class InspirationRepositoryImpl implements InspirationRepository {
  final db.AppDatabase _db;

  InspirationRepositoryImpl(this._db);

  /// 将 drift 行转换为领域实体
  domain.Inspiration _fromRow(db.Inspiration row) {
    return domain.Inspiration(
      id: row.id,
      content: row.content,
      source: row.source,
      tags: domain.Inspiration.tagsFromJson(row.tags),
      aiAnalysis: row.aiAnalysis,
      mindMapData: row.mindMapData,
      isPinned: row.isPinned,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      reviewedAt:
          row.reviewedAt != null
              ? DateTime.fromMillisecondsSinceEpoch(row.reviewedAt!)
              : null,
      needsFollowUp: row.needsFollowUp,
    );
  }

  @override
  Future<List<domain.Inspiration>> getAll() async {
    final rows = await _db.getAllInspirations();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<domain.Inspiration>> search(String query) async {
    final rows = await _db.searchInspirations(query);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<domain.Inspiration>> filterBySource(String? source) async {
    final rows = await _db.filterBySource(source);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<domain.Inspiration?> getById(int id) async {
    final row = await _db.getInspirationById(id);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<int> create(
    String content, {
    String? source,
    List<String> tags = const [],
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = db.InspirationsCompanion.insert(
      content: content,
      createdAt: now,
      updatedAt: now,
      source: source != null ? Value(source) : const Value.absent(),
      tags: Value(jsonEncode(tags)),
    );
    return _db.insertInspiration(entry);
  }

  @override
  Future<void> update(domain.Inspiration inspiration) async {
    final entry = db.InspirationsCompanion(
      id: Value(inspiration.id),
      content: Value(inspiration.content),
      source: Value(inspiration.source),
      tags: Value(jsonEncode(inspiration.tags)),
      aiAnalysis: Value(inspiration.aiAnalysis),
      mindMapData: Value(inspiration.mindMapData),
      isPinned: Value(inspiration.isPinned),
      createdAt: Value(inspiration.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await _db.updateInspiration(entry);
  }

  @override
  Future<void> delete(int id) async {
    await _db.markRecordDeleted('inspirations', id);
    await _db.deleteInspiration(id);
  }

  @override
  Future<void> togglePin(int id) async {
    final inspiration = await getById(id);
    if (inspiration == null) return;

    final entry = db.InspirationsCompanion(
      isPinned: Value(!inspiration.isPinned),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await _db.updateInspirationPartial(id, entry);
  }

  @override
  Future<void> updateAiAnalysis(int id, String? aiAnalysisJson) async {
    if (aiAnalysisJson == null) {
      await _db.clearAiAnalysis(id);
    } else {
      await _db.updateAiAnalysis(id, aiAnalysisJson);
    }
  }

  @override
  Future<void> updateMindMapData(int id, String? mindMapDataJson) async {
    if (mindMapDataJson == null) {
      await _db.clearMindMapData(id);
    } else {
      await _db.updateMindMapData(id, mindMapDataJson);
    }
  }

  @override
  Future<void> markReviewed(int id) => _db.markReviewed(id);

  @override
  Future<void> toggleNeedsFollowUp(int id, bool value) =>
      _db.toggleNeedsFollowUp(id, value);

  @override
  Future<List<domain.Inspiration>> getRandomUnreviewed({int limit = 3}) async {
    final rows = await _db.getRandomUnreviewed(limit: limit);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<domain.Inspiration>> getInspirationsNeedingFollowUp() async {
    final rows = await _db.getInspirationsNeedingFollowUp();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<domain.Inspiration>> getInspirationsSince(DateTime since) async {
    final rows = await _db.getInspirationsSince(since.millisecondsSinceEpoch);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> getUnreviewedCount() => _db.getUnreviewedCount();
}
