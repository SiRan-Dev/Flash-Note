import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flashnote/data/datasources/remote/webdav_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebDavClient download', () {
    test('GET 404 返回 null（只有 404 表示首次同步）', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response('', status: 404),
      );
      final client = _client(adapter);

      final result = await client.downloadData();

      expect(result, isNull);
      expect(adapter.requests.single.method, 'GET');
    });

    test('GET 401 抛 WebDavAuthException 而不是 null', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response('', status: 401),
      );
      final client = _client(adapter);

      await expectLater(
        client.downloadData(),
        throwsA(isA<WebDavAuthException>()),
      );
    });

    test('GET 403 抛 WebDavAuthException', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response('', status: 403),
      );
      final client = _client(adapter);

      await expectLater(
        client.downloadData(),
        throwsA(isA<WebDavAuthException>()),
      );
    });

    test('GET 302 不会被误判为 404，而是提示检查 serverUrl', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response('', status: 302),
      );
      final client = _client(adapter);

      await expectLater(
        client.downloadData(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('serverUrl'),
          ),
        ),
      );
    });

    test('200 空 body 中止下载且不返回空数据', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response(''),
      );
      final client = _client(adapter);

      await expectLater(
        client.downloadData(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('为空'),
          ),
        ),
      );
    });

    test('200 HTML body 中止下载，错误信息不含 body 片段', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response(
          '<html><body>login required</body></html>',
        ),
      );
      final client = _client(adapter);

      await expectLater(
        client.downloadData(),
        throwsA(
          isA<WebDavException>()
              .having((e) => e.message, 'message', contains('不是合法的 JSON'))
              .having((e) => e.message, 'message', isNot(contains('<html>'))),
        ),
      );
    });

    test('200 非对象 JSON 中止下载', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response('[]'),
      );
      final client = _client(adapter);

      await expectLater(
        client.downloadData(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('格式不正确'),
          ),
        ),
      );
    });

    test('暴露 ETag 与 Last-Modified 给调用方', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response(
          '{"version":6}',
          headers: {
            'etag': ['"v1"'],
            'last-modified': ['Wed, 21 Oct 2015 07:28:00 GMT'],
          },
        ),
      );
      final client = _client(adapter);

      final result = await client.downloadData();

      expect(result, isNotNull);
      expect(result!.data['version'], 6);
      expect(result.version.etag, '"v1"');
      expect(result.version.lastModified, 'Wed, 21 Oct 2015 07:28:00 GMT');
    });

    test('Content-Length 超限时直接中止，不读取 body', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response(
          '{}',
          headers: {
            'content-length': ['1000'],
          },
        ),
      );
      final client = _client(adapter, maxDownloadBytes: 10);

      await expectLater(
        client.downloadData(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('过大'),
          ),
        ),
      );
    });

    test('无 Content-Length 时按实际读取量中止（分块传输）', () async {
      final chunk = Uint8List.fromList(List.filled(10, 0x41));
      final adapter = _FakeAdapter(
        (options, body) async => ResponseBody(
          Stream.fromIterable([chunk, chunk]),
          200,
        ),
      );
      final client = _client(adapter, maxDownloadBytes: 10);

      await expectLater(
        client.downloadData(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('过大'),
          ),
        ),
      );
    });

    test('整体请求超时中止，不会无限等待', () async {
      final adapter = _FakeAdapter((options, body) async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return _response('{}');
      });
      final client = _client(
        adapter,
        requestTimeout: const Duration(milliseconds: 30),
      );

      await expectLater(
        client.downloadData(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('超时'),
          ),
        ),
      );
      // 等待后台的延迟请求结束，避免测试框架报告未完成的定时器。
      await Future<void>.delayed(const Duration(milliseconds: 180));
    });
  });

  group('WebDavClient write preconditions', () {
    test('首次创建使用 If-None-Match: *，且写路径不跟随重定向', () async {
      final adapter = _FakeAdapter((options, body) async {
        if (options.method == 'MKCOL') {
          return _response('', status: 201);
        }
        return _response('', status: 201);
      });
      final client = _client(adapter);

      await client.uploadData({'version': 6}, createOnly: true);

      final mkcol = adapter.requests.firstWhere((r) => r.method == 'MKCOL');
      final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(mkcol.followRedirects, isFalse);
      expect(put.followRedirects, isFalse);
      expect(put.headers['If-None-Match'], '*');
      expect(adapter.bodies.last, isNotEmpty);
    });

    test('已存在远端时使用 If-Match，412 归类为冲突', () async {
      final adapter = _FakeAdapter((options, body) async {
        if (options.method == 'MKCOL') {
          return _response('', status: 201);
        }
        return _response('', status: 412);
      });
      final client = _client(adapter);

      await expectLater(
        client.uploadData(
          {'version': 6},
          expectedVersion: const WebDavVersion(etag: '"v1"'),
        ),
        throwsA(isA<WebDavConflictException>()),
      );

      final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(put.headers['If-Match'], '"v1"');
      expect(put.headers['If-None-Match'], isNull);
    });

    test('弱 ETag 退化为 If-Unmodified-Since', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response('', status: 201),
      );
      final client = _client(adapter);

      await client.uploadData(
        {'version': 6},
        expectedVersion: const WebDavVersion(
          etag: 'W/"v1"',
          lastModified: 'Wed, 21 Oct 2015 07:28:00 GMT',
        ),
      );

      final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(put.headers['If-Match'], isNull);
      expect(
        put.headers['If-Unmodified-Since'],
        'Wed, 21 Oct 2015 07:28:00 GMT',
      );
    });

    test('PUT 302 不跟随、只发一次，并提示检查 serverUrl', () async {
      final adapter = _FakeAdapter((options, body) async {
        if (options.method == 'MKCOL') {
          return _response('', status: 201);
        }
        return _response('', status: 302);
      });
      final client = _client(adapter);

      await expectLater(
        client.uploadData({'version': 6}, createOnly: true),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('serverUrl'),
          ),
        ),
      );

      expect(
        adapter.requests.where((r) => r.method == 'PUT'),
        hasLength(1),
      );
    });

    test('MKCOL 302 失败并提示检查 serverUrl', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response('', status: 302),
      );
      final client = _client(adapter);

      await expectLater(
        client.ensureDirectory(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('serverUrl'),
          ),
        ),
      );
    });

    test('MKCOL 405 视为目录已存在', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response('', status: 405),
      );
      final client = _client(adapter);

      await client.ensureDirectory();
    });

    test('PUT 401 抛 WebDavAuthException', () async {
      final adapter = _FakeAdapter((options, body) async {
        if (options.method == 'MKCOL') {
          return _response('', status: 201);
        }
        return _response('', status: 401);
      });
      final client = _client(adapter);

      await expectLater(
        client.uploadData({'version': 6}, createOnly: true),
        throwsA(isA<WebDavAuthException>()),
      );
    });

    test('fetchVersion：404 返回 null，200 返回 ETag', () async {
      var call = 0;
      final adapter = _FakeAdapter((options, body) async {
        call++;
        if (call == 1) return _response('', status: 404);
        return _response('', headers: {'etag': ['"v1"']});
      });
      final client = _client(adapter);

      expect(await client.fetchVersion(), isNull);
      final version = await client.fetchVersion();
      expect(version?.etag, '"v1"');
    });

    test('fetchVersion：405 抛出带状态码的异常，供调用方降级', () async {
      final adapter = _FakeAdapter(
        (options, body) async => _response('', status: 405),
      );
      final client = _client(adapter);

      await expectLater(
        client.fetchVersion(),
        throwsA(
          isA<WebDavException>().having((e) => e.statusCode, 'statusCode', 405),
        ),
      );
    });
  });
}

WebDavClient _client(
  _FakeAdapter adapter, {
  Duration requestTimeout = const Duration(seconds: 5),
  int maxDownloadBytes = WebDavClient.defaultMaxDownloadBytes,
}) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return WebDavClient(
    serverUrl: 'https://dav.example.com/dav',
    username: 'user',
    password: 'pass',
    dio: dio,
    requestTimeout: requestTimeout,
    maxDownloadBytes: maxDownloadBytes,
  );
}

ResponseBody _response(
  String body, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) {
  return ResponseBody.fromString(body, status, headers: headers);
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, List<int> body)
  handler;
  final List<RequestOptions> requests = [];
  final List<List<int>> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.addAll(chunk);
      }
    }
    bodies.add(body);
    return await handler(options, body);
  }

  @override
  void close({bool force = false}) {}
}
