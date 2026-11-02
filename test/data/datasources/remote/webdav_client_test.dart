import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flashnote/data/datasources/remote/webdav_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebDavClient download', () {
    test('指针与旧文件都不存在 -> null（只有 404 表示首次同步）', () async {
      final dav = _FakeDav();
      final client = _client(dav);

      final result = await client.downloadData();

      expect(result, isNull);
      expect(dav.requests.every((r) => r.method == 'GET'), isTrue);
      expect(dav.requests, hasLength(2));
    });

    test('GET 401 抛 WebDavAuthException 而不是 null', () async {
      final dav = _FakeDav()..unauthorizedStatus = 401;
      final client = _client(dav);

      await expectLater(
        client.downloadData(),
        throwsA(isA<WebDavAuthException>()),
      );
    });

    test('GET 403 抛 WebDavAuthException', () async {
      final dav = _FakeDav()..unauthorizedStatus = 403;
      final client = _client(dav);

      await expectLater(
        client.downloadData(),
        throwsA(isA<WebDavAuthException>()),
      );
    });

    test('GET 302 不会被误判为 404，而是提示检查 serverUrl', () async {
      final dav = _FakeDav()..legacyStatus = 302;
      final client = _client(dav);

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
      final dav = _FakeDav()..legacyBody = '';
      final client = _client(dav);

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
      final dav = _FakeDav()
        ..legacyBody = '<html><body>login required</body></html>';
      final client = _client(dav);

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
      final dav = _FakeDav()..legacyBody = '[]';
      final client = _client(dav);

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

    test('旧式文件路径：暴露 ETag/Last-Modified 给调用方', () async {
      final dav = _FakeDav();
      dav.seedLegacy(
        jsonEncode(_validSnapshot()),
        etag: '"v1"',
        lastModified: 'Wed, 21 Oct 2015 07:28:00 GMT',
      );
      final client = _client(dav);

      final result = await client.downloadData();

      expect(result, isNotNull);
      expect(result!.data['version'], 6);
      expect(result.publishState.mode, WebDavPublishMode.atomicMove);
      expect(result.publishState.version.etag, '"v1"');
      expect(
        result.publishState.version.lastModified,
        'Wed, 21 Oct 2015 07:28:00 GMT',
      );
    });

    test('指针文件存在时按指针读槽位', () async {
      final dav = _FakeDav();
      dav.seedPointer(slot: 'b', size: _validSnapshotBytes().length);
      dav.seedSlot('b', _validSnapshotBytes());
      final client = _client(dav);

      final result = await client.downloadData();

      expect(result, isNotNull);
      expect(result!.publishState.mode, WebDavPublishMode.dualSlotPointer);
      expect(result.publishState.activeSlot, 'b');
      final getNames = dav.requests
          .where((r) => r.method == 'GET')
          .map((r) => _name(r))
          .toList();
      expect(getNames, contains('flashnote_sync.pointer.json'));
      expect(getNames, contains('flashnote_sync.b.json'));
      expect(getNames, isNot(contains('flashnote_sync.json')));
    });

    test('指针指向的槽位长度不一致时中止', () async {
      final dav = _FakeDav();
      dav.seedPointer(slot: 'a', size: 999999);
      dav.seedSlot('a', _validSnapshotBytes());
      final client = _client(dav);

      await expectLater(
        client.downloadData(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('长度不一致'),
          ),
        ),
      );
    });

    test('指针文件本身非法时中止', () async {
      final dav = _FakeDav();
      dav.seedPointerRaw({'slot': 'x', 'size': 10});
      final client = _client(dav);

      await expectLater(
        client.downloadData(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('指针'),
          ),
        ),
      );
    });

    test('Content-Length 超限时直接中止，不读取 body', () async {
      final dav = _FakeDav()
        ..legacyBody = '{}'
        ..legacyDeclaredLength = 1000;
      final client = _client(dav, maxDownloadBytes: 10);

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
      final dav = _FakeDav()..legacyChunked = true;
      final client = _client(dav, maxDownloadBytes: 10);

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
      final dav = _FakeDav()..delay = const Duration(milliseconds: 150);
      final client = _client(
        dav,
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

  group('WebDavClient 原子发布', () {
    test('首次创建：临时对象 If-None-Match:* -> HEAD 校验 -> MOVE', () async {
      final dav = _FakeDav();
      final client = _client(dav);

      final result = await client.publishSnapshot(
        _validSnapshot(),
        const WebDavPublishState.firstSync(),
      );

      expect(result.mode, WebDavPublishMode.atomicMove);
      final puts = dav.requests.where((r) => r.method == 'PUT').toList();
      expect(puts, hasLength(1));
      expect(puts.single.headers['If-None-Match'], '*');
      expect(_name(puts.single), endsWith('.tmp'));
      expect(puts.single.followRedirects, isFalse);

      final moves = dav.requests.where((r) => r.method == 'MOVE').toList();
      expect(moves, hasLength(1));
      expect(moves.single.headers['Destination'], contains('flashnote_sync.json'));
      expect(moves.single.headers['Overwrite'], 'T');
      expect(moves.single.followRedirects, isFalse);
      expect(dav.files, contains('flashnote_sync.json'));
    });

    test('临时对象被截断 -> 中止并清理，正式文件保持旧版本', () async {
      final dav = _FakeDav()
        ..seedLegacy(jsonEncode(_validSnapshot()), etag: '"old"')
        ..truncateTempOnPut = true;
      final client = _client(dav);

      await expectLater(
        client.publishSnapshot(
          _validSnapshot(),
          const WebDavPublishState(
            mode: WebDavPublishMode.atomicMove,
            version: WebDavVersion(etag: '"old"'),
            remoteExists: true,
          ),
        ),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('长度'),
          ),
        ),
      );

      expect(dav.requests.any((r) => r.method == 'MOVE'), isFalse);
      expect(
        dav.files['flashnote_sync.json']?.etag,
        '"old"',
      );
      // 临时对象被清理。
      expect(
        dav.files.keys.where((k) => k.endsWith('.tmp')),
        isEmpty,
      );
    });

    test('MOVE 失败保留临时对象并给出明确错误', () async {
      final dav = _FakeDav()..moveStatus = 507;
      final client = _client(dav);

      await expectLater(
        client.publishSnapshot(
          _validSnapshot(),
          const WebDavPublishState.firstSync(),
        ),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('保留'),
          ),
        ),
      );

      expect(dav.requests.any((r) => r.method == 'DELETE'), isFalse);
      expect(
        dav.files.keys.where((k) => k.endsWith('.tmp')),
        hasLength(1),
      );
    });

    test('写入前发现正式文件已被其他设备创建 -> 412，不执行 MOVE', () async {
      final dav = _FakeDav()..simulateDestinationRace = true;
      final client = _client(dav);

      await expectLater(
        client.publishSnapshot(
          _validSnapshot(),
          const WebDavPublishState.firstSync(),
        ),
        throwsA(isA<WebDavConflictException>()),
      );

      expect(dav.requests.any((r) => r.method == 'MOVE'), isFalse);
      expect(dav.files['flashnote_sync.json']?.etag, '"other"');
    });

    test('MOVE 405/501 自动降级为双槽位 + 指针', () async {
      final dav = _FakeDav()..moveSupported = false;
      final client = _client(dav);

      final result = await client.publishSnapshot(
        _validSnapshot(),
        const WebDavPublishState.firstSync(),
      );

      expect(result.mode, WebDavPublishMode.dualSlotPointer);
      final putNames = dav.requests
          .where((r) => r.method == 'PUT')
          .map(_name)
          .toList();
      expect(putNames, contains('flashnote_sync.a.json'));
      expect(putNames, contains('flashnote_sync.pointer.json'));
      expect(dav.files.containsKey('flashnote_sync.json'), isFalse);
      expect(dav.files, contains('flashnote_sync.pointer.json'));
      expect(dav.files, contains('flashnote_sync.a.json'));
    });

    test('双槽位模式：写非活跃槽位并条件更新指针', () async {
      final dav = _FakeDav();
      dav.seedPointer(slot: 'a', size: _validSnapshotBytes().length);
      dav.seedSlot('a', _validSnapshotBytes());
      final client = _client(dav);

      final download = await client.downloadData();
      final result = await client.publishSnapshot(
        _validSnapshot(inspirations: [
          _inspiration(1, '新数据', 3000),
        ]),
        download!.publishState,
      );

      expect(result.mode, WebDavPublishMode.dualSlotPointer);
      final pointerPut = dav.requests.lastWhere(
        (r) => r.method == 'PUT' && _name(r) == 'flashnote_sync.pointer.json',
      );
      expect(pointerPut.headers['If-Match'], '"ptr1"');
      final pointer = jsonDecode(dav.files['flashnote_sync.pointer.json']!.text)
          as Map<String, dynamic>;
      expect(pointer['slot'], 'b');
      expect(dav.files.containsKey('flashnote_sync.b.json'), isTrue);
    });

    test('双槽位模式：指针被其他设备抢先更新 -> 412 中止', () async {
      final dav = _FakeDav();
      dav.seedPointer(slot: 'a', size: _validSnapshotBytes().length);
      dav.seedSlot('a', _validSnapshotBytes());
      final client = _client(dav);
      final download = await client.downloadData();

      dav.failPointerPut = true;
      await expectLater(
        client.publishSnapshot(
          _validSnapshot(inspirations: [
            _inspiration(1, '新数据', 3000),
          ]),
          download!.publishState,
        ),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('指针'),
          ),
        ),
      );
      // 旧指针仍然指向 a，远端不会读到一个未发布的槽位。
      final pointer = jsonDecode(dav.files['flashnote_sync.pointer.json']!.text)
          as Map<String, dynamic>;
      expect(pointer['slot'], 'a');
    });
  });
}

WebDavClient _client(
  _FakeDav dav, {
  Duration requestTimeout = const Duration(seconds: 5),
  int maxDownloadBytes = WebDavClient.defaultMaxDownloadBytes,
}) {
  final dio = Dio();
  dio.httpClientAdapter = dav;
  return WebDavClient(
    serverUrl: 'https://dav.example.com/dav',
    username: 'user',
    password: 'pass',
    dio: dio,
    requestTimeout: requestTimeout,
    maxDownloadBytes: maxDownloadBytes,
  );
}

String _name(RequestOptions options) => options.uri.pathSegments.last;

List<int> _validSnapshotBytes() => utf8.encode(jsonEncode(_validSnapshot()));

Map<String, dynamic> _validSnapshot({
  List<Map<String, dynamic>> inspirations = const [],
}) {
  return {
    'version': 6,
    'exportedAt': '2026-05-16T00:00:00.000',
    'inspirations': inspirations,
    'projects': <Map<String, dynamic>>[],
    'tasks': <Map<String, dynamic>>[],
    'customSources': <Map<String, dynamic>>[],
    'attachments': <Map<String, dynamic>>[],
    'chatMessages': <Map<String, dynamic>>[],
    'inspirationLinks': <Map<String, dynamic>>[],
    'clusters': <Map<String, dynamic>>[],
    'deletedRecords': <Map<String, dynamic>>[],
    'reports': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _inspiration(int id, String content, int timestamp) {
  return {
    'id': id,
    'content': content,
    'createdAt': timestamp,
    'updatedAt': timestamp,
    'isPinned': false,
  };
}

class _Item {
  _Item(this.bytes, {required this.etag});

  final List<int> bytes;
  final String etag;

  String get text => utf8.decode(bytes, allowMalformed: true);

  Map<String, List<String>> get headers => {
    'etag': [etag],
    'content-length': [bytes.length.toString()],
  };
}

/// 最小 WebDAV 假服务器，按发布协议模拟对象读写。
class _FakeDav implements HttpClientAdapter {
  final Map<String, _Item> files = {};
  final List<RequestOptions> requests = [];
  int _etagSeq = 0;

  bool moveSupported = true;
  int? moveStatus;
  bool truncateTempOnPut = false;
  bool simulateDestinationRace = false;
  bool failPointerPut = false;
  int? unauthorizedStatus;
  int? legacyStatus;
  String? legacyBody;
  int? legacyDeclaredLength;
  bool legacyChunked = false;
  Duration? delay;

  void seedLegacy(String body, {required String etag, String? lastModified}) {
    files['flashnote_sync.json'] = _Item(
      utf8.encode(body),
      etag: etag,
    );
    if (lastModified != null) {
      _lastModified['flashnote_sync.json'] = lastModified;
    }
  }

  void seedPointer({required String slot, required int size}) {
    files['flashnote_sync.pointer.json'] = _Item(
      utf8.encode(jsonEncode({'slot': slot, 'size': size})),
      etag: '"ptr1"',
    );
  }

  void seedPointerRaw(Map<String, dynamic> pointer) {
    files['flashnote_sync.pointer.json'] = _Item(
      utf8.encode(jsonEncode(pointer)),
      etag: '"ptr1"',
    );
  }

  void seedSlot(String slot, List<int> bytes) {
    files['flashnote_sync.$slot.json'] = _Item(bytes, etag: '"slot-$slot"');
  }

  final Map<String, String> _lastModified = {};

  Map<String, List<String>> _headersFor(String name) {
    final item = files[name];
    if (item == null) return const {};
    final headers = <String, List<String>>{
      'etag': [item.etag],
      'content-length': [item.bytes.length.toString()],
    };
    final lastModified = _lastModified[name];
    if (lastModified != null) headers['last-modified'] = [lastModified];
    return headers;
  }

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
    return await _handle(options, body);
  }

  Future<ResponseBody> _handle(RequestOptions options, List<int> body) async {
    final delay = this.delay;
    if (delay != null) await Future<void>.delayed(delay);
    if (unauthorizedStatus != null) {
      return _text('', unauthorizedStatus!);
    }

    final name = _name(options);
    switch (options.method) {
      case 'MKCOL':
        return _text('', 201);
      case 'MOVE':
        if (!moveSupported) return _text('', 405);
        if (moveStatus != null) return _text('', moveStatus!);
        final source = files[name];
        if (source == null) return _text('', 404);
        final destination = _destinationName(options);
        files[destination] = source;
        files.remove(name);
        return _text('', 201);
      case 'DELETE':
        files.remove(name);
        return _text('', 204);
      case 'GET':
        if (name == 'flashnote_sync.json') {
          if (legacyChunked) {
            final chunk = Uint8List.fromList(List.filled(10, 0x41));
            return ResponseBody(Stream.fromIterable([chunk, chunk]), 200);
          }
          if (legacyStatus != null) {
            return _text(legacyBody ?? '', legacyStatus!);
          }
          if (legacyBody != null) {
            final headers = <String, List<String>>{};
            if (legacyDeclaredLength != null) {
              headers['content-length'] = [legacyDeclaredLength.toString()];
            }
            return _text(legacyBody!, 200, headers: headers);
          }
        }
        final item = files[name];
        if (item == null) return _text('', 404);
        return ResponseBody.fromBytes(
          item.bytes,
          200,
          headers: _headersFor(name),
        );
      case 'HEAD':
        if (files[name] == null) return _text('', 404);
        return _text('', 200, headers: _headersFor(name));
      case 'PUT':
        final existing = files[name];
        final ifNoneMatch = options.headers['If-None-Match']?.toString();
        final ifMatch = options.headers['If-Match']?.toString();
        if (ifNoneMatch == '*' && existing != null) {
          return _text('', 412);
        }
        if (ifMatch != null && (existing == null || existing.etag != ifMatch)) {
          return _text('', 412);
        }
        if (failPointerPut && name == 'flashnote_sync.pointer.json') {
          return _text('', 412);
        }
        final stored = truncateTempOnPut && name.endsWith('.tmp')
            ? body.sublist(0, body.length ~/ 2)
            : body;
        final item = _Item(stored, etag: '"v${++_etagSeq}"');
        files[name] = item;
        if (simulateDestinationRace && name.endsWith('.tmp')) {
          files['flashnote_sync.json'] = _Item(
            utf8.encode(jsonEncode(_otherDeviceSnapshot())),
            etag: '"other"',
          );
        }
        return _text('', 201, headers: _headersFor(name));
    }
    return _text('', 405);
  }

  String _destinationName(RequestOptions options) {
    final destination = options.headers['Destination']?.toString();
    if (destination == null || destination.isEmpty) return '';
    return Uri.parse(destination).pathSegments.last;
  }

  ResponseBody _text(
    String body,
    int status, {
    Map<String, List<String>> headers = const {},
  }) {
    return ResponseBody.fromString(body, status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _otherDeviceSnapshot() {
  return _validSnapshot(
    inspirations: [_inspiration(9001, '其他设备的灵感', 3000)],
  );
}
