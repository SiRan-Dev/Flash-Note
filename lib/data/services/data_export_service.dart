import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flashnote/data/datasources/local/ai_settings_storage.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/webdav_storage.dart';
import 'package:flashnote/data/services/snapshot_validator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImportResult {
  const ImportResult({
    required this.success,
    this.aiSettingsChanged = false,
    this.credentialsRequired = false,
  });

  final bool success;
  final bool aiSettingsChanged;

  /// 导入的数据不含 API Key / WebDAV 密码，需要用户重新填写。
  final bool credentialsRequired;
}

class DataExportService {
  DataExportService(
    this._db,
    this._aiStorage,
    this._webdavStorage,
    this._prefs,
  );

  final AppDatabase _db;
  final AiSettingsStorage _aiStorage;
  final WebDavStorage _webdavStorage;
  final SharedPreferences _prefs;

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
      'selectedInterfaceId': _aiStorage.selectedPresetId,
      'interfaces': {
        'openai_compatible': {
          'baseUrl': _aiStorage.baseUrlForInterface('openai_compatible'),
          'model': _aiStorage.modelForInterface('openai_compatible'),
        },
        'anthropic_compatible': {
          'baseUrl': _aiStorage.baseUrlForInterface('anthropic_compatible'),
          'model': _aiStorage.modelForInterface('anthropic_compatible'),
        },
      },
    };
  }

  Future<Map<String, dynamic>> _exportAttachment(Attachment attachment) async {
    final file = File(attachment.filePath);
    String? contentBase64;
    if (await file.exists()) {
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

  /// 导入文件不含凭据时提示用户重新填写。
  bool _needsCredentials({
    required Map<String, dynamic>? aiSettings,
    required Map<String, dynamic>? webdavSettings,
  }) {
    if (aiSettings != null && !_containsApiKey(aiSettings)) return true;
    if (webdavSettings != null) {
      final password = webdavSettings['password'];
      if (password is! String || password.isEmpty) return true;
    }
    return false;
  }

  bool _containsApiKey(Map<String, dynamic> settings) {
    final apiKeys = settings['apiKeys'];
    if (apiKeys is Map &&
        apiKeys.values.any((value) => value is String && value.isNotEmpty)) {
      return true;
    }
    final interfaces = settings['interfaces'];
    if (interfaces is Map) {
      for (final value in interfaces.values) {
        if (value is Map) {
          final apiKey = value['apiKey'];
          if (apiKey is String && apiKey.isNotEmpty) return true;
        }
      }
    }
    return false;
  }

  Future<bool> _importAiSettings(Map<String, dynamic> settings) async {
    final before = await _exportAiSettings();
    final selectedInterfaceId =
        settings['selectedInterfaceId'] as String? ??
        settings['selectedPresetId'] as String?;
    if (selectedInterfaceId != null) {
      await _aiStorage.setSelectedPreset(selectedInterfaceId);
    }
    final interfaces = settings['interfaces'] as Map<String, dynamic>?;
    if (interfaces != null) {
      for (final entry in interfaces.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        final baseUrl = value['baseUrl'] as String?;
        final model = value['model'] as String?;
        if (baseUrl != null && model != null) {
          await _aiStorage.setInterfaceConfig(
            interfaceId: entry.key,
            baseUrl: baseUrl,
            model: model,
          );
        }
        final apiKey = value['apiKey'] as String?;
        if (apiKey != null) {
          await _aiStorage.saveApiKey(entry.key, apiKey);
        }
      }
    }
    // Backward compatibility for exports created before compatible-interface
    // settings replaced provider presets.
    final apiKeys = settings['apiKeys'] as Map<String, dynamic>?;
    if (apiKeys != null) {
      for (final entry in apiKeys.entries) {
        await _aiStorage.saveApiKey(entry.key, entry.value as String);
      }
    }
    if (settings['customBaseUrl'] != null) {
      await _aiStorage.setCustomBaseUrl(settings['customBaseUrl'] as String);
    }
    if (settings['customModel'] != null) {
      await _aiStorage.setCustomModel(settings['customModel'] as String);
    }
    if (settings['customIsClaude'] != null) {
      await _aiStorage.setCustomIsClaude(settings['customIsClaude'] as bool);
    }
    final after = await _exportAiSettings();
    return jsonEncode(before) != jsonEncode(after);
  }

  Future<Map<String, dynamic>> _exportWebDavSettings() async {
    return {
      'serverUrl': _webdavStorage.serverUrl,
      'remotePath': _webdavStorage.remotePath,
      'autoSync': _webdavStorage.autoSync,
      'syncMode': _webdavStorage.syncMode,
      'syncIntervalMinutes': _webdavStorage.syncIntervalMinutes,
      'syncAttachments': _webdavStorage.syncAttachments,
      'lastSyncTime': _webdavStorage.lastSyncTime,
      'username': await _webdavStorage.username,
    };
  }

  Future<void> _importWebDavSettings(Map<String, dynamic> settings) async {
    await _webdavStorage.setServerUrl(
      settings['serverUrl'] as String? ?? WebDavStorage.defaultServerUrl,
    );
    await _webdavStorage.setRemotePath(
      settings['remotePath'] as String? ?? WebDavStorage.defaultRemotePath,
    );
    await _webdavStorage.setAutoSync(settings['autoSync'] as bool? ?? false);
    await _webdavStorage.setSyncMode(
      settings['syncMode'] as String? ?? WebDavStorage.defaultSyncMode,
    );
    await _webdavStorage.setSyncIntervalMinutes(
      settings['syncIntervalMinutes'] as int? ?? 0,
    );
    await _webdavStorage.setSyncAttachments(
      settings['syncAttachments'] as bool? ?? false,
    );
    final lastSyncTime = settings['lastSyncTime'] as int?;
    if (lastSyncTime != null) {
      await _webdavStorage.setLastSyncTime(lastSyncTime);
    }
    final username = settings['username'] as String?;
    final password = settings['password'] as String?;
    if (username != null) {
      await _webdavStorage.setUsername(username);
    }
    if (password != null) {
      await _webdavStorage.setPassword(password);
    }
  }

  Map<String, dynamic> _exportGraphLayouts() {
    final graphLayouts = <String, dynamic>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith('graph_positions_')) {
        graphLayouts[key] = _prefs.getString(key);
      }
    }
    return graphLayouts;
  }

  Future<void> _importGraphLayouts(Map<String, dynamic>? graphLayouts) async {
    final existingKeys =
        _prefs
            .getKeys()
            .where((key) => key.startsWith('graph_positions_'))
            .toList();
    for (final key in existingKeys) {
      await _prefs.remove(key);
    }
    if (graphLayouts == null) return;
    for (final entry in graphLayouts.entries) {
      final value = entry.value as String?;
      if (value != null) {
        await _prefs.setString(entry.key, value);
      }
    }
  }

  /// Export all data to a JSON file
  Future<String?> exportData() async {
    final inspirations = await _db.getAllInspirations();
    final projects = await _db.getAllProjects();
    final tasks = await _db.getAllTasks();
    final sources = await _db.getAllSources();
    final allAttachments = await _db.getAllAttachments();
    final chatMessages = await _db.getAllChatMessages();
    final links = await _db.getAllInspirationLinks();
    final clusters = await _db.getAllClusters();
    final reports = await _db.getAllReports();
    final deletedRecords = await _db.getAllDeletedRecords();
    final aiSettings = await _exportAiSettings();
    final webdavSettings = await _exportWebDavSettings();
    final graphLayouts = _exportGraphLayouts();

    final exportedAttachments = <Map<String, dynamic>>[];
    for (final attachment in allAttachments) {
      exportedAttachments.add(await _exportAttachment(attachment));
    }

    final export = {
      'version': 6,
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
      'webdavSettings': webdavSettings,
      'graphLayouts': graphLayouts,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(export);
    final bytes = utf8.encode(jsonStr);

    // Pick save location and write file. On Android/iOS the bytes are written
    // by the platform; saveFile() returns the saved file Uri (or null on cancel).
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export FlashNote Data',
      fileName: 'flashnote_export_${DateTime.now().millisecondsSinceEpoch}.json',
      mimeType: 'application/json',
      bytes: bytes,
    );

    return uri?.toString();
  }

  /// Import data from a JSON file, overwriting existing data
  Future<ImportResult> importData() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result.isEmpty) {
      return const ImportResult(success: false);
    }

    final pickedFile = result.first;
    final String? path = pickedFile.path;
    if (path == null) {
      return const ImportResult(success: false);
    }
    final jsonStr = await File(path).readAsString();
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('导入文件格式不正确');
    }
    final data = decoded;

    // Validate the whole file before touching any local data.
    validateSnapshot(data);
    final version = data['version'] as int? ?? 1;

    // All row replacement happens in a single transaction: if anything fails,
    // every delete/insert is rolled back. Attachment files are never deleted.
    await _db.transaction(() => _replaceLocalData(data, version));

    // Import AI settings only after the database transaction has committed.
    final aiSettings = data['aiSettings'] as Map<String, dynamic>?;
    var aiSettingsChanged = false;
    if (aiSettings != null) {
      aiSettingsChanged = await _importAiSettings(aiSettings);
    }

    final webdavSettings = data['webdavSettings'] as Map<String, dynamic>?;
    if (webdavSettings != null) {
      await _importWebDavSettings(webdavSettings);
    }

    await _importGraphLayouts(data['graphLayouts'] as Map<String, dynamic>?);

    return ImportResult(
      success: true,
      aiSettingsChanged: aiSettingsChanged,
      credentialsRequired: _needsCredentials(
        aiSettings: aiSettings,
        webdavSettings: webdavSettings,
      ),
    );
  }

  /// Replaces all local rows inside the caller's transaction.
  Future<void> _replaceLocalData(
    Map<String, dynamic> data,
    int version,
  ) async {
    // Clear all existing data
    for (final i in await _db.getAllInspirations()) {
      await _db.deleteChatMessagesByInspirationId(i.id);
    }
    final allLinks = await _db.getAllInspirationLinks();
    for (final l in allLinks) {
      await _db.deleteInspirationLink(l.id);
    }
    final allClusters = await _db.getAllClusters();
    for (final c in allClusters) {
      await _db.deleteCluster(c.id);
    }
    final allTasks = await _db.getAllTasks();
    for (final t in allTasks) {
      await _db.deleteTask(t.id);
    }
    final allProjects = await _db.getAllProjects();
    for (final p in allProjects) {
      await _db.deleteProject(p.id);
    }
    final allInspirations = await _db.getAllInspirations();
    for (final i in allInspirations) {
      await _db.deleteInspiration(i.id);
    }
    await _db.deleteAllSources();
    // Clear attachment rows, but keep the files on disk so a failed import
    // can never destroy locally stored attachments.
    final existingAttachments = await _db.getAllAttachments();
    for (final a in existingAttachments) {
      await _db.deleteAttachment(a.id);
    }
    await _db.deleteAllDeletedRecords();
    await _db.deleteAllReports();

    // Import inspirations (preserve original IDs for relationships)
    for (final raw in data['inspirations'] as List) {
      final i = raw as Map<String, dynamic>;
      final tags = i['tags'];
      final tagsStr =
          tags is List ? jsonEncode(tags) : (tags as String? ?? '[]');
      await _db.insertInspiration(
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

    // Import projects (preserve original IDs)
    for (final raw in data['projects'] as List) {
      final p = raw as Map<String, dynamic>;
      await _db.insertProject(
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

    // Import tasks (preserve original IDs)
    for (final raw in data['tasks'] as List) {
      final t = raw as Map<String, dynamic>;
      await _db.insertTask(
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

    // Import custom sources (preserve original IDs)
    for (final raw in data['customSources'] as List) {
      final s = raw as Map<String, dynamic>;
      await _db.insertSource(
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
        await _db.insertAttachment(
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
        await _db.insertChatMessage(
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
        await _db.insertInspirationLink(
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
        await _db.insertCluster(
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
        await _db.insertDeletedRecord(
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
        await _db.insertReport(
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
  }
}
