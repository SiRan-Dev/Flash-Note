import 'dart:convert';

import 'package:flashnote/data/datasources/local/ai_settings_storage.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/webdav_storage.dart';
import 'package:flashnote/data/datasources/remote/webdav_client.dart';
import 'package:flashnote/data/services/snapshot_codec.dart';
import 'package:flashnote/data/services/snapshot_validator.dart';
import 'package:flutter/foundation.dart';

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
  }) : _clientFactory = clientFactory {
    _codec = SnapshotCodec(db);
  }

  final AppDatabase db;
  final AiSettingsStorage aiStorage;
  final WebDavStorage webdavStorage;
  final WebDavClient Function()? _clientFactory;
  late final SnapshotCodec _codec;

  @visibleForTesting
  static Map<String, dynamic> mergeSnapshotsForTesting(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) => mergeSnapshots(local, remote);

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

  /// Whether the local device is missing the API key for the active interface.
  /// Exported/synced snapshots never contain credentials, so a restore onto a
  /// fresh device must ask the user to fill them in again.
  Future<bool> _needsAiKey() async {
    final key = await aiStorage.getApiKey(aiStorage.selectedPresetId);
    return key == null || key.isEmpty;
  }

  /// Export local data to JSON map (v7: uuid identity, no local ids)
  Future<Map<String, dynamic>> _exportToJson() async {
    final deviceId = await webdavStorage.getOrCreateDeviceId();
    final snapshot = await _codec.exportSnapshot(
      deviceId: deviceId,
      includeAttachmentContent: webdavStorage.syncAttachments,
    );
    snapshot['aiSettings'] = await _exportAiSettings();
    return snapshot;
  }

  /// Import data from JSON map into local DB.
  ///
  /// The whole snapshot is validated before anything is touched, all database
  /// writes run in a single transaction, and local attachment files are never
  /// deleted. A parse/validation failure therefore leaves local data intact.
  Future<bool> _importFromJson(Map<String, dynamic> data) async {
    validateSnapshot(data);
    final version = data['version'] as int? ?? 1;
    final deviceId = await webdavStorage.getOrCreateDeviceId();
    final normalized = version >= kSnapshotVersion
        ? data
        : await _codec.upgradeLegacySnapshot(data, deviceId: deviceId);
    // 升级后的快照也必须通过 v7 校验，避免把坏数据写进本地库。
    validateSnapshot(normalized);

    await db.transaction(() => _codec.importSnapshot(normalized));

    // Import AI settings only after the database transaction has committed.
    final aiSettings = normalized['aiSettings'] as Map<String, dynamic>?;
    if (aiSettings == null) return false;
    return await _importAiSettings(aiSettings);
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
      return const SyncResult.failure('推送中止：远端已被其他设备修改，请重试（未写入远端）');
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
          return const SyncResult.failure('首次同步中止：远端已被其他设备创建，请重试（未覆盖远端）');
        }
      }

      // Get local data
      final localData = await _exportToJson();

      // 旧文件（v5/v6）先升级成 v7，再按 uuid 合并。
      final remoteVersion = remote.data['version'] as int? ?? 1;
      final deviceId = await webdavStorage.getOrCreateDeviceId();
      final remoteV7 = remoteVersion >= kSnapshotVersion
          ? remote.data
          : await _codec.upgradeLegacySnapshot(remote.data, deviceId: deviceId);
      validateSnapshot(remoteV7);

      // Merge
      final merged = mergeSnapshots(localData, remoteV7);

      // Validate before publishing: never write a snapshot the local importer
      // could not restore.
      validateSnapshot(merged);

      // 原子发布：临时对象/MOVE 或双槽位 + 指针，失败时旧版本保持完好。
      // 远端只有旧文件时，本次是在创建 v7 文件，按首次创建做冲突复核。
      final publishState = remote.fromLegacyFile
          ? const WebDavPublishState.firstSync()
          : remote.publishState;
      final published = await client.publishSnapshot(
        _stripCredentials(merged),
        publishState,
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
      return const SyncResult.failure('合并同步中止：远端已被其他设备更新，请重试（未写入远端）');
    } on WebDavException catch (e) {
      return SyncResult.failure('合并同步失败：${e.message}');
    } catch (e) {
      return SyncResult.failure('合并同步失败: $e');
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
            entry.key: entry.value is Map<String, dynamic>
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
      copy['webdavSettings'] = Map<String, dynamic>.from(webdavSettings)
        ..remove('password');
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
