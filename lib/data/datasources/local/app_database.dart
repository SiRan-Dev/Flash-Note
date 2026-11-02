import 'package:drift/drift.dart';
import 'package:flashnote/core/constants/app_constants.dart';
import 'package:flashnote/data/datasources/local/connection/connection.dart';
import 'package:flashnote/data/datasources/local/schema_versions.dart';
import 'package:flashnote/data/datasources/local/tables/attachment_table.dart';
import 'package:flashnote/data/datasources/local/tables/chat_message_table.dart';
import 'package:flashnote/data/datasources/local/tables/cluster_table.dart';
import 'package:flashnote/data/datasources/local/tables/custom_source_table.dart';
import 'package:flashnote/data/datasources/local/tables/deleted_record_table.dart';
import 'package:flashnote/data/datasources/local/tables/global_chat_message_table.dart';
import 'package:flashnote/data/datasources/local/tables/inspiration_link_table.dart';
import 'package:flashnote/data/datasources/local/tables/inspiration_table.dart';
import 'package:flashnote/data/datasources/local/tables/project_table.dart';
import 'package:flashnote/data/datasources/local/tables/report_table.dart';
import 'package:flashnote/data/datasources/local/tables/task_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Inspirations,
    CustomSources,
    Projects,
    Tasks,
    ChatMessages,
    Attachments,
    InspirationLinks,
    Clusters,
    DeletedRecords,
    Reports,
    GlobalChatMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : onMigrationFinishedForTesting = null, super(openConnection());

  // For testing with in-memory database
  AppDatabase.forTesting(super.e, {this.onMigrationFinishedForTesting});

  /// Test-only hook called inside the migration transaction after every step.
  ///
  /// Throwing from it simulates a failure halfway through an upgrade, allowing
  /// tests to assert that the transaction rolled everything back.
  final Future<void> Function()? onMigrationFinishedForTesting;

  @override
  int get schemaVersion => AppConstants.schemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // drift 不会自动为 onUpgrade 包事务；这里把全部迁移步骤放进一个事务，
      // 任何一步失败都会回滚 DDL，并让 drift 在成功后才写入 user_version。
      await m.database.transaction(() async {
        await _runUpgradeSteps(m, from, to);
        await onMigrationFinishedForTesting?.call();
      });
    },
  );

  Future<void> _runUpgradeSteps(Migrator m, int from, int to) async {
    if (from < 2) {
      await _addColumnIfMissing(m, inspirations, inspirations.mindMapData);
    }
    if (from < 3) {
      await m.createTable(projects);
      await m.createTable(tasks);
    }
    if (from < 4) {
      await m.createTable(chatMessages);
    }
    if (from < 5) {
      await m.createTable(attachments);
    }
    if (from < 6) {
      await m.createTable(inspirationLinks);
      await m.createTable(clusters);
    }
    if (from < 7) {
      // 保留历史 SQL 形态，但先检查列是否已存在，这样迁移被中断后重试
      // 也不会再次 ADD COLUMN 而失败。
      await _addRawColumnIfMissing(
        m,
        inspirations.actualTableName,
        'reviewed_at',
        'INTEGER',
      );
      await _addRawColumnIfMissing(
        m,
        inspirations.actualTableName,
        'needs_follow_up',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (from < 8) {
      await m.createTable(deletedRecords);
    }
    if (from < 9) {
      await m.createTable(reports);
    }
    if (from < 10) {
      await _addColumnIfMissing(
        m,
        inspirationLinks,
        inspirationLinks.relationLabel,
      );
    }
    if (from < 11) {
      await m.createTable(globalChatMessages);
    }

    // v11 起交给 schema 基线驱动的增量迁移。修改 schema 后的维护流程：
    //   dart run drift_dev schema dump lib/data/datasources/local/app_database.dart drift_schemas/
    //   dart run drift_dev schema steps drift_schemas/ lib/data/datasources/local/schema_versions.dart
    //   dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
    // 生成出的 from11To12 回调直接传给下面的 migrationSteps()。
    if (to > 11 && from < to) {
      await m.runMigrationSteps(
        from: from > 11 ? from : 11,
        to: to,
        steps: migrationSteps(),
      );
    }
  }

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final columns = await _tableColumns(m, table.actualTableName);
    if (columns.contains(column.name)) return;
    await m.addColumn(table, column);
  }

  Future<void> _addRawColumnIfMissing(
    Migrator m,
    String tableName,
    String columnName,
    String definition,
  ) async {
    final columns = await _tableColumns(m, tableName);
    if (columns.contains(columnName)) return;
    await m.database.customStatement(
      'ALTER TABLE "$tableName" ADD COLUMN $columnName $definition',
    );
  }

  Future<Set<String>> _tableColumns(Migrator m, String tableName) async {
    final rows = await m.database
        .customSelect('PRAGMA table_info("$tableName")')
        .get();
    return {for (final row in rows) row.read<String>('name')};
  }

  // === Inspirations ===

  Future<List<Inspiration>> getAllInspirations() =>
      (select(inspirations)..orderBy([
        (t) => OrderingTerm.desc(t.isPinned),
        (t) => OrderingTerm.desc(t.createdAt),
      ])).get();

  Future<List<Inspiration>> searchInspirations(String query) =>
      (select(inspirations)
            ..where((t) => t.content.like('%$query%'))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .get();

  Future<List<Inspiration>> filterBySource(String? source) {
    if (source == null) return getAllInspirations();
    return (select(inspirations)
          ..where((t) => t.source.equals(source))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .get();
  }

  Future<Inspiration?> getInspirationById(int id) =>
      (select(inspirations)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertInspiration(InspirationsCompanion entry) =>
      into(inspirations).insert(entry);

  Future<bool> updateInspiration(InspirationsCompanion entry) =>
      update(inspirations).replace(entry);

  Future<int> updateInspirationPartial(int id, InspirationsCompanion entry) =>
      (update(inspirations)..where((t) => t.id.equals(id))).write(entry);

  Future<int> deleteInspiration(int id) =>
      (delete(inspirations)..where((t) => t.id.equals(id))).go();

  // === CustomSources ===

  Future<List<CustomSource>> getAllSources() =>
      (select(customSources)
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Future<int> insertSource(CustomSourcesCompanion entry) =>
      into(customSources).insert(entry);

  Future<bool> updateSource(CustomSourcesCompanion entry) =>
      update(customSources).replace(entry);

  Future<int> updateSourcePartial(int id, CustomSourcesCompanion entry) =>
      (update(customSources)..where((t) => t.id.equals(id))).write(entry);

  Future<int> deleteSource(int id) =>
      (delete(customSources)..where((t) => t.id.equals(id))).go();

  Future<int> deleteAllSources() => delete(customSources).go();

  // === Projects ===

  Future<List<Project>> getAllProjects() =>
      (select(projects)..orderBy([
        (t) => OrderingTerm.desc(t.isPinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ])).get();

  Future<Project?> getProjectById(int id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);

  Future<bool> updateProject(ProjectsCompanion entry) =>
      update(projects).replace(entry);

  Future<int> updateProjectPartial(int id, ProjectsCompanion entry) =>
      (update(projects)..where((t) => t.id.equals(id))).write(entry);

  Future<int> deleteProject(int id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  // === Tasks ===

  Future<List<Task>> getAllTasks() => select(tasks).get();

  Future<List<Task>> getTasksByProjectId(int projectId) =>
      (select(tasks)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .get();

  Future<Task?> getTaskById(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTask(TasksCompanion entry) => into(tasks).insert(entry);

  Future<bool> updateTask(TasksCompanion entry) => update(tasks).replace(entry);

  Future<int> updateTaskPartial(int id, TasksCompanion entry) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(entry);

  Future<int> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<int> deleteTasksByProjectId(int projectId) =>
      (delete(tasks)..where((t) => t.projectId.equals(projectId))).go();

  Future<int> getCompletedTaskCount(int projectId) async {
    final query = select(
      tasks,
    )..where((t) => t.projectId.equals(projectId) & t.isCompleted.equals(true));
    final results = await query.get();
    return results.length;
  }

  Future<int> getTotalTaskCount(int projectId) async {
    final query = select(tasks)..where((t) => t.projectId.equals(projectId));
    final results = await query.get();
    return results.length;
  }

  Future<List<Task>> getAllIncompleteTasks() =>
      (select(tasks)
            ..where((t) => t.isCompleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .get();

  // === Inspirations AI Data ===

  Future<int> updateAiAnalysis(int id, String? aiAnalysis) => (update(
    inspirations,
  )..where((t) => t.id.equals(id))).write(
    InspirationsCompanion(
      aiAnalysis: aiAnalysis != null ? Value(aiAnalysis) : const Value.absent(),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ),
  );

  Future<int> updateMindMapData(int id, String? mindMapData) =>
      (update(inspirations)..where((t) => t.id.equals(id))).write(
        InspirationsCompanion(
          mindMapData:
              mindMapData != null ? Value(mindMapData) : const Value.absent(),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<int> clearAiAnalysis(int id) =>
      (update(inspirations)..where((t) => t.id.equals(id))).write(
        InspirationsCompanion(
          aiAnalysis: const Value(null),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<int> clearMindMapData(int id) =>
      (update(inspirations)..where((t) => t.id.equals(id))).write(
        InspirationsCompanion(
          mindMapData: const Value(null),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  // === Inspirations Review ===

  Future<int> markReviewed(int id) =>
      (update(inspirations)..where((t) => t.id.equals(id))).write(
        InspirationsCompanion(
          reviewedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<int> toggleNeedsFollowUp(int id, bool value) => (update(inspirations)
    ..where(
      (t) => t.id.equals(id),
    )).write(InspirationsCompanion(needsFollowUp: Value(value)));

  Future<List<Inspiration>> getRandomUnreviewed({int limit = 3}) async {
    final all =
        await (select(inspirations)
              ..where((t) => t.reviewedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    if (all.isEmpty) return [];
    all.shuffle();
    return all.take(limit).toList();
  }

  Future<List<Inspiration>> getInspirationsNeedingFollowUp() =>
      (select(inspirations)
            ..where((t) => t.needsFollowUp.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<List<Inspiration>> getInspirationsSince(int sinceEpoch) =>
      (select(inspirations)
            ..where((t) => t.createdAt.isBiggerOrEqualValue(sinceEpoch))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<int> getUnreviewedCount() async {
    final query = select(inspirations)..where((t) => t.reviewedAt.isNull());
    final results = await query.get();
    return results.length;
  }

  // === ChatMessages ===

  Future<List<ChatMessage>> getAllChatMessages() => select(chatMessages).get();

  Future<List<ChatMessage>> getChatMessagesByInspirationId(int inspirationId) =>
      (select(chatMessages)
            ..where((t) => t.inspirationId.equals(inspirationId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> insertChatMessage(ChatMessagesCompanion entry) =>
      into(chatMessages).insert(entry);

  Future<int> deleteChatMessagesByInspirationId(int inspirationId) =>
      (delete(chatMessages)
        ..where((t) => t.inspirationId.equals(inspirationId))).go();

  // === GlobalChatMessages ===

  Future<List<GlobalChatMessage>> getAllGlobalChatMessages() =>
      (select(globalChatMessages)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> insertGlobalChatMessage(
    GlobalChatMessagesCompanion entry,
  ) =>
      into(globalChatMessages).insert(entry);

  Future<int> deleteAllGlobalChatMessages() => delete(globalChatMessages).go();

  // === Attachments ===

  Future<List<Attachment>> getAllAttachments() => select(attachments).get();

  Future<List<Attachment>> getAttachmentsByOwner(
    String ownerType,
    int ownerId,
  ) =>
      (select(attachments)
            ..where(
              (t) => t.ownerType.equals(ownerType) & t.ownerId.equals(ownerId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<Attachment?> getAttachmentById(int id) =>
      (select(attachments)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertAttachment(AttachmentsCompanion entry) =>
      into(attachments).insert(entry);

  Future<int> deleteAttachment(int id) =>
      (delete(attachments)..where((t) => t.id.equals(id))).go();

  Future<int> deleteAttachmentsByOwner(String ownerType, int ownerId) =>
      (delete(attachments)..where(
        (t) => t.ownerType.equals(ownerType) & t.ownerId.equals(ownerId),
      )).go();

  // === InspirationLinks ===

  Future<List<InspirationLink>> getAllInspirationLinks() =>
      select(inspirationLinks).get();

  Future<List<InspirationLink>> getLinksBySourceId(int sourceId) =>
      (select(inspirationLinks)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.desc(t.confidence)]))
          .get();

  Future<List<InspirationLink>> getLinksByTargetId(int targetId) =>
      (select(inspirationLinks)
            ..where((t) => t.targetId.equals(targetId))
            ..orderBy([(t) => OrderingTerm.desc(t.confidence)]))
          .get();

  Future<List<InspirationLink>> getLinksForInspiration(int id) =>
      (select(inspirationLinks)
            ..where((t) => t.sourceId.equals(id) | t.targetId.equals(id))
            ..orderBy([(t) => OrderingTerm.desc(t.confidence)]))
          .get();

  Future<InspirationLink?> getLinkById(int id) =>
      (select(inspirationLinks)
        ..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertInspirationLink(InspirationLinksCompanion entry) =>
      into(inspirationLinks).insert(entry);

  Future<int> deleteInspirationLink(int id) =>
      (delete(inspirationLinks)..where((t) => t.id.equals(id))).go();

  Future<int> updateInspirationLink(int id, InspirationLinksCompanion entry) =>
      (update(inspirationLinks)..where((t) => t.id.equals(id))).write(entry);

  Future<int> deleteLinksForInspiration(int id) =>
      (delete(inspirationLinks)
        ..where((t) => t.sourceId.equals(id) | t.targetId.equals(id))).go();

  Future<bool> linkExists(int sourceId, int targetId) async {
    final query = select(inspirationLinks)..where(
      (t) =>
          (t.sourceId.equals(sourceId) & t.targetId.equals(targetId)) |
          (t.sourceId.equals(targetId) & t.targetId.equals(sourceId)),
    );
    final result = await query.getSingleOrNull();
    return result != null;
  }

  // === Clusters ===

  Future<List<Cluster>> getAllClusters() =>
      (select(clusters)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();

  Future<Cluster?> getClusterById(int id) =>
      (select(clusters)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertCluster(ClustersCompanion entry) =>
      into(clusters).insert(entry);

  Future<bool> updateCluster(ClustersCompanion entry) =>
      update(clusters).replace(entry);

  Future<int> deleteCluster(int id) =>
      (delete(clusters)..where((t) => t.id.equals(id))).go();

  // === Reports ===

  Future<List<Report>> getAllReports() => select(reports).get();

  Future<Report?> getLatestReportByType(String type) =>
      (select(reports)
            ..where((t) => t.type.equals(type))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertReport(ReportsCompanion entry) =>
      into(reports).insert(entry);

  Future<int> upsertLatestReport(
    String type,
    String content, {
    String model = '',
  }) async {
    final existing = await getLatestReportByType(type);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing == null) {
      return insertReport(
        ReportsCompanion.insert(
          type: type,
          content: content,
          model: Value(model),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return (update(reports)..where((t) => t.id.equals(existing.id))).write(
      ReportsCompanion(
        content: Value(content),
        model: Value(model),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> deleteAllReports() => delete(reports).go();

  // === DeletedRecords ===

  Future<List<DeletedRecord>> getAllDeletedRecords() =>
      select(deletedRecords).get();

  Future<int> markRecordDeleted(String entityType, int entityId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (delete(deletedRecords)..where(
      (t) => t.entityType.equals(entityType) & t.entityId.equals(entityId),
    )).go();
    return into(deletedRecords).insert(
      DeletedRecordsCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        deletedAt: now,
      ),
    );
  }

  Future<int> insertDeletedRecord(DeletedRecordsCompanion entry) =>
      into(deletedRecords).insert(entry);

  Future<int> deleteAllDeletedRecords() => delete(deletedRecords).go();
}
