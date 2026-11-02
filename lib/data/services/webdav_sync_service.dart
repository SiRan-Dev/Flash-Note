import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/ai_settings_storage.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/webdav_storage.dart';
import 'package:flashnote/data/datasources/remote/webdav_client.dart';
import 'package:flashnote/data/services/snapshot_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SyncResult {
  const SyncResult.success({
    this.message = '同步成功',
    this.count,
    this.aiSettingsChanged = false,
    this.credentialsRequired = false,
    this.publishMode,
  }) : isSuccess = true;
  const SyncResult.failure(this.message)
    : isSuccess = false,
      count = null,
      aiSettingsChanged = false,
      credentialsRequired = false,
      publishMode = null;

  final bool isSuccess;
  final String message;
  final int? count;
  final bool aiSettingsChanged;

  /// 恢复的数据不含 API Key，需要用户在本机重新填写。
  final bool credentialsRequired;

  /// 本次发布使用的模式（atomicMove / dualSlotPointer），失败时为 null。
  final String? publishMode;
}

class WebDavSyncService {
  WebDavSyncService({
    required this.db,
    required this.aiStorage,
    required this.webdavStorage,
    WebDavClient Function()? clientFactory,
  }) : _clientFactory = clientFactory;

  final AppDatabase db;
  final AiSettingsStorage aiStorage;
  final WebDavStorage webdavStorage;
  final WebDavClient Function()? _clientFactory;

  @visibleForTesting
  static Map<String, dynamic> mergeSnapshotsForTesting(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) => _mergeData(local, remote);

  @visibleForTesting
  static Map<String, dynamic> stripCredentialsForTesting(
    Map<String, dynamic> snapshot,
  ) => _stripCredentials(snapshot);

  @visibleForTesting
  Future<bool> importSnapshotForTesting(Map<String, dynamic> data) =>
      _importFromJson(data);

  Future<WebDavClient> _getClient() async {
    final factory = _clientFactory;
    if (factory != null) return factory();
    final user = await webdavStorage.username;
    final pass = await webdavStorage.password;
    if (user == null || pass == null) {
      throw const WebDavException('WebDAV 未配置');
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
    return await client.testConnection();
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

  /// Whether the local device is missing the API key for the active interface.
  /// Exported/synced snapshots never contain credentials, so a restore onto a
  /// fresh device must ask the user to fill them in again.
  Future<bool> _needsAiKey() async {
    final key = await aiStorage.getApiKey(aiStorage.selectedPresetId);
    return key == null || key.isEmpty;
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

  /// Import data from JSON map into local DB.
  ///
  /// The whole snapshot is validated before anything is touched, all database
  /// writes run in a single transaction, and local attachment files are never
  /// deleted. A parse/validation failure therefore leaves local data intact.
  Future<bool> _importFromJson(Map<String, dynamic> data) async {
    validateSnapshot(data);
    final version = data['version'] as int? ?? 1;

    await db.transaction(() async {
      // Clear all existing rows
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
      // Rows are replaced, but files stay on disk so a failed import or a
      // merge can never destroy locally stored attachments.
      final existingAttachments = await db.getAllAttachments();
      for (final a in existingAttachments) {
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
              confidence: Value((l['confidence'] as num?)?.toDouble() ?? 0.5),
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
              id:
                  d['id'] != null
                      ? Value(d['id'] as int)
                      : const Value.absent(),
              entityType: d['entityType'] as String,
              entityId: d['entityId'] as int,
              deletedAt: d['deletedAt'] as int,
            ),
          );
        }
      }

      // Import reports (version 5+)
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
    });

    // Import AI settings only after the database transaction has committed.
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
      // downloadData() returns null only for HTTP 404; every other failure
      // (timeout / network / 401 / 403 / malformed body) throws and aborts
      // this restore without touching local data.
      final download = await client.downloadData();
      if (download == null) {
        return const SyncResult.failure('远端没有同步数据');
      }
      final aiSettingsChanged = await _importFromJson(download.data);
      await webdavStorage.setLastSyncTime(
        DateTime.now().millisecondsSinceEpoch,
      );
      return SyncResult.success(
        message: '拉取成功',
        aiSettingsChanged: aiSettingsChanged,
        credentialsRequired: await _needsAiKey(),
      );
    } on WebDavException catch (e) {
      return SyncResult.failure('拉取失败：${e.message}');
    } catch (e) {
      return SyncResult.failure('拉取失败: $e');
    }
  }

  /// Push: upload local data to remote
  Future<SyncResult> pushToRemote() async {
    try {
      final client = await _getClient();
      final localData = await _exportToJson();

      // 先探测当前发布模式；服务器不支持 HEAD 时由客户端自行降级。
      final state = await client.probePublishState();
      final published = await client.publishSnapshot(
        _stripCredentials(localData),
        state,
      );
      await webdavStorage.setLastSyncTime(
        DateTime.now().millisecondsSinceEpoch,
      );
      return SyncResult.success(
        message: '推送成功（${published.mode.label}）',
        publishMode: published.mode.name,
      );
    } on WebDavConflictException {
      return const SyncResult.failure(
        '推送中止：远端已被其他设备修改，请重试（未写入远端）',
      );
    } on WebDavException catch (e) {
      return SyncResult.failure('推送失败：${e.message}');
    } catch (e) {
      return SyncResult.failure('推送失败: $e');
    }
  }

  /// Merge: compare local and remote, keep newer per record
  Future<SyncResult> mergeSync() async {
    try {
      final client = await _getClient();

      // Fetch remote data. Only an explicit 404 means "first sync"; network
      // errors, timeouts and auth failures must abort instead of overwriting
      // the remote file with local data.
      final remote = await client.downloadData();
      if (remote == null) {
        final localData = await _exportToJson();
        try {
          final published = await client.publishSnapshot(
            _stripCredentials(localData),
            const WebDavPublishState.firstSync(),
          );
          await webdavStorage.setLastSyncTime(
            DateTime.now().millisecondsSinceEpoch,
          );
          return SyncResult.success(
            message: '首次同步，已推送本地数据（${published.mode.label}）',
            publishMode: published.mode.name,
          );
        } on WebDavConflictException {
          return const SyncResult.failure(
            '首次同步中止：远端已被其他设备创建，请重试（未覆盖远端）',
          );
        }
      }

      // Get local data
      final localData = await _exportToJson();

      // Merge
      final merged = _mergeData(localData, remote.data);

      // Validate before publishing: never write a snapshot the local importer
      // could not restore.
      validateSnapshot(merged);

      // 原子发布：临时对象/MOVE 或双槽位 + 指针，失败时旧版本保持完好。
      final published = await client.publishSnapshot(
        _stripCredentials(merged),
        remote.publishState,
      );

      // Apply the merged result locally only after the publish succeeded, so a
      // failed publish never changes local data.
      final aiSettingsChanged = await _importFromJson(merged);

      await webdavStorage.setLastSyncTime(
        DateTime.now().millisecondsSinceEpoch,
      );
      return SyncResult.success(
        message: '合并同步成功（${published.mode.label}）',
        aiSettingsChanged: aiSettingsChanged,
        credentialsRequired: await _needsAiKey(),
        publishMode: published.mode.name,
      );
    } on WebDavConflictException {
      return const SyncResult.failure(
        '合并同步中止：远端已被其他设备更新，请重试（未写入远端）',
      );
    } on WebDavException catch (e) {
      return SyncResult.failure('合并同步失败：${e.message}');
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
      'reports': _mergeEntityList(
        local['reports'],
        remote['reports'],
        deletedRecords,
        'reports',
      ),
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
    return {
      'selectedInterfaceId': aiStorage.selectedPresetId,
      'interfaces': {
        'openai_compatible': {
          'baseUrl': aiStorage.baseUrlForInterface('openai_compatible'),
          'model': aiStorage.modelForInterface('openai_compatible'),
        },
        'anthropic_compatible': {
          'baseUrl': aiStorage.baseUrlForInterface('anthropic_compatible'),
          'model': aiStorage.modelForInterface('anthropic_compatible'),
        },
      },
    };
  }

  /// Removes credentials from an outgoing snapshot. Doing this at the upload
  /// boundary also covers legacy remote snapshots that still contain keys.
  static Map<String, dynamic> _stripCredentials(Map<String, dynamic> snapshot) {
    final copy = Map<String, dynamic>.from(snapshot);

    final aiSettings = copy['aiSettings'];
    if (aiSettings is Map<String, dynamic>) {
      final aiCopy = Map<String, dynamic>.from(aiSettings)..remove('apiKeys');
      final interfaces = aiCopy['interfaces'];
      if (interfaces is Map<String, dynamic>) {
        aiCopy['interfaces'] = {
          for (final entry in interfaces.entries)
            entry.key:
                entry.value is Map<String, dynamic>
                    ? (Map<String, dynamic>.from(
                      entry.value as Map<String, dynamic>,
                    )..remove('apiKey'))
                    : entry.value,
        };
      }
      copy['aiSettings'] = aiCopy;
    }

    final webdavSettings = copy['webdavSettings'];
    if (webdavSettings is Map<String, dynamic>) {
      copy['webdavSettings'] = Map<String, dynamic>.from(
        webdavSettings,
      )..remove('password');
    }

    return copy;
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
