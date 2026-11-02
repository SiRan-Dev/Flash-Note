import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class WebDavStorage {
  WebDavStorage({
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
  }) : _prefs = prefs,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _serverUrlKey = 'webdav_server_url';
  static const _remotePathKey = 'webdav_remote_path';
  static const _autoSyncKey = 'webdav_auto_sync';
  static const _syncModeKey = 'webdav_sync_mode';
  static const _syncIntervalKey = 'webdav_sync_interval';
  static const _syncAttachmentsKey = 'webdav_sync_attachments';
  static const _lastSyncTimeKey = 'webdav_last_sync_time';
  static const _usernameKey = 'webdav_username';
  static const _passwordKey = 'webdav_password';
  static const _deviceIdKey = 'flashnote_device_id';

  static const defaultServerUrl = 'https://dav.jianguoyun.com/dav/';
  static const defaultRemotePath = '/FlashNote/';
  static const defaultSyncMode = 'merge';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  String get serverUrl => _prefs.getString(_serverUrlKey) ?? defaultServerUrl;

  String get remotePath =>
      _prefs.getString(_remotePathKey) ?? defaultRemotePath;

  bool get autoSync => _prefs.getBool(_autoSyncKey) ?? false;

  /// Sync mode: 'pull', 'push', or 'merge'
  String get syncMode => _prefs.getString(_syncModeKey) ?? defaultSyncMode;

  /// Sync interval in minutes: 0 = disabled, otherwise the interval
  int get syncIntervalMinutes => _prefs.getInt(_syncIntervalKey) ?? 0;

  bool get syncAttachments => _prefs.getBool(_syncAttachmentsKey) ?? false;

  int? get lastSyncTime => _prefs.getInt(_lastSyncTimeKey);

  Future<String?> get username => _secureStorage.read(key: _usernameKey);

  Future<String?> get password => _secureStorage.read(key: _passwordKey);

  /// 本机稳定身份，用于合并时对 updatedAt 相同的记录做确定性裁决。
  Future<String> getOrCreateDeviceId() async {
    final existing = _prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    await _prefs.setString(_deviceIdKey, created);
    return created;
  }

  Future<void> setServerUrl(String url) => _prefs.setString(_serverUrlKey, url);

  Future<void> setRemotePath(String path) =>
      _prefs.setString(_remotePathKey, path);

  Future<void> setAutoSync(bool value) => _prefs.setBool(_autoSyncKey, value);

  Future<void> setSyncMode(String mode) => _prefs.setString(_syncModeKey, mode);

  Future<void> setSyncIntervalMinutes(int minutes) =>
      _prefs.setInt(_syncIntervalKey, minutes);

  Future<void> setSyncAttachments(bool value) =>
      _prefs.setBool(_syncAttachmentsKey, value);

  Future<void> setLastSyncTime(int timestamp) =>
      _prefs.setInt(_lastSyncTimeKey, timestamp);

  Future<void> setUsername(String value) =>
      _secureStorage.write(key: _usernameKey, value: value);

  Future<void> setPassword(String value) =>
      _secureStorage.write(key: _passwordKey, value: value);

  Future<bool> get isConfigured async {
    final user = await username;
    final pass = await password;
    return user != null && user.isNotEmpty && pass != null && pass.isNotEmpty;
  }

  Future<void> clearAll() async {
    await _prefs.remove(_serverUrlKey);
    await _prefs.remove(_remotePathKey);
    await _prefs.remove(_autoSyncKey);
    await _prefs.remove(_syncModeKey);
    await _prefs.remove(_syncIntervalKey);
    await _prefs.remove(_syncAttachmentsKey);
    await _prefs.remove(_lastSyncTimeKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _passwordKey);
  }
}
