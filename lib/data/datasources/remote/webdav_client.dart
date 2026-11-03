import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

/// 快照发布模式。
enum WebDavPublishMode {
  /// 临时对象 + MOVE 原子替换正式文件。
  atomicMove,

  /// 服务器不支持 MOVE 时降级为双槽位 + 指针。
  dualSlotPointer,
}

extension WebDavPublishModeLabel on WebDavPublishMode {
  String get label {
    switch (this) {
      case WebDavPublishMode.atomicMove:
        return '原子发布';
      case WebDavPublishMode.dualSlotPointer:
        return '双槽位降级';
    }
  }
}

/// 远端文件的版本信息，用于条件写入与写后校验。
class WebDavVersion {
  const WebDavVersion({this.etag, this.lastModified, this.contentLength});

  final String? etag;
  final String? lastModified;
  final int? contentLength;

  bool get isEmpty =>
      etag == null && lastModified == null && contentLength == null;

  /// 弱 ETag（以 `W/` 开头）不能用于 If-Match（RFC 9110）。
  bool get hasStrongEtag {
    final value = etag;
    return value != null &&
        value.isNotEmpty &&
        !value.toUpperCase().startsWith('W/');
  }
}

/// 发布前从远端读到的状态，用于判断下一次写入走哪条路径。
class WebDavPublishState {
  const WebDavPublishState({
    required this.mode,
    required this.version,
    required this.remoteExists,
    this.activeSlot,
    this.revalidateDestination = true,
  });

  const WebDavPublishState.firstSync()
    : mode = WebDavPublishMode.atomicMove,
      version = const WebDavVersion(),
      remoteExists = false,
      activeSlot = null,
      revalidateDestination = true;

  final WebDavPublishMode mode;

  /// atomicMove 模式是正式文件版本；双槽位模式是指针文件版本。
  final WebDavVersion version;
  final bool remoteExists;

  /// 双槽位模式当前生效的槽位（a/b）。
  final String? activeSlot;

  /// 服务器不支持 HEAD 时无法做写入前复核，避免误判为首次同步。
  final bool revalidateDestination;
}

/// 下载结果：同步数据 + 下一次发布所需的状态。
class WebDavDownload {
  const WebDavDownload({
    required this.data,
    required this.publishState,
    this.fromLegacyFile = false,
  });

  final Map<String, dynamic> data;
  final WebDavPublishState publishState;

  /// 数据来自旧文件名（v5/v6），调用方应先升级格式，再把结果发布到 v7 文件。
  final bool fromLegacyFile;
}

/// 发布结果，供上层在同步结果里展示使用的模式。
class WebDavPublishResult {
  const WebDavPublishResult({required this.mode});

  final WebDavPublishMode mode;
}

/// WebDAV 客户端异常基类。
///
/// 消息面向用户，不包含请求头、响应体或凭据。
class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'WebDavException: $message';
}

/// 远端文件不存在（HTTP 404）。
class WebDavNotFoundException extends WebDavException {
  const WebDavNotFoundException([super.message = '远端文件不存在（HTTP 404）'])
    : super(statusCode: 404);
}

/// 条件写入失败（HTTP 412），说明远端已被其他设备修改。
class WebDavConflictException extends WebDavException {
  const WebDavConflictException([super.message = '远端文件已被其他设备修改（HTTP 412）'])
    : super(statusCode: 412);
}

/// 认证或授权失败（HTTP 401/403）。
class WebDavAuthException extends WebDavException {
  const WebDavAuthException(int statusCode, super.message)
    : super(statusCode: statusCode);
}

class WebDavClient {
  WebDavClient({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remotePath = '/FlashNote/',
    this.snapshotFileName = defaultSnapshotFileName,
    this.legacySnapshotFileName = defaultLegacySnapshotFileName,
    Dio? dio,
    this.requestTimeout = const Duration(minutes: 5),
    this.maxDownloadBytes = defaultMaxDownloadBytes,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               sendTimeout: const Duration(seconds: 120),
               transformTimeout: const Duration(seconds: 30),
             ),
           );

  /// 单个快照的下载/校验体积上限，默认 128 MiB。
  static const int defaultMaxDownloadBytes = 128 * 1024 * 1024;

  /// 新客户端专用的 v7 文件名；旧客户端只认 [defaultLegacySnapshotFileName]，
  /// 因此两边永远不会互相覆盖。
  static const String defaultSnapshotFileName = 'flashnote_sync_v7.json';
  static const String defaultLegacySnapshotFileName = 'flashnote_sync.json';

  /// 指针文件上限，正常只有几十字节。
  static const int _maxPointerBytes = 4096;

  static const List<String> _slotNames = ['a', 'b'];

  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;

  /// v7 主文件名，例如 `flashnote_sync_v7.json`。
  final String snapshotFileName;

  /// 只读回退的旧文件名；为 null 时不读取旧文件。
  final String? legacySnapshotFileName;

  final Duration requestTimeout;
  final int maxDownloadBytes;
  final Dio _dio;

  String get _baseUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;

  String get _fullPath {
    final path = remotePath.startsWith('/') ? remotePath : '/$remotePath';
    return path.endsWith('/') ? path : '$path/';
  }

  String _urlFor(String fileName) => '$_baseUrl$_fullPath$fileName';

  String get _fileBase => snapshotFileName.endsWith('.json')
      ? snapshotFileName.substring(0, snapshotFileName.length - 5)
      : snapshotFileName;

  String get _mainUrl => _urlFor(snapshotFileName);

  String? get _legacyUrl {
    final name = legacySnapshotFileName;
    return name == null ? null : _urlFor(name);
  }

  String? get _legacyFileBase {
    final name = legacySnapshotFileName;
    if (name == null) return null;
    return name.endsWith('.json') ? name.substring(0, name.length - 5) : name;
  }

  String? get _legacyPointerUrl {
    final base = _legacyFileBase;
    return base == null ? null : _urlFor('$base.pointer.json');
  }

  String? _legacySlotUrl(String slot) {
    final base = _legacyFileBase;
    return base == null ? null : _urlFor('$base.$slot.json');
  }

  String get _pointerUrl => _urlFor('$_fileBase.pointer.json');

  String _slotUrl(String slot) => _urlFor('$_fileBase.$slot.json');

  String _tempUrl() => _urlFor(
    '$_fileBase.${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}.tmp',
  );

  Options get _authOptions => Options(
    headers: {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    },
  );

  /// Test WebDAV connection by sending a PROPFIND request
  Future<(bool, String)> testConnection() async {
    try {
      final response = await _send(
        (token) => _dio.request(
          _urlFor(''),
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'PROPFIND',
            headers: {..._authOptions.headers!, 'Depth': '0'},
            responseType: ResponseType.plain,
            receiveDataWhenStatusError: false,
          ),
        ),
      );
      if (response.statusCode == 207 || response.statusCode == 200) {
        return (true, 'OK');
      }
      return (false, 'HTTP ${response.statusCode}');
    } on WebDavException catch (e) {
      return (false, e.message);
    }
  }

  /// Ensure the remote directory exists (MKCOL).
  ///
  /// Redirects are not followed: a redirected MKCOL would be replayed without
  /// its body and can leave the remote state inconsistent.
  Future<void> ensureDirectory() async {
    try {
      await _send(
        (token) => _dio.request(
          _urlFor(''),
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'MKCOL',
            responseType: ResponseType.plain,
            followRedirects: false,
            receiveDataWhenStatusError: false,
          ),
        ),
      );
    } on WebDavException catch (e) {
      // 405 Method Not Allowed 表示目录已存在（RFC 4918）。
      if (e.statusCode == 405) return;
      rethrow;
    }
  }

  /// 读取旧式正式文件的版本（HEAD）。返回 null 表示文件不存在。
  Future<WebDavVersion?> fetchVersion() => _head(_mainUrl);

  /// 轻量探测发布状态（不下载快照正文），用于“推送”。
  Future<WebDavPublishState> probePublishState() async {
    final pointer = await _readPointer(allowNotFound: true);
    if (pointer != null) {
      return WebDavPublishState(
        mode: WebDavPublishMode.dualSlotPointer,
        version: pointer.version,
        remoteExists: true,
        activeSlot: pointer.slot,
      );
    }

    try {
      final version = await _head(_mainUrl);
      if (version == null) {
        return const WebDavPublishState.firstSync();
      }
      return WebDavPublishState(
        mode: WebDavPublishMode.atomicMove,
        version: version,
        remoteExists: true,
      );
    } on WebDavException catch (e) {
      if (e.statusCode == 405 || e.statusCode == 501) {
        // 服务器不支持 HEAD：保留旧行为，跳过写入前复核。
        return const WebDavPublishState(
          mode: WebDavPublishMode.atomicMove,
          version: WebDavVersion(),
          remoteExists: true,
          revalidateDestination: false,
        );
      }
      rethrow;
    }
  }

  /// 原子发布快照。
  ///
  /// 正常路径：PUT 到临时对象 → HEAD 校验长度/ETag → MOVE 覆盖正式文件。
  /// MOVE 返回 405/501 时降级为双槽位 + 指针模式。
  Future<WebDavPublishResult> publishSnapshot(
    Map<String, dynamic> data,
    WebDavPublishState state,
  ) async {
    await ensureDirectory();
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));

    if (state.mode == WebDavPublishMode.dualSlotPointer) {
      return await _publishToSlots(bytes, state);
    }

    try {
      return await _publishWithMove(bytes, state);
    } on WebDavException catch (e) {
      if (e.statusCode == 405 || e.statusCode == 501) {
        return await _publishToSlots(
          bytes,
          const WebDavPublishState(
            mode: WebDavPublishMode.dualSlotPointer,
            version: WebDavVersion(),
            remoteExists: false,
          ),
        );
      }
      rethrow;
    }
  }

  /// 读取远端快照。
  ///
  /// 顺序：v7 指针 → v7 正式文件 → 旧指针（双槽位）→ 旧单文件 → 旧孤儿槽位。
  /// 旧数据全部只读，用于升级；v7 文件一旦写入，后续读取不会再碰旧文件。
  ///
  /// 旧指针先于旧单文件：旧客户端进入双槽位模式后只会更新槽位，正式单文件
  /// 停留在进入降级前的旧内容，槽位才是最新数据。
  Future<WebDavDownload?> downloadData() async {
    final pointer = await _readPointer(allowNotFound: true);
    if (pointer != null) {
      final slotDownload = await _downloadBytes(
        _slotUrl(pointer.slot),
        followRedirects: false,
        label: '远端同步快照',
      );
      if (slotDownload == null || slotDownload.bytes.length != pointer.size) {
        throw const WebDavException('远端同步指针指向的快照长度不一致，已中止（旧快照仍保留）');
      }
      final data = _requireSnapshot(slotDownload.bytes, label: '远端同步快照');

      return WebDavDownload(
        data: data,
        publishState: WebDavPublishState(
          mode: WebDavPublishMode.dualSlotPointer,
          version: pointer.version,
          remoteExists: true,
          activeSlot: pointer.slot,
        ),
      );
    }

    final mainDownload = await _downloadBytes(
      _mainUrl,
      allowNotFound: true,
      label: '远端同步快照',
    );
    if (mainDownload != null) {
      return WebDavDownload(
        data: _requireSnapshot(mainDownload.bytes, label: '远端同步快照'),
        publishState: WebDavPublishState(
          mode: WebDavPublishMode.atomicMove,
          version: mainDownload.version,
          remoteExists: true,
        ),
      );
    }

    return await _downloadLegacy();
  }

  /// 旧格式回退：旧指针（双槽位）→ 旧单文件 → 无指针的孤儿槽位。
  ///
  /// 返回值语义与 [_downloadLegacy] 相同：v7 目标文件尚不存在，调用方会把
  /// 升级结果按首次创建（If-None-Match: *）发布到 v7 文件。
  Future<WebDavDownload?> _downloadLegacy() async {
    final pointerUrl = _legacyPointerUrl;
    if (pointerUrl != null) {
      final pointer = await _readPointerAt(
        pointerUrl,
        allowNotFound: true,
        label: '远端旧同步指针',
      );
      if (pointer != null) {
        return await _downloadLegacySlot(pointer);
      }
    }

    final legacyUrl = _legacyUrl;
    if (legacyUrl != null) {
      final downloaded = await _downloadBytes(
        legacyUrl,
        allowNotFound: true,
        label: '远端旧同步文件',
      );
      if (downloaded != null) {
        return WebDavDownload(
          data: _requireSnapshot(downloaded.bytes, label: '远端旧同步文件'),
          publishState: const WebDavPublishState.firstSync(),
          fromLegacyFile: true,
        );
      }
    }

    return await _downloadOrphanLegacySlots();
  }

  /// 按旧指针读取激活槽位。长度不一致或解析失败都明确报错：指针声明的
  /// 就是最新数据，静默跳过等于弄丢用户的同步结果。
  Future<WebDavDownload> _downloadLegacySlot(_PointerDoc pointer) async {
    final slotUrl = _legacySlotUrl(pointer.slot);
    if (slotUrl == null) {
      throw const WebDavException('远端旧同步文件名配置不正确');
    }
    final slotDownload = await _downloadBytes(
      slotUrl,
      followRedirects: false,
      label: '远端旧同步槽位',
    );
    if (slotDownload == null) {
      throw const WebDavException('远端旧同步指针指向的槽位不存在，已中止');
    }
    if (slotDownload.bytes.length != pointer.size) {
      throw const WebDavException('远端旧同步指针指向的槽位长度不一致，已中止');
    }
    return WebDavDownload(
      data: _requireSnapshot(slotDownload.bytes, label: '远端旧同步槽位'),
      publishState: const WebDavPublishState.firstSync(),
      fromLegacyFile: true,
    );
  }

  /// 指针缺失时的兜底：两个旧槽位都下载，取时间（exportedAt）更新者，
  /// 并列时取版本号更大者；两个都解析失败则明确报错。
  Future<WebDavDownload?> _downloadOrphanLegacySlots() async {
    final candidates = <String, _DownloadedBytes>{};
    for (final slot in _slotNames) {
      final slotUrl = _legacySlotUrl(slot);
      if (slotUrl == null) return null;
      final downloaded = await _downloadBytes(
        slotUrl,
        allowNotFound: true,
        followRedirects: false,
        label: '远端旧同步槽位',
      );
      if (downloaded != null) candidates[slot] = downloaded;
    }
    if (candidates.isEmpty) return null;

    Map<String, dynamic>? best;
    for (final entry in candidates.entries) {
      // _requireSnapshot 解析失败会直接抛错：宁可中止也不静默丢数据。
      final parsed = _requireSnapshot(entry.value.bytes, label: '远端旧同步槽位');
      if (best == null || _snapshotNewer(parsed, best)) {
        best = parsed;
      }
    }

    return WebDavDownload(
      data: best!,
      publishState: const WebDavPublishState.firstSync(),
      fromLegacyFile: true,
    );
  }

  Future<WebDavPublishResult> _publishWithMove(
    List<int> bytes,
    WebDavPublishState state,
  ) async {
    final tempUrl = _tempUrl();
    try {
      final putResponse = await _putBytes(tempUrl, bytes, createOnly: true);
      final putVersion = _versionFrom(putResponse.headers);
      final head = await _head(tempUrl);
      _verifyWrittenObject(head, bytes.length, putVersion, '临时文件');

      if (state.revalidateDestination) {
        final current = await _head(_mainUrl);
        if (!_destinationUnchanged(current, state)) {
          throw const WebDavConflictException('远端文件已被其他设备修改');
        }
      }
    } on WebDavException {
      await _deleteBestEffort(tempUrl);
      rethrow;
    }

    try {
      await _send(
        (token) => _dio.request(
          tempUrl,
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'MOVE',
            headers: {
              ..._authOptions.headers!,
              'Destination': Uri.parse(_mainUrl).toString(),
              'Overwrite': 'T',
            },
            responseType: ResponseType.plain,
            followRedirects: false,
            receiveDataWhenStatusError: false,
          ),
        ),
      );
      return const WebDavPublishResult(mode: WebDavPublishMode.atomicMove);
    } on WebDavException catch (e) {
      if (e.statusCode == 405 || e.statusCode == 501) {
        await _deleteBestEffort(tempUrl);
        rethrow;
      }
      throw WebDavException(
        '${e.message}；临时文件已保留：${_fileNameOf(tempUrl)}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<WebDavPublishResult> _publishToSlots(
    List<int> bytes,
    WebDavPublishState state,
  ) async {
    final activeSlot = state.activeSlot;
    final targetSlot = activeSlot == null
        ? 'a'
        : (activeSlot == 'a' ? 'b' : 'a');

    // 写入前复核指针没有在读取后被其他设备改走。
    final before = await _readPointer(allowNotFound: true);
    _ensurePointerUnchanged(before, state);

    final slotUrl = _slotUrl(targetSlot);
    try {
      final putResponse = await _putBytes(slotUrl, bytes);
      final putVersion = _versionFrom(putResponse.headers);
      final head = await _head(slotUrl);
      _verifyWrittenObject(head, bytes.length, putVersion, '同步槽位 $targetSlot');
    } on WebDavException catch (e) {
      throw WebDavException(
        '双槽位写入失败（${e.message}），远端仍指向旧版本',
        statusCode: e.statusCode,
      );
    }

    // 写入期间指针若被其他设备更新，则本次发布失败，避免覆盖对方。
    final after = await _readPointer(allowNotFound: true);
    _ensurePointerUnchanged(after, state);

    final pointerBytes = utf8.encode(
      jsonEncode({
        'slot': targetSlot,
        'size': bytes.length,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );

    try {
      await _putBytes(
        _pointerUrl,
        pointerBytes,
        createOnly: activeSlot == null,
        expectedVersion: activeSlot == null ? null : after!.version,
      );
    } on WebDavException catch (e) {
      throw WebDavException(
        '指针更新失败（${e.message}），远端仍指向旧版本',
        statusCode: e.statusCode,
      );
    }

    return const WebDavPublishResult(mode: WebDavPublishMode.dualSlotPointer);
  }

  void _ensurePointerUnchanged(_PointerDoc? pointer, WebDavPublishState state) {
    final expectedSlot = state.activeSlot;
    if (expectedSlot == null) {
      if (pointer != null) {
        throw const WebDavConflictException('远端已被其他设备切换为指针模式');
      }
      return;
    }
    if (pointer == null) {
      throw const WebDavConflictException('远端同步指针已被其他设备删除');
    }
    if (pointer.slot != expectedSlot) {
      throw const WebDavConflictException('远端同步指针已被其他设备更新');
    }
    if (!_versionsEqual(state.version, pointer.version)) {
      throw const WebDavConflictException('远端同步指针已被其他设备更新');
    }
  }

  bool _versionsEqual(WebDavVersion expected, WebDavVersion actual) {
    if (expected.etag != null && actual.etag != null) {
      return expected.etag == actual.etag;
    }
    if (expected.lastModified != null && actual.lastModified != null) {
      return expected.lastModified == actual.lastModified;
    }
    // 没有可比较的验证器：退化为只比较槽位。
    return true;
  }

  Future<_PointerDoc?> _readPointer({required bool allowNotFound}) =>
      _readPointerAt(
        _pointerUrl,
        allowNotFound: allowNotFound,
        label: '远端同步指针',
      );

  Future<_PointerDoc?> _readPointerAt(
    String url, {
    required bool allowNotFound,
    required String label,
  }) async {
    final downloaded = await _downloadBytes(
      url,
      allowNotFound: allowNotFound,
      followRedirects: false,
      maxBytes: _maxPointerBytes,
      label: label,
    );
    if (downloaded == null) return null;

    final pointer = _requireMap(downloaded.bytes, label: label);
    final slot = pointer['slot'];
    final size = pointer['size'];
    if (slot is! String || !_slotNames.contains(slot)) {
      throw WebDavException('$label中的槽位无效');
    }
    if (size is! int || size <= 0) {
      throw WebDavException('$label中的长度无效');
    }
    return _PointerDoc(slot: slot, size: size, version: downloaded.version);
  }

  /// 快照新旧比较：先比 exportedAt，再比 version，用于孤儿旧槽位的兜底选择。
  static bool _snapshotNewer(
    Map<String, dynamic> candidate,
    Map<String, dynamic> current,
  ) {
    final candidateTime = _exportedAtMillis(candidate['exportedAt']);
    final currentTime = _exportedAtMillis(current['exportedAt']);
    if (candidateTime != currentTime) return candidateTime > currentTime;
    final candidateVersion = candidate['version'];
    final currentVersion = current['version'];
    if (candidateVersion is int && currentVersion is int) {
      return candidateVersion >= currentVersion;
    }
    return true;
  }

  static int _exportedAtMillis(Object? value) {
    if (value is! String) return 0;
    return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
  }

  Future<_DownloadedBytes?> _downloadBytes(
    String url, {
    bool allowNotFound = false,
    bool followRedirects = true,
    int? maxBytes,
    String label = '远端同步文件',
  }) async {
    final limit = maxBytes ?? maxDownloadBytes;
    try {
      final response = await _send(
        (token) => _dio.request(
          url,
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'GET',
            responseType: ResponseType.stream,
            followRedirects: followRedirects,
            receiveDataWhenStatusError: false,
          ),
        ),
      );
      final statusCode = response.statusCode;
      if (statusCode != 200) {
        throw WebDavException(
          '$label 读取失败（HTTP $statusCode）',
          statusCode: statusCode,
        );
      }

      final declaredLength = _contentLength(response.headers);
      if (declaredLength != null && declaredLength > limit) {
        throw _tooLargeException(limit, label);
      }

      final data = response.data;
      if (data is! ResponseBody) {
        throw WebDavException('$label 读取失败（响应格式不正确）');
      }

      final bytes = <int>[];
      try {
        await for (final chunk in data.stream) {
          if (bytes.length + chunk.length > limit) {
            throw _tooLargeException(limit, label);
          }
          bytes.addAll(chunk);
        }
      } on WebDavException {
        rethrow;
      } on DioException {
        rethrow;
      } catch (_) {
        throw WebDavException('读取 $label 失败');
      }

      if (bytes.isEmpty) {
        throw WebDavException('$label 为空');
      }

      return _DownloadedBytes(
        bytes: bytes,
        version: _versionFrom(response.headers),
      );
    } on WebDavNotFoundException {
      if (allowNotFound) return null;
      rethrow;
    }
  }

  Future<Response<dynamic>> _putBytes(
    String url,
    List<int> bytes, {
    bool createOnly = false,
    WebDavVersion? expectedVersion,
  }) {
    final headers = <String, dynamic>{
      ..._authOptions.headers!,
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': bytes.length.toString(),
    };
    if (createOnly) {
      headers['If-None-Match'] = '*';
    } else if (expectedVersion != null && expectedVersion.hasStrongEtag) {
      headers['If-Match'] = expectedVersion.etag;
    } else if (expectedVersion != null &&
        expectedVersion.lastModified != null) {
      headers['If-Unmodified-Since'] = expectedVersion.lastModified;
    }

    return _send(
      (token) => _dio.request(
        url,
        data: Stream.fromIterable([bytes]),
        cancelToken: token,
        options: _authOptions.copyWith(
          method: 'PUT',
          headers: headers,
          responseType: ResponseType.plain,
          followRedirects: false,
          receiveDataWhenStatusError: false,
        ),
      ),
    );
  }

  Future<WebDavVersion?> _head(String url) async {
    try {
      final response = await _send(
        (token) => _dio.request(
          url,
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'HEAD',
            responseType: ResponseType.plain,
            followRedirects: false,
            receiveDataWhenStatusError: false,
          ),
        ),
      );
      return _versionFrom(response.headers);
    } on WebDavNotFoundException {
      return null;
    }
  }

  Future<void> _deleteBestEffort(String url) async {
    try {
      await _send(
        (token) => _dio.request(
          url,
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'DELETE',
            followRedirects: false,
            receiveDataWhenStatusError: false,
          ),
        ),
      );
    } on WebDavException {
      // 清理失败不影响主流程。
    }
  }

  void _verifyWrittenObject(
    WebDavVersion? head,
    int expectedLength,
    WebDavVersion putVersion,
    String label,
  ) {
    if (head == null) {
      throw WebDavException('$label 写入校验失败（HEAD 未找到）');
    }
    final length = head.contentLength;
    if (length != null && length != expectedLength) {
      throw WebDavException('$label 写入校验失败（长度 $length != $expectedLength）');
    }
    if (putVersion.etag != null &&
        head.etag != null &&
        putVersion.etag != head.etag) {
      throw WebDavException('$label 写入校验失败（ETag 不一致）');
    }
    // 服务器既不返回长度也不返回 ETag 时无法校验，只能接受（降级）。
  }

  bool _destinationUnchanged(WebDavVersion? current, WebDavPublishState state) {
    if (!state.remoteExists) return current == null;
    final expected = state.version;

    if (state.revalidateDestination) {
      if (current == null) return false;
    }

    if (expected.etag != null && current?.etag != null) {
      return expected.etag == current!.etag;
    }
    if (expected.lastModified != null && current?.lastModified != null) {
      return expected.lastModified == current!.lastModified;
    }
    // 没有可比较的验证器：无法检测并发修改，放行（降级）。
    return true;
  }

  Map<String, dynamic> _requireSnapshot(
    List<int> bytes, {
    required String label,
  }) {
    final map = _requireMap(bytes, label: label);
    if (map['inspirations'] is! List) {
      throw WebDavException('$label 格式不正确');
    }
    return map;
  }

  Map<String, dynamic> _requireMap(List<int> bytes, {required String label}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      // 不使用原始 FormatException：它会携带源码片段并显示到界面上。
      throw WebDavException('$label 不是合法的 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw WebDavException('$label 格式不正确');
    }
    return decoded;
  }

  int? _contentLength(Headers headers) {
    final value = headers.value(Headers.contentLengthHeader);
    if (value == null) return null;
    return int.tryParse(value);
  }

  WebDavException _tooLargeException(int limit, String label) {
    final size = limit >= 1024 * 1024
        ? '${limit ~/ (1024 * 1024)} MB'
        : '${limit ~/ 1024} KB';
    return WebDavException('$label 过大（上限 $size），已中止下载');
  }

  WebDavVersion _versionFrom(Headers headers) {
    final etag = headers.value('etag');
    final lastModified = headers.value('last-modified');
    return WebDavVersion(
      etag: (etag == null || etag.isEmpty) ? null : etag,
      lastModified: (lastModified == null || lastModified.isEmpty)
          ? null
          : lastModified,
      contentLength: _contentLength(headers),
    );
  }

  String _fileNameOf(String url) {
    final segments = Uri.parse(url).pathSegments;
    return segments.isEmpty ? url : segments.last;
  }

  /// 整体请求超时兜底。Dio 的 receiveTimeout 只覆盖等待响应头，
  /// 无法覆盖响应体读取或上传卡住的情况。
  Future<T> _runWithDeadline<T>(
    Future<T> Function(CancelToken token) action,
  ) async {
    final token = CancelToken();
    final timer = Timer(requestTimeout, () {
      if (!token.isCancelled) token.cancel();
    });
    try {
      return await Future.any<T>([
        action(token),
        token.whenCancel.then<T>(
          (_) => throw const WebDavException('请求超时，已中止'),
        ),
      ]);
    } finally {
      timer.cancel();
    }
  }

  /// 统一把 DioException 转成领域异常，避免调用方再看到 Dio 类型。
  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function(CancelToken token) action,
  ) async {
    try {
      return await _runWithDeadline(action);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  WebDavException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.cancel:
        return const WebDavException('请求超时，已中止');
      case DioExceptionType.badCertificate:
        return const WebDavException('TLS 证书校验失败');
      case DioExceptionType.connectionError:
        return const WebDavException('网络连接失败');
      case DioExceptionType.badResponse:
        return _mapStatus(e.response?.statusCode);
      case DioExceptionType.unknown:
        final statusCode = e.response?.statusCode;
        if (statusCode != null) return _mapStatus(statusCode);
        return const WebDavException('网络请求失败');
    }
  }

  WebDavException _mapStatus(int? statusCode) {
    if (statusCode == null) {
      return const WebDavException('网络请求失败');
    }
    if (statusCode == 401) {
      return const WebDavAuthException(401, '认证失败（用户名或密码错误）');
    }
    if (statusCode == 403) {
      return const WebDavAuthException(403, '没有访问权限');
    }
    if (statusCode == 404) {
      return const WebDavNotFoundException();
    }
    if (statusCode == 412) {
      return const WebDavConflictException();
    }
    if (statusCode >= 300 && statusCode < 400) {
      return WebDavException(
        '服务器返回重定向（HTTP $statusCode），请检查 serverUrl（协议、域名或末尾斜杠）是否正确',
        statusCode: statusCode,
      );
    }
    return WebDavException('HTTP $statusCode', statusCode: statusCode);
  }
}

class _PointerDoc {
  const _PointerDoc({
    required this.slot,
    required this.size,
    required this.version,
  });

  final String slot;
  final int size;
  final WebDavVersion version;
}

class _DownloadedBytes {
  const _DownloadedBytes({required this.bytes, required this.version});

  final List<int> bytes;
  final WebDavVersion version;
}
