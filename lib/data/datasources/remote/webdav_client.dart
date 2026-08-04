import 'dart:convert';

import 'package:dio/dio.dart';

class WebDavClient {
  WebDavClient({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remotePath = '/FlashNote/',
  }) : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
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
      final response = await _dio.request(
        _directoryUrl,
        options: _authOptions.copyWith(
          method: 'PROPFIND',
          headers: {
            ..._authOptions.headers!,
            'Depth': '0',
          },
          responseType: ResponseType.plain,
        ),
      );
      if (response.statusCode == 207 || response.statusCode == 200) {
        return (true, 'OK');
      }
      return (false, 'HTTP ${response.statusCode}');
    } on DioException catch (e) {
      return (false, _formatDioError(e));
    }
  }

  /// Ensure the remote directory exists (MKCOL)
  Future<void> ensureDirectory() async {
    try {
      await _dio.request(
        _directoryUrl,
        options: _authOptions.copyWith(
          method: 'MKCOL',
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (e) {
      // 405 Method Not Allowed means directory already exists
      if (e.response?.statusCode == 405) return;
      // 201 Created or 301 also acceptable
      if (e.response?.statusCode == 201) return;
      rethrow;
    }
  }

  /// Upload JSON data to WebDAV
  Future<void> uploadData(Map<String, dynamic> data) async {
    await ensureDirectory();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(jsonStr);

    await _dio.request(
      _fileUrl,
      data: Stream.fromIterable([bytes]),
      options: _authOptions.copyWith(
        method: 'PUT',
        headers: {
          ..._authOptions.headers!,
          'Content-Type': 'application/json; charset=utf-8',
          'Content-Length': bytes.length.toString(),
        },
        responseType: ResponseType.plain,
      ),
    );
  }

  /// Download JSON data from WebDAV. Returns null if file doesn't exist.
  Future<Map<String, dynamic>?> downloadData() async {
    try {
      final response = await _dio.request(
        _fileUrl,
        options: _authOptions.copyWith(
          method: 'GET',
          responseType: ResponseType.plain,
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return jsonDecode(response.data as String) as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  String _formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时';
      case DioExceptionType.connectionError:
        return '网络连接失败';
      default:
        final code = e.response?.statusCode;
        if (code == 401) return '认证失败（用户名或密码错误）';
        if (code == 403) return '没有访问权限';
        if (code == 404) return '路径不存在';
        return 'HTTP ${code ?? "未知错误"}';
    }
  }
}
