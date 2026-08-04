import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/ai_settings_storage.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/webdav_storage.dart';
import 'package:flashnote/data/datasources/remote/webdav_client.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SyncResult {
  const SyncResult.success({
    this.message = '同步成功',
    this.count,
    this.aiSettingsChanged = false,
  }) : isSuccess = true;
  const SyncResult.failure(this.message)
    : isSuccess = false,
      count = null,
      aiSettingsChanged = false;

  final bool isSuccess;
  final String message;
  final int? count;
  final bool aiSettingsChanged;
}

class WebDavSyncService {
  WebDavSyncService({
    required this.db,
    required this.aiStorage,
    required this.webdavStorage,
  });

  final AppDatabase db;
  final AiSettingsStorage aiStorage;
  final WebDavStorage webdavStorage;

  @visibleForTesting
  static Map<String, dynamic> mergeSnapshotsForTesting(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) => _mergeData(local, remote);

  Future<WebDavClient> _getClient() async {
    final user = await webdavStorage.username;
    final pass = await webdavStorage.password;
    if (user == null || pass == null) {
      throw Exception('WebDAV 未配置');
    }
    return WebDavClient(
      serverUrl: webdavStorage.serverUrl,
      username: user,
      password: pass,
      remotePath: webdavStorage.remotePath,
    );
  }

  Future<(bool, String)> testConnection() async {
    final client = await _getClient();
    return client.testConnection();
  }

  Future<Map<String, dynamic>> _exportAttachment(
    Attachment attachment, {
    required bool includeContent,
  }) async {
    final file = File(attachment.filePath);
    String? contentBase64;
    if (includeContent && await file.exists()) {
      contentBase64 = base64Encode(await file.readAsBytes());
    }
    return {
      'id': attachment.id,
      'ownerType': attachment.ownerType,
      'ownerId': attachment.ownerId,
      'fileName': attachment.fileName,
      'filePath': attachment.filePath,
      'mimeType': attachment.mimeType,
      'size': attachment.size,
      'createdAt': attachment.createdAt,
      'contentBase64': contentBase64,
    };
  }

  Future<String> _restoreAttachmentFile(Map<String, dynamic> attachment) async {
    final contentBase64 = attachment['contentBase64'] as String?;
    if (contentBase64 == null || contentBase64.isEmpty) {
      return attachment['filePath'] as String? ?? '';
    }

    final appDir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(appDir.path, 'attachments'));
    await attachmentsDir.create(recursive: true);
    final fileName = attachment['fileName'] as String? ?? 'attachment';
    final id =
        attachment['id'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final createdAt = attachment['createdAt'] as int? ?? id;
    final safeName = p.basename(fileName);
    final restoredPath = p.join(
      attachmentsDir.path,
      '${createdAt}_${id}_$safeName',
    );
    await File(restoredPath).writeAsBytes(base64Decode(contentBase64));
    return restoredPath;
  }

  Future<void> _deleteAttachmentFile(String filePath) async {
    if (filePath.isEmpty) return;
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Export local data to JSON map (same format as DataExportService)
  Future<Map<String, dynamic>> _exportToJson() async {
    final inspirations = await db.getAllInspirations();
    final projects = await db.getAllProjects();
    final tasks = await db.getAllTasks();
    final sources = await db.getAllSources();
    final allAttachments = await db.getAllAttachments();
    final chatMessages = await db.getAllChatMessages();
    final links = await db.getAllInspirationLinks();
    final clusters = await db.getAllClusters();
    final reports = await db.getAllReports();
    final deletedRecords = await db.getAllDeletedRecords();
    final aiSettings = await _exportAiSettings();
    final includeAttachmentContent = webdavStorage.syncAttachments;
    final exportedAttachments = <Map<String, dynamic>>[];
    for (final attachment in allAttachments) {
      exportedAttachments.add(
        await _exportAttachment(
          attachment,
          includeContent: includeAttachmentContent,
        ),
      );
    }

    return {
      'version': 5,
      'exportedAt': DateTime.now().toIso8601String(),
      'inspirations':
          inspirations
              .map(
                (i) => {
                  'id': i.id,
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
      'projects':
          projects
              .map(
                (p) => {
                  'id': p.id,
                  'inspirationId': p.inspirationId,
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
      'tasks':
          tasks
              .map(
                (t) => {
                  'id': t.id,
                  'projectId': t.projectId,
                  'title': t.title,
                  'isCompleted': t.isCompleted,
                  'isPinned': t.isPinned,
                  'createdAt': t.createdAt,
                  'updatedAt': t.updatedAt,
                },
              )
              .toList(),
      'customSources':
          sources
              .map(
                (s) => {
                  'id': s.id,
                  'name': s.name,
                  'icon': s.icon,
                  'sortOrder': s.sortOrder,
                  'isBuiltIn': s.isBuiltIn,
                  'createdAt': s.createdAt,
                },
              )
              .toList(),
      'attachments': exportedAttachments,
      'chatMessages':
          chatMessages
              .map(
                (m) => {
                  'id': m.id,
                  'inspirationId': m.inspirationId,
                  'role': m.role,
                  'content': m.content,
                  'createdAt': m.createdAt,
                },
              )
              .toList(),
      'inspirationLinks':
          links
              .map(
                (l) => {
                  'id': l.id,
                  'sourceId': l.sourceId,
                  'targetId': l.targetId,
                  'linkType': l.linkType,
                  'relationLabel': l.relationLabel,
                  'confidence': l.confidence,
                  'isAutoGenerated': l.isAutoGenerated,
                  'createdAt': l.createdAt,
                },
              )
              .toList(),
      'clusters':
          clusters
              .map(
                (c) => {
                  'id': c.id,
                  'name': c.name,
                  'description': c.description,
                  'createdAt': c.createdAt,
                  'updatedAt': c.updatedAt,
                },
              )
              .toList(),
      'reports':
          reports
              .map(
                (r) => {
                  'id': r.id,
                  'type': r.type,
                  'content': r.content,
                  'model': r.model,
                  'createdAt': r.createdAt,
                  'updatedAt': r.updatedAt,
                },
              )
              .toList(),
      'deletedRecords':
          deletedRecords
              .map(
                (d) => {
                  'id': d.id,
                  'entityType': d.entityType,
                  'entityId': d.entityId,
                  'deletedAt': d.deletedAt,
                },
              )
              .toList(),
      'aiSettings': aiSettings,
    };
  }

  /// Import data from JSON map into local DB
  Future<bool> _importFromJson(Map<String, dynamic> data) async {
    final version = data['version'] as int? ?? 1;
    if (version < 1 || version > 5) {
      throw Exception('不支持的数据版本');
    }

    // Clear all existing data
    for (final i in await db.getAllInspirations()) {
      await db.deleteChatMessagesByInspirationId(i.id);
    }
    final allLinks = await db.getAllInspirationLinks();
    for (final l in allLinks) {
      await db.deleteInspirationLink(l.id);
    }
    final allClusters = await db.getAllClusters();
    for (final c in allClusters) {
      await db.deleteCluster(c.id);
    }
    final allTasks = await db.getAllTasks();
    for (final t in allTasks) {
      await db.deleteTask(t.id);
    }
    final allProjects = await db.getAllProjects();
    for (final p in allProjects) {
      await db.deleteProject(p.id);
    }
    final allInspirations = await db.getAllInspirations();
    for (final i in allInspirations) {
      await db.deleteInspiration(i.id);
    }
    await db.deleteAllSources();
    final existingAttachments = await db.getAllAttachments();
    for (final a in existingAttachments) {
      await _deleteAttachmentFile(a.filePath);
      await db.deleteAttachment(a.id);
    }
    await db.deleteAllDeletedRecords();
    await db.deleteAllReports();

    // Import inspirations
    for (final raw in data['inspirations'] as List) {
      final i = raw as Map<String, dynamic>;
      final tags = i['tags'];
      final tagsStr =
          tags is List ? jsonEncode(tags) : (tags as String? ?? '[]');
      await db.insertInspiration(
        InspirationsCompanion.insert(
          id: Value(i['id'] as int),
          content: i['content'] as String,
          createdAt: i['createdAt'] as int,
          updatedAt: i['updatedAt'] as int,
          source:
              i['source'] != null
                  ? Value(i['source'] as String)
                  : const Value.absent(),
          tags: Value(tagsStr),
          aiAnalysis:
              i['aiAnalysis'] != null
                  ? Value(i['aiAnalysis'] as String)
                  : const Value.absent(),
          mindMapData:
              i['mindMapData'] != null
                  ? Value(i['mindMapData'] as String)
                  : const Value.absent(),
          isPinned: Value(i['isPinned'] as bool),
          reviewedAt:
              i['reviewedAt'] != null
                  ? Value(i['reviewedAt'] as int)
                  : const Value.absent(),
          needsFollowUp: Value(i['needsFollowUp'] as bool? ?? false),
        ),
      );
    }

    // Import projects
    for (final raw in data['projects'] as List) {
      final p = raw as Map<String, dynamic>;
      await db.insertProject(
        ProjectsCompanion.insert(
          id: Value(p['id'] as int),
          title: p['title'] as String,
          createdAt: p['createdAt'] as int,
          updatedAt: p['updatedAt'] as int,
          inspirationId:
              p['inspirationId'] != null
                  ? Value(p['inspirationId'] as int)
                  : const Value.absent(),
          description: Value(p['description'] as String? ?? ''),
          progress: Value(p['progress'] as int? ?? 0),
          status: Value(p['status'] as String? ?? 'active'),
          isPinned: Value(p['isPinned'] as bool? ?? false),
        ),
      );
    }

    // Import tasks
    for (final raw in data['tasks'] as List) {
      final t = raw as Map<String, dynamic>;
      await db.insertTask(
        TasksCompanion.insert(
          id: Value(t['id'] as int),
          projectId: t['projectId'] as int,
          title: t['title'] as String,
          createdAt: t['createdAt'] as int,
          updatedAt: t['updatedAt'] as int,
          isCompleted: Value(t['isCompleted'] as bool? ?? false),
          isPinned: Value(t['isPinned'] as bool? ?? false),
        ),
      );
    }

    // Import custom sources
    for (final raw in data['customSources'] as List) {
      final s = raw as Map<String, dynamic>;
      await db.insertSource(
        CustomSourcesCompanion.insert(
          id: Value(s['id'] as int),
          name: s['name'] as String,
          icon: s['icon'] as String,
          createdAt: s['createdAt'] as int,
          sortOrder: Value(s['sortOrder'] as int? ?? 0),
          isBuiltIn: Value(s['isBuiltIn'] as bool? ?? false),
        ),
      );
    }

    // Import attachments (version 2+)
    if (version >= 2 && data['attachments'] != null) {
      for (final raw in data['attachments'] as List) {
        final a = raw as Map<String, dynamic>;
        final restoredPath = await _restoreAttachmentFile(a);
        await db.insertAttachment(
          AttachmentsCompanion.insert(
            id: Value(a['id'] as int),
            ownerType: a['ownerType'] as String,
            ownerId: a['ownerId'] as int,
            fileName: a['fileName'] as String,
            filePath: restoredPath,
            mimeType: a['mimeType'] as String,
            size: Value(a['size'] as int? ?? 0),
            createdAt: a['createdAt'] as int,
          ),
        );
      }
    }

    // Import chat messages (version 3+)
    if (version >= 3 && data['chatMessages'] != null) {
      for (final raw in data['chatMessages'] as List) {
        final m = raw as Map<String, dynamic>;
        await db.insertChatMessage(
          ChatMessagesCompanion.insert(
            id: Value(m['id'] as int),
            inspirationId: m['inspirationId'] as int,
            role: m['role'] as String,
            content: m['content'] as String,
            createdAt: m['createdAt'] as int,
          ),
        );
      }
    }

    // Import inspiration links (version 3+)
    if (version >= 3 && data['inspirationLinks'] != null) {
      for (final raw in data['inspirationLinks'] as List) {
        final l = raw as Map<String, dynamic>;
        await db.insertInspirationLink(
          InspirationLinksCompanion.insert(
            id: Value(l['id'] as int),
            sourceId: l['sourceId'] as int,
            targetId: l['targetId'] as int,
            linkType: l['linkType'] as String,
            relationLabel: Value(l['relationLabel'] as String?),
            confidence: Value(l['confidence'] as double? ?? 0.5),
            isAutoGenerated: Value(l['isAutoGenerated'] as bool? ?? false),
            createdAt: l['createdAt'] as int,
          ),
        );
      }
    }

    // Import clusters (version 3+)
    if (version >= 3 && data['clusters'] != null) {
      for (final raw in data['clusters'] as List) {
        final c = raw as Map<String, dynamic>;
        await db.insertCluster(
          ClustersCompanion.insert(
            id: Value(c['id'] as int),
            name: c['name'] as String,
            description: Value(c['description'] as String? ?? ''),
            createdAt: c['createdAt'] as int,
            updatedAt: c['updatedAt'] as int,
          ),
        );
      }
    }

    // Import deletion tombstones (version 4+)
    if (version >= 4 && data['deletedRecords'] != null) {
      for (final raw in data['deletedRecords'] as List) {
        final d = raw as Map<String, dynamic>;
        await db.insertDeletedRecord(
          DeletedRecordsCompanion.insert(
            id: d['id'] != null ? Value(d['id'] as int) : const Value.absent(),
            entityType: d['entityType'] as String,
            entityId: d['entityId'] as int,
            deletedAt: d['deletedAt'] as int,
          ),
        );
      }
    }

    if (version >= 5 && data['reports'] != null) {
      for (final raw in data['reports'] as List) {
        final r = raw as Map<String, dynamic>;
        await db.insertReport(
          ReportsCompanion.insert(
            id: Value(r['id'] as int),
            type: r['type'] as String,
            content: r['content'] as String,
            model: Value(r['model'] as String? ?? ''),
            createdAt: r['createdAt'] as int,
            updatedAt: r['updatedAt'] as int,
          ),
        );
      }
    }

    // Import AI settings
    final aiSettings = data['aiSettings'] as Map<String, dynamic>?;
    var aiSettingsChanged = false;
    if (aiSettings != null) {
      aiSettingsChanged = await _importAiSettings(aiSettings);
    }
    return aiSettingsChanged;
  }

  /// Pull: download remote data and overwrite local
  Future<SyncResult> pullFromRemote() async {
    try {
      final client = await _getClient();
      final remoteData = await client.downloadData();
      if (remoteData == null) {
        return const SyncResult.failure('远端没有同步数据');
      }
      final aiSettingsChanged = await _importFromJson(remoteData);
      await webdavStorage.setLastSyncTime(
        DateTime.now().millisecondsSinceEpoch,
      );
      return SyncResult.success(
        message: '拉取成功',
        aiSettingsChanged: aiSettingsChanged,
      );
    } catch (e) {
      return SyncResult.failure('拉取失败: $e');
    }
  }

  /// Push: upload local data to remote
  Future<SyncResult> pushToRemote() async {
    try {
      final client = await _getClient();
      final localData = await _exportToJson();
      await client.uploadData(localData);
      await webdavStorage.setLastSyncTime(
        DateTime.now().millisecondsSinceEpoch,
      );
      return const SyncResult.success(message: '推送成功');
    } catch (e) {
      return SyncResult.failure('推送失败: $e');
    }
  }

  /// Merge: compare local and remote, keep newer per record
  Future<SyncResult> mergeSync() async {
    try {
      final client = await _getClient();

      // Fetch remote data
      Map<String, dynamic>? remoteData;
      try {
        remoteData = await client.downloadData();
      } catch (_) {
        // Remote file doesn't exist, just push local
        final localData = await _exportToJson();
        await client.uploadData(localData);
        await webdavStorage.setLastSyncTime(
          DateTime.now().millisecondsSinceEpoch,
        );
        return const SyncResult.success(message: '首次同步，已推送本地数据');
      }

      // Get local data
      final localData = await _exportToJson();

      // Merge
      final merged = _mergeData(localData, remoteData!);

      // Save merged result locally
      final aiSettingsChanged = await _importFromJson(merged);

      // Upload merged result to remote
      await client.uploadData(merged);

      await webdavStorage.setLastSyncTime(
        DateTime.now().millisecondsSinceEpoch,
      );
      return SyncResult.success(
        message: '合并同步成功',
        aiSettingsChanged: aiSettingsChanged,
      );
    } catch (e) {
      return SyncResult.failure('合并同步失败: $e');
    }
  }

  /// Merge two data snapshots: newer updatedAt wins per entity ID
  static Map<String, dynamic> _mergeData(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localVersion = local['version'] as int? ?? 1;
    final remoteVersion = remote['version'] as int? ?? 1;
    final version = localVersion > remoteVersion ? localVersion : remoteVersion;
    final deletedRecords = _mergeDeletedRecords(
      local['deletedRecords'],
      remote['deletedRecords'],
    );
    final merged = <String, dynamic>{
      'version': version < 5 ? 5 : version,
      'exportedAt': DateTime.now().toIso8601String(),
      'inspirations': _mergeEntityList(
        local['inspirations'],
        remote['inspirations'],
        deletedRecords,
        'inspirations',
      ),
      'projects': _mergeEntityList(
        local['projects'],
        remote['projects'],
        deletedRecords,
        'projects',
      ),
      'tasks': _mergeEntityList(
        local['tasks'],
        remote['tasks'],
        deletedRecords,
        'tasks',
      ),
      'customSources': _mergeEntityList(
        local['customSources'],
        remote['customSources'],
        deletedRecords,
        'customSources',
      ),
      'attachments': _mergeEntityList(
        local['attachments'],
        remote['attachments'],
        deletedRecords,
        'attachments',
      ),
      'deletedRecords': deletedRecords,
      'aiSettings': _mergeAiSettings(
        (local['aiSettings'] as Map<String, dynamic>?) ?? {},
        (remote['aiSettings'] as Map<String, dynamic>?) ?? {},
      ),
    };
    if (version >= 3) {
      merged['chatMessages'] = _mergeEntityList(
        local['chatMessages'],
        remote['chatMessages'],
        deletedRecords,
        'chatMessages',
      );
      merged['inspirationLinks'] = _mergeEntityList(
        local['inspirationLinks'],
        remote['inspirationLinks'],
        deletedRecords,
        'inspirationLinks',
      );
      merged['clusters'] = _mergeEntityList(
        local['clusters'],
        remote['clusters'],
        deletedRecords,
        'clusters',
      );
    }
    return merged;
  }

  /// Merge AI settings: local takes priority, missing keys filled from remote
  static Map<String, dynamic>? _mergeAiSettings(
    Map<String, dynamic>? local,
    Map<String, dynamic>? remote,
  ) {
    if (local == null && remote == null) return null;
    if (local == null) return remote;
    if (remote == null) return local;

    final localInterfaces =
        (local['interfaces'] as Map<String, dynamic>?) ?? {};
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
      'selectedPresetId':
          local['selectedPresetId'] ?? remote['selectedPresetId'],
      'interfaces': mergedInterfaces,
      'apiKeys': mergedKeys,
      'customBaseUrl': local['customBaseUrl'] ?? remote['customBaseUrl'],
      'customModel': local['customModel'] ?? remote['customModel'],
      'customIsClaude': local['customIsClaude'] ?? remote['customIsClaude'],
    };
  }

  /// Merge two lists of entities by ID, keeping the one with newer updatedAt
  static List<dynamic> _mergeEntityList(
    dynamic localList,
    dynamic remoteList,
    List<Map<String, dynamic>> deletedRecords,
    String entityType,
  ) {
    final local = (localList as List?)?.cast<Map<String, dynamic>>() ?? [];
    final remote = (remoteList as List?)?.cast<Map<String, dynamic>>() ?? [];

    final Map<int, Map<String, dynamic>> merged = {};

    // Add all local entries
    for (final item in local) {
      final id = item['id'] as int;
      merged[id] = item;
    }

    // Compare with remote
    for (final item in remote) {
      final id = item['id'] as int;
      if (!merged.containsKey(id)) {
        // Only in remote, take it
        merged[id] = item;
      } else {
        // In both: compare updatedAt
        final localUpdated = merged[id]!['updatedAt'] as int? ?? 0;
        final remoteUpdated = item['updatedAt'] as int? ?? 0;
        if (remoteUpdated > localUpdated) {
          merged[id] = item;
        }
      }
    }

    final tombstones = {
      for (final d in deletedRecords.where(
        (d) => d['entityType'] == entityType,
      ))
        d['entityId'] as int: d['deletedAt'] as int,
    };

    return merged.values.where((item) {
      final id = item['id'] as int;
      final deletedAt = tombstones[id];
      if (deletedAt == null) return true;
      final itemUpdated =
          item['updatedAt'] as int? ?? item['createdAt'] as int? ?? 0;
      return itemUpdated > deletedAt;
    }).toList();
  }

  static List<Map<String, dynamic>> _mergeDeletedRecords(
    dynamic localList,
    dynamic remoteList,
  ) {
    final local = (localList as List?)?.cast<Map<String, dynamic>>() ?? [];
    final remote = (remoteList as List?)?.cast<Map<String, dynamic>>() ?? [];
    final merged = <String, Map<String, dynamic>>{};

    for (final item in [...local, ...remote]) {
      final entityType = item['entityType'] as String?;
      final entityId = item['entityId'] as int?;
      final deletedAt = item['deletedAt'] as int?;
      if (entityType == null || entityId == null || deletedAt == null) {
        continue;
      }
      final key = '$entityType:$entityId';
      final existing = merged[key];
      if (existing == null || deletedAt > (existing['deletedAt'] as int)) {
        merged[key] = {
          'entityType': entityType,
          'entityId': entityId,
          'deletedAt': deletedAt,
        };
      }
    }

    return merged.values.toList();
  }

  static List<String> _parseTags(String tagsJson) {
    try {
      final list = jsonDecode(tagsJson) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _exportAiSettings() async {
    final openAiKey = await aiStorage.getApiKey('openai_compatible');
    final anthropicKey = await aiStorage.getApiKey('anthropic_compatible');
    return {
      'selectedInterfaceId': aiStorage.selectedPresetId,
      'interfaces': {
        'openai_compatible': {
          'baseUrl': aiStorage.baseUrlForInterface('openai_compatible'),
          'model': aiStorage.modelForInterface('openai_compatible'),
          if (openAiKey != null && openAiKey.isNotEmpty) 'apiKey': openAiKey,
        },
        'anthropic_compatible': {
          'baseUrl': aiStorage.baseUrlForInterface('anthropic_compatible'),
          'model': aiStorage.modelForInterface('anthropic_compatible'),
          if (anthropicKey != null && anthropicKey.isNotEmpty)
            'apiKey': anthropicKey,
        },
      },
    };
  }

  Future<bool> _importAiSettings(Map<String, dynamic> settings) async {
    final before = await _exportAiSettings();
    final selectedInterfaceId =
        settings['selectedInterfaceId'] as String? ??
        settings['selectedPresetId'] as String?;
    if (selectedInterfaceId != null) {
      await aiStorage.setSelectedPreset(selectedInterfaceId);
    }
    final interfaces = settings['interfaces'] as Map<String, dynamic>?;
    if (interfaces != null) {
      for (final entry in interfaces.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        final baseUrl = value['baseUrl'] as String?;
        final model = value['model'] as String?;
        if (baseUrl != null && model != null) {
          await aiStorage.setInterfaceConfig(
            interfaceId: entry.key,
            baseUrl: baseUrl,
            model: model,
          );
        }
        final apiKey = value['apiKey'] as String?;
        if (apiKey != null) {
          await aiStorage.saveApiKey(entry.key, apiKey);
        }
      }
    }
    final apiKeys = settings['apiKeys'] as Map<String, dynamic>?;
    if (apiKeys != null) {
      for (final entry in apiKeys.entries) {
        await aiStorage.saveApiKey(entry.key, entry.value as String);
      }
    }
    if (settings['customBaseUrl'] != null) {
      await aiStorage.setCustomBaseUrl(settings['customBaseUrl'] as String);
    }
    if (settings['customModel'] != null) {
      await aiStorage.setCustomModel(settings['customModel'] as String);
    }
    if (settings['customIsClaude'] != null) {
      await aiStorage.setCustomIsClaude(settings['customIsClaude'] as bool);
    }
    final after = await _exportAiSettings();
    return jsonEncode(before) != jsonEncode(after);
  }
}
