import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flashnote/data/datasources/local/ai_settings_storage.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/webdav_storage.dart';
import 'package:flashnote/data/services/snapshot_codec.dart';
import 'package:flashnote/data/services/snapshot_validator.dart';
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
    final existingKeys = _prefs
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
    final deviceId = await _webdavStorage.getOrCreateDeviceId();
    final snapshot = await SnapshotCodec(
      _db,
    ).exportSnapshot(deviceId: deviceId, includeAttachmentContent: true);
    snapshot['aiSettings'] = await _exportAiSettings();
    snapshot['webdavSettings'] = await _exportWebDavSettings();
    snapshot['graphLayouts'] = _exportGraphLayouts();

    final jsonStr = const JsonEncoder.withIndent('  ').convert(snapshot);
    final bytes = utf8.encode(jsonStr);

    // Pick save location and write file. On Android/iOS the bytes are written
    // by the platform; saveFile() returns the saved file Uri (or null on cancel).
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export FlashNote Data',
      fileName:
          'flashnote_export_${DateTime.now().millisecondsSinceEpoch}.json',
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
    final deviceId = await _webdavStorage.getOrCreateDeviceId();
    final codec = SnapshotCodec(_db);
    final normalized = version >= kSnapshotVersion
        ? data
        : await codec.upgradeLegacySnapshot(data, deviceId: deviceId);
    validateSnapshot(normalized);

    // All row replacement happens in a single transaction: if anything fails,
    // every delete/insert is rolled back. Attachment files are never deleted.
    await _db.transaction(() => codec.importSnapshot(normalized));

    // Import AI settings only after the database transaction has committed.
    final aiSettings = normalized['aiSettings'] as Map<String, dynamic>?;
    var aiSettingsChanged = false;
    if (aiSettings != null) {
      aiSettingsChanged = await _importAiSettings(aiSettings);
    }

    final webdavSettings =
        normalized['webdavSettings'] as Map<String, dynamic>?;
    if (webdavSettings != null) {
      await _importWebDavSettings(webdavSettings);
    }

    await _importGraphLayouts(
      normalized['graphLayouts'] as Map<String, dynamic>?,
    );

    return ImportResult(
      success: true,
      aiSettingsChanged: aiSettingsChanged,
      credentialsRequired: _needsCredentials(
        aiSettings: aiSettings,
        webdavSettings: webdavSettings,
      ),
    );
  }
}
