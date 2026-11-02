import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// 远端文件的版本信息，用于条件写入（If-Match / If-Unmodified-Since）。
class WebDavVersion {
  const WebDavVersion({this.etag, this.lastModified});

  final String? etag;
  final String? lastModified;

  bool get isEmpty => etag == null && lastModified == null;

  /// 弱 ETag（以 `W/` 开头）不能用于 If-Match（RFC 9110）。
  bool get hasStrongEtag {
    final value = etag;
    return value != null &&
        value.isNotEmpty &&
        !value.toUpperCase().startsWith('W/');
  }
}

/// 下载结果：同步数据 + 远端版本。
class WebDavDownload {
  const WebDavDownload({required this.data, required this.version});

  final Map<String, dynamic> data;
  final WebDavVersion version;
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
  const WebDavConflictException([
    super.message = '远端文件已被其他设备修改（HTTP 412）',
  ]) : super(statusCode: 412);
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

  /// 下载体积上限，默认 128 MiB。超过后中止并给出明确错误，避免 OOM。
  static const int defaultMaxDownloadBytes = 128 * 1024 * 1024;

  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
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

  String get _fileUrl => '$_baseUrl${_fullPath}flashnote_sync.json';

  String get _directoryUrl => '$_baseUrl$_fullPath';

  Options get _authOptions => Options(
    headers: {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    },
  );

  /// Test WebDAV connection by sending a PROPFIND request
  Future<(bool, String)> testConnection() async {
    try {
      final response = await _runWithDeadline(
        (token) => _dio.request(
          _directoryUrl,
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'PROPFIND',
            headers: {
              ..._authOptions.headers!,
              'Depth': '0',
            },
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
    } on DioException catch (e) {
      return (false, _mapDioException(e).message);
    }
  }

  /// Ensure the remote directory exists (MKCOL).
  ///
  /// Redirects are not followed: a redirected MKCOL would be replayed without
  /// its body and can leave the remote state inconsistent.
  Future<void> ensureDirectory() async {
    try {
      await _runWithDeadline(
        (token) => _dio.request(
          _directoryUrl,
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'MKCOL',
            responseType: ResponseType.plain,
            followRedirects: false,
            receiveDataWhenStatusError: false,
          ),
        ),
      );
    } on DioException catch (e) {
      // 405 Method Not Allowed 表示目录已存在（RFC 4918）。
      if (e.response?.statusCode == 405) return;
      throw _mapDioException(e);
    }
  }

  /// 读取远端文件版本（HEAD）。返回 null 表示远端文件不存在。
  ///
  /// 服务器不支持 HEAD（405/501）时调用方可决定降级策略。
  Future<WebDavVersion?> fetchVersion() async {
    try {
      final response = await _runWithDeadline(
        (token) => _dio.request(
          _fileUrl,
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
    } on DioException catch (e) {
      final mapped = _mapDioException(e);
      if (mapped is WebDavNotFoundException) return null;
      throw mapped;
    }
  }

  /// Upload JSON data to WebDAV.
  ///
  /// [createOnly] sends `If-None-Match: *` so an existing remote file can
  /// never be overwritten by a "first sync" push.
  /// [expectedVersion] sends `If-Match` (or `If-Unmodified-Since` when only
  /// Last-Modified is available) so a concurrent modification fails with 412.
  Future<void> uploadData(
    Map<String, dynamic> data, {
    WebDavVersion? expectedVersion,
    bool createOnly = false,
  }) async {
    await ensureDirectory();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(jsonStr);

    final headers = <String, dynamic>{
      ..._authOptions.headers!,
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': bytes.length.toString(),
    };
    final version = expectedVersion;
    if (createOnly) {
      headers['If-None-Match'] = '*';
    } else if (version != null && version.hasStrongEtag) {
      headers['If-Match'] = version.etag;
    } else if (version != null && version.lastModified != null) {
      headers['If-Unmodified-Since'] = version.lastModified;
    }

    try {
      await _runWithDeadline(
        (token) => _dio.request(
          _fileUrl,
          data: Stream.fromIterable([bytes]),
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'PUT',
            headers: headers,
            responseType: ResponseType.plain,
            // 关键：PUT 不允许跟随重定向。Dart HttpClient 会把重定向后的
            // 请求体重置为空，跟随 3xx 可能用空 body 覆盖远端文件。
            followRedirects: false,
            receiveDataWhenStatusError: false,
          ),
        ),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Download JSON data from WebDAV.
  ///
  /// Returns null ONLY when the remote file does not exist (HTTP 404).
  /// Any other failure throws a [WebDavException] so callers never mistake it
  /// for a first-time sync.
  Future<WebDavDownload?> downloadData() async {
    try {
      return await _runWithDeadline((token) async {
        final response = await _dio.request(
          _fileUrl,
          cancelToken: token,
          options: _authOptions.copyWith(
            method: 'GET',
            responseType: ResponseType.stream,
            receiveDataWhenStatusError: false,
          ),
        );
        final statusCode = response.statusCode;
        if (statusCode != 200) {
          throw WebDavException(
            '远端同步文件读取失败（HTTP $statusCode）',
            statusCode: statusCode,
          );
        }

        final declaredLength = _contentLength(response.headers);
        if (declaredLength != null && declaredLength > maxDownloadBytes) {
          throw _tooLargeException();
        }

        final data = response.data;
        if (data is! ResponseBody) {
          throw const WebDavException('远端同步文件读取失败（响应格式不正确）');
        }

        final bytes = <int>[];
        try {
          await for (final chunk in data.stream) {
            if (bytes.length + chunk.length > maxDownloadBytes) {
              throw _tooLargeException();
            }
            bytes.addAll(chunk);
          }
        } on WebDavException {
          rethrow;
        } on DioException {
          rethrow;
        } catch (_) {
          throw const WebDavException('读取远端同步文件失败');
        }

        if (bytes.isEmpty) {
          throw const WebDavException('远端同步文件为空');
        }

        final text = utf8.decode(bytes, allowMalformed: true);
        dynamic decoded;
        try {
          decoded = jsonDecode(text);
        } on FormatException {
          // 不使用原始 FormatException：它会携带源码片段并显示到界面上。
          throw const WebDavException('远端同步文件不是合法的 JSON');
        }
        if (decoded is! Map<String, dynamic>) {
          throw const WebDavException('远端同步文件格式不正确');
        }

        return WebDavDownload(
          data: decoded,
          version: _versionFrom(response.headers),
        );
      });
    } on DioException catch (e) {
      final mapped = _mapDioException(e);
      if (mapped is WebDavNotFoundException) return null;
      throw mapped;
    }
  }

  int? _contentLength(Headers headers) {
    final value = headers.value(Headers.contentLengthHeader);
    if (value == null) return null;
    return int.tryParse(value);
  }

  WebDavException _tooLargeException() {
    final limitMb = maxDownloadBytes ~/ (1024 * 1024);
    return WebDavException('远端同步文件过大（上限 $limitMb MB），已中止下载');
  }

  WebDavVersion _versionFrom(Headers headers) {
    final etag = headers.value('etag');
    final lastModified = headers.value('last-modified');
    return WebDavVersion(
      etag: (etag == null || etag.isEmpty) ? null : etag,
      lastModified:
          (lastModified == null || lastModified.isEmpty)
              ? null
              : lastModified,
    );
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
