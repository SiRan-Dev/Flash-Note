import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flashnote/data/datasources/local/ai_settings_storage.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/webdav_storage.dart';
import 'package:flashnote/data/datasources/remote/webdav_client.dart';
import 'package:flashnote/data/services/webdav_sync_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WebDavSyncService service;
  late _FakeDav dav;

  Map<String, dynamic> snapshot({
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

  Map<String, dynamic> inspiration({
    required int id,
    required String content,
    required int createdAt,
  }) {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': createdAt,
      'isPinned': false,
    };
  }

  List<String> contentsOf(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return (data['inspirations'] as List)
        .cast<Map<String, dynamic>>()
        .map((i) => i['content'] as String)
        .toList();
  }

  String remoteJsonWith(String content) => jsonEncode(
    snapshot(
      inspirations: [inspiration(id: 2, content: content, createdAt: 2000)],
    ),
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    dav = _FakeDav();
    final dio = Dio();
    dio.httpClientAdapter = dav;

    final client = WebDavClient(
      serverUrl: 'https://dav.example.com/dav',
      username: 'user',
      password: 'pass',
      dio: dio,
    );

    service = WebDavSyncService(
      db: db,
      aiStorage: AiSettingsStorage(prefs: prefs),
      webdavStorage: WebDavStorage(prefs: prefs),
      clientFactory: () => client,
    );

    await db.insertInspiration(
      InspirationsCompanion.insert(
        content: '本地灵感',
        createdAt: 1000,
        updatedAt: 1000,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('首次同步', () {
    test('远端不存在 -> 临时对象 + MOVE，远端写入本地数据，本地不变', () async {
      final result = await service.mergeSync();

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('首次同步'));
      expect(result.message, contains('原子发布'));
      expect(result.publishMode, 'atomicMove');

      final put = dav.requests.lastWhere((r) => r.method == 'PUT');
      expect(_name(put), endsWith('.tmp'));
      expect(put.headers['If-None-Match'], '*');
      expect(dav.requests.any((r) => r.method == 'MOVE'), isTrue);

      expect(contentsOf(dav.files['flashnote_sync_v7.json']!.text), ['本地灵感']);
      final local = await db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
    });

    test('GET 404 后其他设备抢先创建 -> 412 中止，绝不覆盖远端', () async {
      dav.simulateDestinationRace = true;

      final result = await service.mergeSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('其他设备'));
      expect(dav.requests.any((r) => r.method == 'MOVE'), isFalse);
      expect(contentsOf(dav.files['flashnote_sync_v7.json']!.text), [
        '其他设备的灵感',
      ]);

      final local = await db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
    });
  });

  group('后续合并', () {
    test('远端被其他设备更新 -> 412 中止，远端与本地都不被覆盖', () async {
      dav.seedSnapshot(remoteJsonWith('远端灵感'), etag: '"v1"');
      dav.simulateDestinationRace = true;

      final result = await service.mergeSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('其他设备'));
      expect(contentsOf(dav.files['flashnote_sync_v7.json']!.text), [
        '其他设备的灵感',
      ]);

      final local = await db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
    });

    test('正常单设备合并 -> MOVE 原子替换，远端与本地都得到双方数据', () async {
      dav.seedSnapshot(remoteJsonWith('远端灵感'), etag: '"v1"');

      final result = await service.mergeSync();

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('合并同步成功'));
      expect(result.message, contains('原子发布'));
      expect(result.publishMode, 'atomicMove');
      expect(dav.requests.any((r) => r.method == 'MOVE'), isTrue);

      expect(
        contentsOf(dav.files['flashnote_sync_v7.json']!.text),
        containsAll(['本地灵感', '远端灵感']),
      );
      final local = await db.getAllInspirations();
      expect(local, hasLength(2));
      expect(local.map((i) => i.content), containsAll(['本地灵感', '远端灵感']));
    });

    test('PUT 中途断连 -> 临时对象被清理，正式文件仍是完整旧快照', () async {
      dav.seedSnapshot(remoteJsonWith('远端灵感'), etag: '"v1"');
      dav.truncateTempOnPut = true;

      final result = await service.mergeSync();

      expect(result.isSuccess, isFalse);
      expect(dav.requests.any((r) => r.method == 'MOVE'), isFalse);
      // 正式文件仍是合法的旧快照，没有被截断。
      final remote = dav.files['flashnote_sync_v7.json']!;
      expect(remote.text, isNotEmpty);
      expect(jsonDecode(remote.text), isA<Map<String, dynamic>>());
      expect(contentsOf(remote.text), ['远端灵感']);
      // 临时对象被清理。
      expect(dav.files.keys.where((k) => k.endsWith('.tmp')), isEmpty);

      final local = await db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
    });

    test('MOVE 405 -> 双槽位 + 指针降级，旧正式文件保持完好', () async {
      dav.seedSnapshot(remoteJsonWith('远端灵感'), etag: '"v1"');
      dav.moveSupported = false;

      final result = await service.mergeSync();

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('双槽位降级'));
      expect(result.publishMode, 'dualSlotPointer');
      expect(dav.requests.any((r) => r.method == 'MOVE'), isTrue);

      // 旧正式文件没有被改写，仍可被旧客户端读取。
      expect(contentsOf(dav.files['flashnote_sync_v7.json']!.text), ['远端灵感']);
      final pointer =
          jsonDecode(dav.files['flashnote_sync_v7.pointer.json']!.text)
              as Map<String, dynamic>;
      expect(pointer['slot'], 'a');
      expect(
        contentsOf(dav.files['flashnote_sync_v7.a.json']!.text),
        containsAll(['本地灵感', '远端灵感']),
      );

      final local = await db.getAllInspirations();
      expect(local, hasLength(2));
    });
  });

  group('指针读取', () {
    test('指针存在时按指针读槽位，而不是旧文件', () async {
      dav.seedPointer(
        slot: 'a',
        size: utf8.encode(remoteJsonWith('远端灵感')).length,
      );
      dav.seedSlot('a', utf8.encode(remoteJsonWith('远端灵感')));
      dav.seedSnapshot(remoteJsonWith('旧文件灵感'), etag: '"old"');

      final result = await service.pullFromRemote();

      expect(result.isSuccess, isTrue);
      final local = await db.getAllInspirations();
      // 拉取是覆盖本地语义：读到的是指针指向的槽位，而不是旧文件。
      expect(local, hasLength(1));
      expect(local.single.content, '远端灵感');
      expect(local.map((i) => i.content), isNot(contains('旧文件灵感')));
    });
  });

  group('推送', () {
    test('HEAD 探测后临时对象 + MOVE，单设备推送成功', () async {
      dav.seedSnapshot(remoteJsonWith('远端灵感'), etag: '"v1"');

      final result = await service.pushToRemote();

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('原子发布'));
      expect(result.publishMode, 'atomicMove');
      expect(dav.requests.any((r) => r.method == 'MOVE'), isTrue);
      expect(contentsOf(dav.files['flashnote_sync_v7.json']!.text), ['本地灵感']);
    });

    test('服务器不支持 HEAD 时跳过复核但继续原子发布', () async {
      dav.seedSnapshot(remoteJsonWith('远端灵感'), etag: '"v1"');
      dav.headFinalStatus = 405;

      final result = await service.pushToRemote();

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('原子发布'));
      expect(contentsOf(dav.files['flashnote_sync_v7.json']!.text), ['本地灵感']);
    });

    test('推送遇到其他设备写入 -> 中止且远端不变', () async {
      dav.seedSnapshot(remoteJsonWith('其他设备的灵感'), etag: '"v1"');
      dav.simulateDestinationRace = true;

      final result = await service.pushToRemote();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('其他设备'));
      expect(contentsOf(dav.files['flashnote_sync_v7.json']!.text), [
        '其他设备的灵感',
      ]);
    });
  });

  group('拉取', () {
    test('401 -> 失败且本地不变', () async {
      dav.unauthorizedStatus = 401;

      final result = await service.pullFromRemote();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('认证失败'));

      final local = await db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
    });
  });
}

String _name(RequestOptions options) => options.uri.pathSegments.last;

class _Item {
  _Item(this.bytes, {required this.etag});

  final List<int> bytes;
  final String etag;

  String get text => utf8.decode(bytes, allowMalformed: true);
}

class _FakeDav implements HttpClientAdapter {
  final Map<String, _Item> files = {};
  final List<RequestOptions> requests = [];
  int _etagSeq = 0;

  bool moveSupported = true;
  bool truncateTempOnPut = false;
  bool simulateDestinationRace = false;
  int? unauthorizedStatus;
  int? headFinalStatus;

  void seedSnapshot(String body, {required String etag}) {
    files['flashnote_sync_v7.json'] = _Item(utf8.encode(body), etag: etag);
  }

  void seedPointer({required String slot, required int size}) {
    files['flashnote_sync_v7.pointer.json'] = _Item(
      utf8.encode(jsonEncode({'slot': slot, 'size': size})),
      etag: '"ptr1"',
    );
  }

  void seedSlot(String slot, List<int> bytes) {
    files['flashnote_sync_v7.$slot.json'] = _Item(bytes, etag: '"slot-$slot"');
  }

  Map<String, List<String>> _headersFor(String name) {
    final item = files[name];
    if (item == null) return const {};
    return {
      'etag': [item.etag],
      'content-length': [item.bytes.length.toString()],
    };
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
    if (unauthorizedStatus != null) {
      return _text('', unauthorizedStatus!);
    }
    final name = _name(options);
    switch (options.method) {
      case 'MKCOL':
        return _text('', 201);
      case 'MOVE':
        if (!moveSupported) return _text('', 405);
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
        final item = files[name];
        if (item == null) return _text('', 404);
        return ResponseBody.fromBytes(
          item.bytes,
          200,
          headers: _headersFor(name),
        );
      case 'HEAD':
        if (name == 'flashnote_sync_v7.json' && headFinalStatus != null) {
          return _text('', headFinalStatus!);
        }
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
        final stored = truncateTempOnPut && name.endsWith('.tmp')
            ? body.sublist(0, body.length ~/ 2)
            : body;
        final item = _Item(stored, etag: '"v${++_etagSeq}"');
        files[name] = item;
        if (simulateDestinationRace && name.endsWith('.tmp')) {
          files['flashnote_sync_v7.json'] = _Item(
            utf8.encode(
              jsonEncode(
                _snapshot(inspirations: [_inspiration(9001, '其他设备的灵感', 3000)]),
              ),
            ),
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

Map<String, dynamic> _snapshot({
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
