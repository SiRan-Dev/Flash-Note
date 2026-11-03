import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';
import 'package:flashnote/data/services/snapshot_validator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 新客户端只读写这个文件；旧客户端只认 [kLegacySnapshotFileName]。
const String kSnapshotFileName = 'flashnote_sync_v7.json';
const String kLegacySnapshotFileName = 'flashnote_sync.json';

/// 快照导入的结果统计。
class SnapshotImportSummary {
  const SnapshotImportSummary({this.attachmentConflicts = 0});

  /// 同一 uuid 的附件在本地与快照中内容不同、且无法判断谁更新的数量。
  ///
  /// 冲突时本机文件被原样保留，快照里的内容另存为 `.conflict` 副本，
  /// 没有任何文件被静默覆盖。
  final int attachmentConflicts;
}

/// v7 快照的生成、旧版升级、合并与入库。
///
/// 快照不再携带本地自增 id，只带 `uuid`；关系字段全部用 uuid 表达。
/// 旧快照（v1-v6）在读取时先经过 [upgradeLegacySnapshot] 转换成 v7。
class SnapshotCodec {
  SnapshotCodec(this._db);

  final AppDatabase _db;

  /// 从本地数据库生成 v7 快照。
  Future<Map<String, dynamic>> exportSnapshot({
    required String deviceId,
    required bool includeAttachmentContent,
  }) async {
    final inspirations = await _db.getAllInspirations();
    final projects = await _db.getAllProjects();
    final tasks = await _db.getAllTasks();
    final sources = await _db.getAllSources();
    final allAttachments = await _db.getAllAttachments();
    final chatMessages = await _db.getAllChatMessages();
    final links = await _db.getAllInspirationLinks();
    final clusters = await _db.getAllClusters();
    final reports = await _db.getAllReports();
    final tombstones = await _db.getAllDeletedRecords();

    final inspirationUuidById = {
      for (final row in inspirations) row.id: row.uuid,
    };
    final projectUuidById = {for (final row in projects) row.id: row.uuid};

    // 旧墓碑只靠 entityId 兜底；导出时把能被旧 UUID 规则命中的记录重新标上
    // legacyId，保证经过一次本地库往返后删除仍然能传播。
    final legacyIdsByType = <String, List<int>>{};
    for (final tombstone in tombstones) {
      final entityId = tombstone.entityId;
      if (tombstone.legacy && entityId != null) {
        legacyIdsByType
            .putIfAbsent(tombstone.entityType, () => [])
            .add(entityId);
      }
    }

    int? legacyIdOf(String entityType, String uuid, int createdAt) {
      final ids = legacyIdsByType[entityType];
      if (ids == null) return null;
      for (final id in ids) {
        if (legacyRecordUuid(entityType, id, createdAt) == uuid) return id;
      }
      return null;
    }

    final attachments = <Map<String, dynamic>>[];
    for (final attachment in allAttachments) {
      final ownerUuid = attachment.ownerType == 'project'
          ? projectUuidById[attachment.ownerId]
          : inspirationUuidById[attachment.ownerId];
      // 关系指向已不存在的记录：丢弃附件行，但绝不删除磁盘文件。
      if (ownerUuid == null) continue;

      String? contentBase64;
      if (includeAttachmentContent && attachment.filePath.isNotEmpty) {
        final file = File(attachment.filePath);
        if (await file.exists()) {
          contentBase64 = base64Encode(await file.readAsBytes());
        }
      }

      attachments.add({
        'uuid': attachment.uuid,
        if (legacyIdOf('attachments', attachment.uuid, attachment.createdAt) !=
            null)
          'legacyId': legacyIdOf(
            'attachments',
            attachment.uuid,
            attachment.createdAt,
          ),
        'ownerType': attachment.ownerType,
        'ownerUuid': ownerUuid,
        'fileName': attachment.fileName,
        'filePath': attachment.filePath,
        'mimeType': attachment.mimeType,
        'size': attachment.size,
        'createdAt': attachment.createdAt,
        'contentBase64': contentBase64,
      });
    }

    final tasksOut = <Map<String, dynamic>>[];
    for (final task in tasks) {
      final projectUuid = projectUuidById[task.projectId];
      if (projectUuid == null) continue;
      tasksOut.add({
        'uuid': task.uuid,
        if (legacyIdOf('tasks', task.uuid, task.createdAt) != null)
          'legacyId': legacyIdOf('tasks', task.uuid, task.createdAt),
        'projectUuid': projectUuid,
        'title': task.title,
        'isCompleted': task.isCompleted,
        'isPinned': task.isPinned,
        'createdAt': task.createdAt,
        'updatedAt': task.updatedAt,
      });
    }

    final chatsOut = <Map<String, dynamic>>[];
    for (final message in chatMessages) {
      final inspirationUuid = inspirationUuidById[message.inspirationId];
      if (inspirationUuid == null) continue;
      chatsOut.add({
        'uuid': message.uuid,
        if (legacyIdOf('chatMessages', message.uuid, message.createdAt) != null)
          'legacyId': legacyIdOf(
            'chatMessages',
            message.uuid,
            message.createdAt,
          ),
        'inspirationUuid': inspirationUuid,
        'role': message.role,
        'content': message.content,
        'createdAt': message.createdAt,
      });
    }

    final linksOut = <Map<String, dynamic>>[];
    for (final link in links) {
      final sourceUuid = inspirationUuidById[link.sourceId];
      final targetUuid = inspirationUuidById[link.targetId];
      if (sourceUuid == null || targetUuid == null) continue;
      linksOut.add({
        'uuid': link.uuid,
        if (legacyIdOf('inspirationLinks', link.uuid, link.createdAt) != null)
          'legacyId': legacyIdOf('inspirationLinks', link.uuid, link.createdAt),
        'sourceUuid': sourceUuid,
        'targetUuid': targetUuid,
        'linkType': link.linkType,
        'relationLabel': link.relationLabel,
        'confidence': link.confidence,
        'isAutoGenerated': link.isAutoGenerated,
        'createdAt': link.createdAt,
      });
    }

    return {
      'version': kSnapshotVersion,
      'deviceId': deviceId,
      'exportedAt': DateTime.now().toIso8601String(),
      'inspirations': inspirations
          .map(
            (i) => {
              'uuid': i.uuid,
              if (legacyIdOf('inspirations', i.uuid, i.createdAt) != null)
                'legacyId': legacyIdOf('inspirations', i.uuid, i.createdAt),
              'content': i.content,
              'source': i.source,
              'tags': _parseTags(i.tags),
              'aiAnalysis': i.aiAnalysis,
              'mindMapData': i.mindMapData,
              'isPinned': i.isPinned,
              'reviewedAt': i.reviewedAt,
              'needsFollowUp': i.needsFollowUp,
              'createdAt': i.createdAt,
              'updatedAt': i.updatedAt,
            },
          )
          .toList(),
      'projects': projects
          .map(
            (p) => {
              'uuid': p.uuid,
              if (legacyIdOf('projects', p.uuid, p.createdAt) != null)
                'legacyId': legacyIdOf('projects', p.uuid, p.createdAt),
              'inspirationUuid': p.inspirationId == null
                  ? null
                  : inspirationUuidById[p.inspirationId],
              'title': p.title,
              'description': p.description,
              'progress': p.progress,
              'status': p.status,
              'isPinned': p.isPinned,
              'createdAt': p.createdAt,
              'updatedAt': p.updatedAt,
            },
          )
          .toList(),
      'tasks': tasksOut,
      'customSources': sources
          .map(
            (s) => {
              'uuid': s.uuid,
              if (legacyIdOf('customSources', s.uuid, s.createdAt) != null)
                'legacyId': legacyIdOf('customSources', s.uuid, s.createdAt),
              'name': s.name,
              'icon': s.icon,
              'sortOrder': s.sortOrder,
              'isBuiltIn': s.isBuiltIn,
              'createdAt': s.createdAt,
            },
          )
          .toList(),
      'attachments': attachments,
      'chatMessages': chatsOut,
      'inspirationLinks': linksOut,
      'clusters': clusters
          .map(
            (c) => {
              'uuid': c.uuid,
              if (legacyIdOf('clusters', c.uuid, c.createdAt) != null)
                'legacyId': legacyIdOf('clusters', c.uuid, c.createdAt),
              'name': c.name,
              'description': c.description,
              'createdAt': c.createdAt,
              'updatedAt': c.updatedAt,
            },
          )
          .toList(),
      'reports': reports
          .map(
            (r) => {
              'uuid': r.uuid,
              if (legacyIdOf('reports', r.uuid, r.createdAt) != null)
                'legacyId': legacyIdOf('reports', r.uuid, r.createdAt),
              'type': r.type,
              'content': r.content,
              'model': r.model,
              'createdAt': r.createdAt,
              'updatedAt': r.updatedAt,
            },
          )
          .toList(),
      'deletedRecords': tombstones
          .map(
            (d) => {
              'entityType': d.entityType,
              'entityUuid': d.entityUuid,
              'deletedAt': d.deletedAt,
              'legacy': d.legacy,
              if (d.legacy && d.entityId != null) 'entityId': d.entityId,
            },
          )
          .toList(),
    };
  }

  /// 把 v1-v6 快照转换成 v7。
  ///
  /// uuid 选择顺序：
  /// 1. 本地同表、同 id、同 createdAt 的行 → 复用它的 uuid（两设备已有同一份
  ///    数据的场景）；
  /// 2. 内置来源按 name、Reports 按 type 的确定性 UUID（避免同一份数据在
  ///    不同设备上被拆成两条）；
  /// 3. 其余用 `legacy:{type}:{id}:{createdAt}` 的确定性 v5。
  ///
  /// 旧 id 会写入 `legacyId`，关系字段用本次转换的 id→uuid 映射改写。
  /// 同一份旧快照转换两次得到完全一致的结果（包括 exportedAt）。
  Future<Map<String, dynamic>> upgradeLegacySnapshot(
    Map<String, dynamic> data, {
    required String deviceId,
  }) async {
    final version = data['version'] as int? ?? 1;
    if (version >= kSnapshotVersion) return data;

    final localInspirations = {
      for (final row in await _db.getAllInspirations()) row.id: row,
    };
    final localProjects = {
      for (final row in await _db.getAllProjects()) row.id: row,
    };
    final localTasks = {for (final row in await _db.getAllTasks()) row.id: row};
    final localSources = {
      for (final row in await _db.getAllSources()) row.id: row,
    };
    final localAttachments = {
      for (final row in await _db.getAllAttachments()) row.id: row,
    };
    final localChats = {
      for (final row in await _db.getAllChatMessages()) row.id: row,
    };
    final localLinks = {
      for (final row in await _db.getAllInspirationLinks()) row.id: row,
    };
    final localClusters = {
      for (final row in await _db.getAllClusters()) row.id: row,
    };
    final localReports = {
      for (final row in await _db.getAllReports()) row.id: row,
    };

    final inspirationIdToUuid = <int, String>{};
    final inspirations = <Map<String, dynamic>>[];
    for (final item in _listOf(data['inspirations'])) {
      final id = item['id'] as int;
      final createdAt = item['createdAt'] as int;
      final local = localInspirations[id];
      final uuid = local != null && local.createdAt == createdAt
          ? local.uuid
          : legacyRecordUuid('inspirations', id, createdAt);
      inspirationIdToUuid[id] = uuid;
      inspirations.add({
        'uuid': uuid,
        'legacyId': id,
        'content': item['content'],
        'source': item['source'],
        'tags': item['tags'],
        'aiAnalysis': item['aiAnalysis'],
        'mindMapData': item['mindMapData'],
        'isPinned': item['isPinned'] as bool? ?? false,
        'reviewedAt': item['reviewedAt'],
        'needsFollowUp': item['needsFollowUp'] as bool? ?? false,
        'createdAt': createdAt,
        'updatedAt': item['updatedAt'] as int? ?? createdAt,
      });
    }

    final projectIdToUuid = <int, String>{};
    final projects = <Map<String, dynamic>>[];
    for (final item in _listOf(data['projects'])) {
      final id = item['id'] as int;
      final createdAt = item['createdAt'] as int;
      final local = localProjects[id];
      final uuid = local != null && local.createdAt == createdAt
          ? local.uuid
          : legacyRecordUuid('projects', id, createdAt);
      projectIdToUuid[id] = uuid;
      projects.add({
        'uuid': uuid,
        'legacyId': id,
        'inspirationUuid': item['inspirationId'] == null
            ? null
            : inspirationIdToUuid[item['inspirationId'] as int],
        'title': item['title'],
        'description': item['description'] as String? ?? '',
        'progress': item['progress'] as int? ?? 0,
        'status': item['status'] as String? ?? 'active',
        'isPinned': item['isPinned'] as bool? ?? false,
        'createdAt': createdAt,
        'updatedAt': item['updatedAt'] as int? ?? createdAt,
      });
    }

    final taskIdToUuid = <int, String>{};
    final tasks = <Map<String, dynamic>>[];
    for (final item in _listOf(data['tasks'])) {
      final id = item['id'] as int;
      final createdAt = item['createdAt'] as int;
      final projectUuid = projectIdToUuid[item['projectId'] as int];
      if (projectUuid == null) continue;
      final local = localTasks[id];
      final uuid = local != null && local.createdAt == createdAt
          ? local.uuid
          : legacyRecordUuid('tasks', id, createdAt);
      taskIdToUuid[id] = uuid;
      tasks.add({
        'uuid': uuid,
        'legacyId': id,
        'projectUuid': projectUuid,
        'title': item['title'],
        'isCompleted': item['isCompleted'] as bool? ?? false,
        'isPinned': item['isPinned'] as bool? ?? false,
        'createdAt': createdAt,
        'updatedAt': item['updatedAt'] as int? ?? createdAt,
      });
    }

    final sourceIdToUuid = <int, String>{};
    final sources = <Map<String, dynamic>>[];
    final usedBuiltInNames = <String>{};
    for (final item in _listOf(data['customSources'])) {
      final id = item['id'] as int;
      final createdAt = item['createdAt'] as int;
      final name = item['name'] as String;
      final isBuiltIn = item['isBuiltIn'] as bool? ?? false;
      final local = localSources[id];

      String uuid;
      if (local != null && local.createdAt == createdAt) {
        uuid = local.uuid;
        if (isBuiltIn) usedBuiltInNames.add(name);
      } else if (isBuiltIn) {
        final firstOfName = usedBuiltInNames.add(name);
        uuid = deterministicBuiltInSourceUuid(
          name,
          discriminator: firstOfName ? null : id,
        );
      } else {
        uuid = legacyRecordUuid('customSources', id, createdAt);
      }

      sourceIdToUuid[id] = uuid;
      sources.add({
        'uuid': uuid,
        'legacyId': id,
        'name': name,
        'icon': item['icon'],
        'sortOrder': item['sortOrder'] as int? ?? 0,
        'isBuiltIn': isBuiltIn,
        'createdAt': createdAt,
      });
    }

    final attachmentIdToUuid = <int, String>{};
    final attachments = <Map<String, dynamic>>[];
    for (final item in _listOf(data['attachments'])) {
      final id = item['id'] as int;
      final createdAt = item['createdAt'] as int;
      final ownerType = item['ownerType'] as String;
      final ownerUuid = ownerType == 'project'
          ? projectIdToUuid[item['ownerId'] as int]
          : inspirationIdToUuid[item['ownerId'] as int];
      // 关系指向不存在的记录：附件行丢弃，磁盘文件不受影响。
      if (ownerUuid == null) continue;
      final local = localAttachments[id];
      final uuid = local != null && local.createdAt == createdAt
          ? local.uuid
          : legacyRecordUuid('attachments', id, createdAt);
      attachmentIdToUuid[id] = uuid;
      attachments.add({
        'uuid': uuid,
        'legacyId': id,
        'ownerType': ownerType,
        'ownerUuid': ownerUuid,
        'fileName': item['fileName'],
        'filePath': item['filePath'],
        'mimeType': item['mimeType'],
        'size': item['size'] as int? ?? 0,
        'createdAt': createdAt,
        'contentBase64': item['contentBase64'],
      });
    }

    final chatIdToUuid = <int, String>{};
    final chats = <Map<String, dynamic>>[];
    for (final item in _listOf(data['chatMessages'])) {
      final id = item['id'] as int;
      final createdAt = item['createdAt'] as int;
      final inspirationUuid = inspirationIdToUuid[item['inspirationId'] as int];
      if (inspirationUuid == null) continue;
      final local = localChats[id];
      final uuid = local != null && local.createdAt == createdAt
          ? local.uuid
          : legacyRecordUuid('chatMessages', id, createdAt);
      chatIdToUuid[id] = uuid;
      chats.add({
        'uuid': uuid,
        'legacyId': id,
        'inspirationUuid': inspirationUuid,
        'role': item['role'],
        'content': item['content'],
        'createdAt': createdAt,
      });
    }

    final links = <Map<String, dynamic>>[];
    for (final item in _listOf(data['inspirationLinks'])) {
      final id = item['id'] as int;
      final createdAt = item['createdAt'] as int;
      final sourceUuid = inspirationIdToUuid[item['sourceId'] as int];
      final targetUuid = inspirationIdToUuid[item['targetId'] as int];
      if (sourceUuid == null || targetUuid == null) continue;
      final local = localLinks[id];
      final uuid = local != null && local.createdAt == createdAt
          ? local.uuid
          : legacyRecordUuid('inspirationLinks', id, createdAt);
      links.add({
        'uuid': uuid,
        'legacyId': id,
        'sourceUuid': sourceUuid,
        'targetUuid': targetUuid,
        'linkType': item['linkType'],
        'relationLabel': item['relationLabel'],
        'confidence': item['confidence'] as num? ?? 0.5,
        'isAutoGenerated': item['isAutoGenerated'] as bool? ?? false,
        'createdAt': createdAt,
      });
    }

    final clusters = <Map<String, dynamic>>[];
    for (final item in _listOf(data['clusters'])) {
      final id = item['id'] as int;
      final createdAt = item['createdAt'] as int;
      final local = localClusters[id];
      final uuid = local != null && local.createdAt == createdAt
          ? local.uuid
          : legacyRecordUuid('clusters', id, createdAt);
      clusters.add({
        'uuid': uuid,
        'legacyId': id,
        'name': item['name'],
        'description': item['description'] as String? ?? '',
        'createdAt': createdAt,
        'updatedAt': item['updatedAt'] as int? ?? createdAt,
      });
    }

    final reportIdToUuid = <int, String>{};
    final reports = <Map<String, dynamic>>[];
    final usedReportTypes = <String>{};
    for (final item in _listOf(data['reports'])) {
      final id = item['id'] as int;
      final createdAt = item['createdAt'] as int;
      final type = item['type'] as String;
      final local = localReports[id];
      final firstOfType = usedReportTypes.add(type);

      String uuid;
      if (local != null && local.createdAt == createdAt) {
        uuid = local.uuid;
      } else {
        uuid = deterministicReportUuid(
          type,
          discriminator: firstOfType ? null : id,
        );
      }

      reportIdToUuid[id] = uuid;
      reports.add({
        'uuid': uuid,
        'legacyId': id,
        'type': type,
        'content': item['content'],
        'model': item['model'] as String? ?? '',
        'createdAt': createdAt,
        'updatedAt': item['updatedAt'] as int? ?? createdAt,
      });
    }

    final tombstones = <Map<String, dynamic>>[];
    for (final item in _listOf(data['deletedRecords'])) {
      final entityType = item['entityType'] as String;
      final entityId = item['entityId'] as int;
      tombstones.add({
        'entityType': entityType,
        'entityUuid': legacyTombstoneUuid(entityType, entityId),
        'deletedAt': item['deletedAt'],
        'legacy': true,
        'entityId': entityId,
      });
    }

    final upgraded = <String, dynamic>{
      'version': kSnapshotVersion,
      'deviceId': deviceId,
      if (data['exportedAt'] != null) 'exportedAt': data['exportedAt'],
      'inspirations': inspirations,
      'projects': projects,
      'tasks': tasks,
      'customSources': sources,
      'attachments': attachments,
      'chatMessages': chats,
      'inspirationLinks': links,
      'clusters': clusters,
      'reports': reports,
      'deletedRecords': tombstones,
    };
    for (final key in ['aiSettings', 'webdavSettings', 'graphLayouts']) {
      if (data.containsKey(key)) upgraded[key] = data[key];
    }
    return upgraded;
  }

  /// 把 v7 快照写回本地库。
  ///
  /// - 不用快照里的 id；按 uuid 匹配本地行，能复用本地 id 就复用；
  /// - 关系字段通过本次导入建立的 uuid→本地 id 映射还原；
  /// - 快照中没有的本地行会被删除（覆盖语义）；附件只删行，不删磁盘文件；
  /// - 附件行存在但本机缺物理文件、且快照带内容时，按 uuid 落盘恢复。
  ///
  /// [preserveConflictingAttachments] 为 true 时（合并同步），同一 uuid 的
  /// 附件内容与快照不一致且无法判断谁更新：保留本机文件、把快照内容另存为
  /// `.conflict` 副本并计入 [SnapshotImportSummary.attachmentConflicts]，
  /// 绝不静默挑选一侧。为 false 时（拉取 / 文件导入这类明确的覆盖语义），
  /// 用快照内容覆盖本机文件。
  Future<SnapshotImportSummary> importSnapshot(
    Map<String, dynamic> data, {
    bool preserveConflictingAttachments = false,
  }) async {
    var attachmentConflicts = 0;
    final inspirations = _listOf(data['inspirations']);
    final projects = _listOf(data['projects']);
    final tasks = _listOf(data['tasks']);
    final sources = _listOf(data['customSources']);
    final attachments = _listOf(data['attachments']);
    final chats = _listOf(data['chatMessages']);
    final links = _listOf(data['inspirationLinks']);
    final clusters = _listOf(data['clusters']);
    final reports = _listOf(data['reports']);
    final tombstones = _listOf(data['deletedRecords']);

    final inspirationIdByUuid = <String, int>{};
    final existingInspirations = {
      for (final row in await _db.getAllInspirations()) row.uuid: row,
    };
    for (final item in inspirations) {
      final uuid = item['uuid'] as String;
      final tags = item['tags'];
      final tagsJson = tags is List
          ? jsonEncode(tags)
          : (tags as String? ?? '[]');
      final companion = InspirationsCompanion(
        content: Value(item['content'] as String),
        source: Value(item['source'] as String?),
        tags: Value(tagsJson),
        aiAnalysis: Value(item['aiAnalysis'] as String?),
        mindMapData: Value(item['mindMapData'] as String?),
        isPinned: Value(item['isPinned'] as bool? ?? false),
        createdAt: Value(item['createdAt'] as int),
        updatedAt: Value(item['updatedAt'] as int),
        reviewedAt: Value(item['reviewedAt'] as int?),
        needsFollowUp: Value(item['needsFollowUp'] as bool? ?? false),
        uuid: Value(uuid),
      );

      final existing = existingInspirations[uuid];
      if (existing != null) {
        await _db.updateInspirationPartial(existing.id, companion);
        inspirationIdByUuid[uuid] = existing.id;
      } else {
        inspirationIdByUuid[uuid] = await _db.insertInspiration(companion);
      }
    }

    final projectIdByUuid = <String, int>{};
    final existingProjects = {
      for (final row in await _db.getAllProjects()) row.uuid: row,
    };
    for (final item in projects) {
      final uuid = item['uuid'] as String;
      final inspirationUuid = item['inspirationUuid'] as String?;
      final companion = ProjectsCompanion(
        inspirationId: Value<int?>(
          inspirationUuid == null ? null : inspirationIdByUuid[inspirationUuid],
        ),
        title: Value(item['title'] as String),
        description: Value(item['description'] as String? ?? ''),
        progress: Value(item['progress'] as int? ?? 0),
        status: Value(item['status'] as String? ?? 'active'),
        isPinned: Value(item['isPinned'] as bool? ?? false),
        createdAt: Value(item['createdAt'] as int),
        updatedAt: Value(item['updatedAt'] as int),
        uuid: Value(uuid),
      );

      final existing = existingProjects[uuid];
      if (existing != null) {
        await _db.updateProjectPartial(existing.id, companion);
        projectIdByUuid[uuid] = existing.id;
      } else {
        projectIdByUuid[uuid] = await _db.insertProject(companion);
      }
    }

    final existingSources = {
      for (final row in await _db.getAllSources()) row.uuid: row,
    };
    for (final item in sources) {
      final uuid = item['uuid'] as String;
      final companion = CustomSourcesCompanion(
        name: Value(item['name'] as String),
        icon: Value(item['icon'] as String),
        sortOrder: Value(item['sortOrder'] as int? ?? 0),
        isBuiltIn: Value(item['isBuiltIn'] as bool? ?? false),
        createdAt: Value(item['createdAt'] as int),
        uuid: Value(uuid),
      );
      final existing = existingSources[uuid];
      if (existing != null) {
        await _db.updateSourcePartial(existing.id, companion);
      } else {
        await _db.insertSource(companion);
      }
    }

    final existingTasks = {
      for (final row in await _db.getAllTasks()) row.uuid: row,
    };
    for (final item in tasks) {
      final uuid = item['uuid'] as String;
      final projectId = projectIdByUuid[item['projectUuid'] as String];
      // 关系指向不存在的记录：丢弃孤儿行。
      if (projectId == null) continue;
      final companion = TasksCompanion(
        projectId: Value(projectId),
        title: Value(item['title'] as String),
        isCompleted: Value(item['isCompleted'] as bool? ?? false),
        isPinned: Value(item['isPinned'] as bool? ?? false),
        createdAt: Value(item['createdAt'] as int),
        updatedAt: Value(item['updatedAt'] as int),
        uuid: Value(uuid),
      );
      final existing = existingTasks[uuid];
      if (existing != null) {
        await _db.updateTaskPartial(existing.id, companion);
      } else {
        await _db.insertTask(companion);
      }
    }

    final existingAttachments = {
      for (final row in await _db.getAllAttachments()) row.uuid: row,
    };
    for (final item in attachments) {
      final uuid = item['uuid'] as String;
      final ownerType = item['ownerType'] as String;
      final ownerUuid = item['ownerUuid'] as String;
      final ownerId = ownerType == 'project'
          ? projectIdByUuid[ownerUuid]
          : inspirationIdByUuid[ownerUuid];
      if (ownerId == null) continue;

      final existing = existingAttachments[uuid];
      final contentBase64 = item['contentBase64'] as String?;
      String filePath;
      if (contentBase64 != null && contentBase64.isNotEmpty) {
        final remoteBytes = base64Decode(contentBase64);
        final localPath = existing?.filePath ?? '';
        final localFile = localPath.isEmpty ? null : File(localPath);
        final localExists = localFile != null && await localFile.exists();

        if (!localExists) {
          // 本机缺物理文件（新行，或“有行没文件”）：按 uuid 落盘恢复。
          filePath = await _restoreAttachmentFile(
            item,
            uuid: uuid,
            bytes: remoteBytes,
          );
        } else if (_sameBytes(await localFile.readAsBytes(), remoteBytes)) {
          // 内容一致：直接复用本机文件，避免每次同步重复写盘。
          filePath = localPath;
        } else if (preserveConflictingAttachments) {
          // 两端内容不同且附件没有可靠的更新时间，无法判断谁更新：
          // 保留本机文件，把快照内容另存副本，交给用户在结果里看到冲突。
          await _writeConflictCopy(item, uuid: uuid, bytes: remoteBytes);
          attachmentConflicts++;
          filePath = localPath;
        } else {
          filePath = await _restoreAttachmentFile(
            item,
            uuid: uuid,
            bytes: remoteBytes,
          );
        }
      } else {
        filePath = existing?.filePath ?? (item['filePath'] as String? ?? '');
      }

      final companion = AttachmentsCompanion(
        ownerType: Value(ownerType),
        ownerId: Value(ownerId),
        fileName: Value(item['fileName'] as String),
        filePath: Value(filePath),
        mimeType: Value(item['mimeType'] as String),
        size: Value(item['size'] as int? ?? 0),
        createdAt: Value(item['createdAt'] as int),
        uuid: Value(uuid),
      );
      if (existing != null) {
        await (_db.update(
          _db.attachments,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      } else {
        await _db.insertAttachment(companion);
      }
    }

    final existingChats = {
      for (final row in await _db.getAllChatMessages()) row.uuid: row,
    };
    for (final item in chats) {
      final uuid = item['uuid'] as String;
      final inspirationId =
          inspirationIdByUuid[item['inspirationUuid'] as String];
      if (inspirationId == null) continue;
      final companion = ChatMessagesCompanion(
        inspirationId: Value(inspirationId),
        role: Value(item['role'] as String),
        content: Value(item['content'] as String),
        createdAt: Value(item['createdAt'] as int),
        uuid: Value(uuid),
      );
      final existing = existingChats[uuid];
      if (existing != null) {
        await (_db.update(
          _db.chatMessages,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      } else {
        await _db.insertChatMessage(companion);
      }
    }

    final existingLinks = {
      for (final row in await _db.getAllInspirationLinks()) row.uuid: row,
    };
    for (final item in links) {
      final uuid = item['uuid'] as String;
      final sourceId = inspirationIdByUuid[item['sourceUuid'] as String];
      final targetId = inspirationIdByUuid[item['targetUuid'] as String];
      if (sourceId == null || targetId == null) continue;
      final companion = InspirationLinksCompanion(
        sourceId: Value(sourceId),
        targetId: Value(targetId),
        linkType: Value(item['linkType'] as String),
        relationLabel: Value(item['relationLabel'] as String?),
        confidence: Value((item['confidence'] as num?)?.toDouble() ?? 0.5),
        isAutoGenerated: Value(item['isAutoGenerated'] as bool? ?? false),
        createdAt: Value(item['createdAt'] as int),
        uuid: Value(uuid),
      );
      final existing = existingLinks[uuid];
      if (existing != null) {
        await _db.updateInspirationLink(existing.id, companion);
      } else {
        await _db.insertInspirationLink(companion);
      }
    }

    final existingClusters = {
      for (final row in await _db.getAllClusters()) row.uuid: row,
    };
    for (final item in clusters) {
      final uuid = item['uuid'] as String;
      final companion = ClustersCompanion(
        name: Value(item['name'] as String),
        description: Value(item['description'] as String? ?? ''),
        createdAt: Value(item['createdAt'] as int),
        updatedAt: Value(item['updatedAt'] as int),
        uuid: Value(uuid),
      );
      final existing = existingClusters[uuid];
      if (existing != null) {
        await (_db.update(
          _db.clusters,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      } else {
        await _db.insertCluster(companion);
      }
    }

    final existingReports = {
      for (final row in await _db.getAllReports()) row.uuid: row,
    };
    for (final item in reports) {
      final uuid = item['uuid'] as String;
      final companion = ReportsCompanion(
        type: Value(item['type'] as String),
        content: Value(item['content'] as String),
        model: Value(item['model'] as String? ?? ''),
        createdAt: Value(item['createdAt'] as int),
        updatedAt: Value(item['updatedAt'] as int),
        uuid: Value(uuid),
      );
      final existing = existingReports[uuid];
      if (existing != null) {
        await (_db.update(
          _db.reports,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      } else {
        await _db.insertReport(companion);
      }
    }

    await _db.deleteAllDeletedRecords();
    for (final item in tombstones) {
      await _db.insertDeletedRecord(
        DeletedRecordsCompanion.insert(
          entityType: item['entityType'] as String,
          entityUuid: Value(item['entityUuid'] as String),
          entityId: Value<int?>(item['entityId'] as int?),
          deletedAt: item['deletedAt'] as int,
          legacy: Value(item['legacy'] as bool? ?? false),
        ),
      );
    }

    await _deleteRowsMissingFromSnapshot(
      inspirations: inspirations,
      projects: projects,
      tasks: tasks,
      sources: sources,
      attachments: attachments,
      chats: chats,
      links: links,
      clusters: clusters,
      reports: reports,
    );

    return SnapshotImportSummary(attachmentConflicts: attachmentConflicts);
  }

  Future<void> _deleteRowsMissingFromSnapshot({
    required List<Map<String, dynamic>> inspirations,
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> sources,
    required List<Map<String, dynamic>> attachments,
    required List<Map<String, dynamic>> chats,
    required List<Map<String, dynamic>> links,
    required List<Map<String, dynamic>> clusters,
    required List<Map<String, dynamic>> reports,
  }) async {
    final keepInspirations = {
      for (final i in inspirations) i['uuid'] as String,
    };
    for (final row in await _db.getAllInspirations()) {
      if (!keepInspirations.contains(row.uuid)) {
        await _db.deleteInspiration(row.id);
      }
    }

    final keepProjects = {for (final i in projects) i['uuid'] as String};
    for (final row in await _db.getAllProjects()) {
      if (!keepProjects.contains(row.uuid)) {
        await _db.deleteProject(row.id);
      }
    }

    final keepSources = {for (final i in sources) i['uuid'] as String};
    for (final row in await _db.getAllSources()) {
      if (!keepSources.contains(row.uuid)) {
        await _db.deleteSource(row.id);
      }
    }

    final keepTasks = {for (final i in tasks) i['uuid'] as String};
    for (final row in await _db.getAllTasks()) {
      if (!keepTasks.contains(row.uuid)) {
        await _db.deleteTask(row.id);
      }
    }

    final keepAttachments = {for (final i in attachments) i['uuid'] as String};
    for (final row in await _db.getAllAttachments()) {
      if (!keepAttachments.contains(row.uuid)) {
        await _db.deleteAttachment(row.id);
      }
    }

    final keepChats = {for (final i in chats) i['uuid'] as String};
    for (final row in await _db.getAllChatMessages()) {
      if (!keepChats.contains(row.uuid)) {
        await (_db.delete(
          _db.chatMessages,
        )..where((t) => t.id.equals(row.id))).go();
      }
    }

    final keepLinks = {for (final i in links) i['uuid'] as String};
    for (final row in await _db.getAllInspirationLinks()) {
      if (!keepLinks.contains(row.uuid)) {
        await _db.deleteInspirationLink(row.id);
      }
    }

    final keepClusters = {for (final i in clusters) i['uuid'] as String};
    for (final row in await _db.getAllClusters()) {
      if (!keepClusters.contains(row.uuid)) {
        await _db.deleteCluster(row.id);
      }
    }

    final keepReports = {for (final i in reports) i['uuid'] as String};
    for (final row in await _db.getAllReports()) {
      if (!keepReports.contains(row.uuid)) {
        await (_db.delete(_db.reports)..where((t) => t.id.equals(row.id))).go();
      }
    }
  }

  /// 按 uuid 命名落盘，避免按本地自增 id 命名在同步后产生重复文件。
  Future<String> _restoreAttachmentFile(
    Map<String, dynamic> attachment, {
    required String uuid,
    required List<int> bytes,
  }) async {
    final restoredPath = await _attachmentPathFor(attachment, uuid: uuid);
    await File(restoredPath).writeAsBytes(bytes);
    return restoredPath;
  }

  /// 冲突副本与正件同名（同 uuid），只加 `.conflict` 后缀，重复同步时幂等。
  Future<void> _writeConflictCopy(
    Map<String, dynamic> attachment, {
    required String uuid,
    required List<int> bytes,
  }) async {
    final conflictPath =
        '${await _attachmentPathFor(attachment, uuid: uuid)}.conflict';
    await File(conflictPath).writeAsBytes(bytes);
  }

  Future<String> _attachmentPathFor(
    Map<String, dynamic> attachment, {
    required String uuid,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(appDir.path, 'attachments'));
    await attachmentsDir.create(recursive: true);
    final fileName = attachment['fileName'] as String? ?? 'attachment';
    final createdAt = attachment['createdAt'] as int? ?? 0;
    final safeName = p.basename(fileName);
    return p.join(attachmentsDir.path, '${createdAt}_${uuid}_$safeName');
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<dynamic> _parseTags(String tagsJson) {
  try {
    return jsonDecode(tagsJson) as List;
  } catch (_) {
    return const [];
  }
}

List<Map<String, dynamic>> _listOf(Object? value) {
  if (value is! List) return const [];
  return value.cast<Map<String, dynamic>>();
}

int _recency(Map<String, dynamic> item) {
  return item['updatedAt'] as int? ??
      item['createdAt'] as int? ??
      item['deletedAt'] as int? ??
      0;
}

/// 合并两份已经是 v7 的快照。
///
/// - 按 uuid 分组；updatedAt（缺失时用 createdAt）大的赢；
/// - 时间相同用快照顶层 deviceId 的字典序裁决，保证两端结果一致；
/// - 墓碑按 (entityType, entityUuid) 取最大 deletedAt；
/// - 最后清理指向不存在 uuid 的孤儿关系与记录。
Map<String, dynamic> mergeSnapshots(
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  final localDevice = local['deviceId'] as String? ?? '';
  final remoteDevice = remote['deviceId'] as String? ?? '';
  final tombstones = _mergeTombstones(local, remote);

  Map<String, dynamic> mergeList(String key) {
    final localList = _listOf(local[key]);
    final remoteList = _listOf(remote[key]);
    final merged = <String, Map<String, dynamic>>{};

    for (final item in localList) {
      final uuid = item['uuid'];
      if (uuid is String) merged[uuid] = item;
    }

    for (final item in remoteList) {
      final uuid = item['uuid'];
      if (uuid is! String) continue;
      final existing = merged[uuid];
      if (existing == null) {
        merged[uuid] = item;
        continue;
      }
      final localTime = _recency(existing);
      final remoteTime = _recency(item);
      if (remoteTime > localTime) {
        merged[uuid] = item;
      } else if (remoteTime == localTime) {
        if (remoteDevice.compareTo(localDevice) > 0) {
          merged[uuid] = item;
        } else if (remoteDevice == localDevice) {
          // 没有可用的设备身份时，用内容序列化做确定性裁决。
          if (jsonEncode(item).compareTo(jsonEncode(existing)) > 0) {
            merged[uuid] = item;
          }
        }
      }
    }

    final kept = <Map<String, dynamic>>[];
    for (final entry in merged.entries) {
      if (!_isDeleted(key, entry.key, entry.value, tombstones)) {
        kept.add(entry.value);
      }
    }
    return {'items': kept};
  }

  final mergedLists = <String, List<Map<String, dynamic>>>{};
  for (final key in [
    'inspirations',
    'projects',
    'tasks',
    'customSources',
    'attachments',
    'chatMessages',
    'inspirationLinks',
    'clusters',
    'reports',
  ]) {
    mergedLists[key] = mergeList(key)['items'] as List<Map<String, dynamic>>;
  }

  final mergedDeviceId = localDevice.compareTo(remoteDevice) >= 0
      ? localDevice
      : remoteDevice;
  final merged = <String, dynamic>{
    'version': kSnapshotVersion,
    'deviceId': mergedDeviceId,
    'exportedAt': _mergedExportedAt(local['exportedAt'], remote['exportedAt']),
    ...mergedLists,
    'deletedRecords': [for (final t in tombstones.values) _tombstoneJson(t)],
  };
  if (local['aiSettings'] != null || remote['aiSettings'] != null) {
    merged['aiSettings'] = _mergeAiSettings(
      local['aiSettings'] as Map<String, dynamic>?,
      remote['aiSettings'] as Map<String, dynamic>?,
    );
  }
  if (local['webdavSettings'] != null) {
    merged['webdavSettings'] = local['webdavSettings'];
  }
  if (local['graphLayouts'] != null) {
    merged['graphLayouts'] = local['graphLayouts'];
  }

  _cleanRelations(merged);
  return merged;
}

String _mergedExportedAt(Object? local, Object? remote) {
  final localValue = local is String ? local : '';
  final remoteValue = remote is String ? remote : '';
  if (localValue.isEmpty && remoteValue.isEmpty) {
    return DateTime.now().toIso8601String();
  }
  return localValue.compareTo(remoteValue) >= 0 ? localValue : remoteValue;
}

class _Tombstone {
  _Tombstone({
    required this.entityType,
    required this.entityUuid,
    required this.deletedAt,
    required this.legacy,
    required this.entityId,
  });

  final String entityType;
  final String entityUuid;
  final int deletedAt;
  final bool legacy;
  final int? entityId;
}

Map<String, _Tombstone> _mergeTombstones(
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  final merged = <String, _Tombstone>{};
  for (final item in [
    ..._listOf(local['deletedRecords']),
    ..._listOf(remote['deletedRecords']),
  ]) {
    final entityType = item['entityType'];
    final entityUuid = item['entityUuid'];
    final deletedAt = item['deletedAt'];
    if (entityType is! String || entityUuid is! String || deletedAt is! int) {
      continue;
    }
    final legacy = item['legacy'] as bool? ?? false;
    final entityId = item['entityId'] as int?;
    final key = '$entityType:$entityUuid';
    final existing = merged[key];
    if (existing == null ||
        deletedAt > existing.deletedAt ||
        (deletedAt == existing.deletedAt && existing.legacy && !legacy)) {
      merged[key] = _Tombstone(
        entityType: entityType,
        entityUuid: entityUuid,
        deletedAt: deletedAt,
        legacy: legacy,
        entityId: entityId,
      );
    }
  }
  return merged;
}

Map<String, dynamic> _tombstoneJson(_Tombstone tombstone) {
  return {
    'entityType': tombstone.entityType,
    'entityUuid': tombstone.entityUuid,
    'deletedAt': tombstone.deletedAt,
    'legacy': tombstone.legacy,
    if (tombstone.legacy && tombstone.entityId != null)
      'entityId': tombstone.entityId,
  };
}

bool _isDeleted(
  String entityType,
  String uuid,
  Map<String, dynamic> record,
  Map<String, _Tombstone> tombstones,
) {
  final time = _recency(record);
  final direct = tombstones['$entityType:$uuid'];
  if (direct != null && time <= direct.deletedAt) return true;

  final legacyId = record['legacyId'] as int?;
  if (legacyId == null) return false;
  for (final tombstone in tombstones.values) {
    if (tombstone.entityType != entityType || !tombstone.legacy) continue;
    if (tombstone.entityId == legacyId && time <= tombstone.deletedAt) {
      return true;
    }
  }
  return false;
}

void _cleanRelations(Map<String, dynamic> snapshot) {
  final inspirationUuids = {
    for (final item in _listOf(snapshot['inspirations']))
      item['uuid'] as String,
  };
  final projectUuids = {
    for (final item in _listOf(snapshot['projects'])) item['uuid'] as String,
  };

  for (final project in _listOf(snapshot['projects'])) {
    final target = project['inspirationUuid'];
    if (target is String && !inspirationUuids.contains(target)) {
      project['inspirationUuid'] = null;
    }
  }

  snapshot['tasks'] = [
    for (final task in _listOf(snapshot['tasks']))
      if (projectUuids.contains(task['projectUuid'])) task,
  ];

  snapshot['attachments'] = [
    for (final attachment in _listOf(snapshot['attachments']))
      if (attachment['ownerType'] == 'project'
          ? projectUuids.contains(attachment['ownerUuid'])
          : inspirationUuids.contains(attachment['ownerUuid']))
        attachment,
  ];

  snapshot['chatMessages'] = [
    for (final message in _listOf(snapshot['chatMessages']))
      if (inspirationUuids.contains(message['inspirationUuid'])) message,
  ];

  snapshot['inspirationLinks'] = [
    for (final link in _listOf(snapshot['inspirationLinks']))
      if (inspirationUuids.contains(link['sourceUuid']) &&
          inspirationUuids.contains(link['targetUuid']))
        link,
  ];
}

Map<String, dynamic>? _mergeAiSettings(
  Map<String, dynamic>? local,
  Map<String, dynamic>? remote,
) {
  if (local == null && remote == null) return null;
  if (local == null) return remote;
  if (remote == null) return local;

  final localInterfaces = (local['interfaces'] as Map<String, dynamic>?) ?? {};
  final remoteInterfaces =
      (remote['interfaces'] as Map<String, dynamic>?) ?? {};
  final mergedInterfaces = <String, dynamic>{
    ...remoteInterfaces,
    ...localInterfaces,
  };

  final localKeys = (local['apiKeys'] as Map<String, dynamic>?) ?? {};
  final remoteKeys = (remote['apiKeys'] as Map<String, dynamic>?) ?? {};
  final mergedKeys = <String, dynamic>{...remoteKeys, ...localKeys};

  return {
    'selectedInterfaceId':
        local['selectedInterfaceId'] ?? remote['selectedInterfaceId'],
    'selectedPresetId': local['selectedPresetId'] ?? remote['selectedPresetId'],
    'interfaces': mergedInterfaces,
    'apiKeys': mergedKeys,
    'customBaseUrl': local['customBaseUrl'] ?? remote['customBaseUrl'],
    'customModel': local['customModel'] ?? remote['customModel'],
    'customIsClaude': local['customIsClaude'] ?? remote['customIsClaude'],
  };
}
