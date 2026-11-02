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
  late _FakeRemote remote;
  late _RecordingAdapter adapter;

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

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    remote = _FakeRemote();
    adapter = _RecordingAdapter(remote.handle);
    final dio = Dio();
    dio.httpClientAdapter = adapter;

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
    test('远端 404 → 用 If-None-Match 创建，远端写入本地数据，本地不变', () async {
      final result = await service.mergeSync();

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('首次同步'));
      expect(remote.putCount, 1);
      final put = adapter.requests.lastWhere((r) => r.method == 'PUT');
      expect(put.headers['If-None-Match'], '*');

      expect(remote.content, isNotNull);
      expect(contentsOf(remote.content!), ['本地灵感']);

      final local = await db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
    });

    test('远端在 GET 404 后被其他设备创建 → 412 中止，绝不覆盖远端', () async {
      remote.simulateCreateRace = true;

      final result = await service.mergeSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('其他设备'));
      expect(contentsOf(remote.content!), ['其他设备的灵感']);

      final local = await db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
    });
  });

  group('后续合并', () {
    test('远端被其他设备更新 → 412 中止，远端与本地都不被覆盖', () async {
      remote.content = jsonEncode(
        snapshot(
          inspirations: [
            inspiration(id: 2, content: '远端灵感', createdAt: 2000),
          ],
        ),
      );
      remote.etag = '"v1"';
      remote.rejectPut = true;

      final result = await service.mergeSync();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('其他设备'));
      expect(contentsOf(remote.content!), ['远端灵感']);

      final local = await db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
    });

    test('正常单设备合并 → 带 If-Match，远端与本地都得到双方数据', () async {
      remote.content = jsonEncode(
        snapshot(
          inspirations: [
            inspiration(id: 2, content: '远端灵感', createdAt: 2000),
          ],
        ),
      );
      remote.etag = '"v1"';

      final result = await service.mergeSync();

      expect(result.isSuccess, isTrue);
      final put = adapter.requests.lastWhere((r) => r.method == 'PUT');
      expect(put.headers['If-Match'], '"v1"');

      expect(contentsOf(remote.content!), containsAll(['本地灵感', '远端灵感']));
      final local = await db.getAllInspirations();
      expect(local, hasLength(2));
      expect(
        local.map((i) => i.content),
        containsAll(['本地灵感', '远端灵感']),
      );
    });
  });

  group('推送', () {
    test('HEAD 拿到 ETag 后带 If-Match，单设备推送成功', () async {
      remote.content = jsonEncode(snapshot());
      remote.etag = '"v1"';

      final result = await service.pushToRemote();

      expect(result.isSuccess, isTrue);
      final put = adapter.requests.lastWhere((r) => r.method == 'PUT');
      expect(put.headers['If-Match'], '"v1"');
      expect(contentsOf(remote.content!), ['本地灵感']);
    });

    test('服务器不支持 HEAD 时退回强制覆盖，保持旧行为', () async {
      remote.content = jsonEncode(snapshot());
      remote.headUnsupported = true;

      final result = await service.pushToRemote();

      expect(result.isSuccess, isTrue);
      final put = adapter.requests.lastWhere((r) => r.method == 'PUT');
      expect(put.headers['If-Match'], isNull);
      expect(put.headers['If-None-Match'], isNull);
      expect(contentsOf(remote.content!), ['本地灵感']);
    });

    test('推送遇到 412 → 中止且远端不变', () async {
      remote.content = jsonEncode(
        snapshot(
          inspirations: [
            inspiration(id: 2, content: '其他设备的灵感', createdAt: 2000),
          ],
        ),
      );
      remote.etag = '"v1"';
      remote.rejectPut = true;

      final result = await service.pushToRemote();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('其他设备'));
      expect(contentsOf(remote.content!), ['其他设备的灵感']);
    });
  });

  group('拉取', () {
    test('401 → 失败且本地不变', () async {
      remote.unauthorizedGet = true;

      final result = await service.pullFromRemote();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('认证失败'));

      final local = await db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
    });
  });
}

class _FakeRemote {
  String? content;
  String? etag;
  int putCount = 0;
  bool simulateCreateRace = false;
  bool rejectPut = false;
  bool headUnsupported = false;
  bool unauthorizedGet = false;

  static final String _otherDeviceContent = jsonEncode({
    'version': 6,
    'exportedAt': '2026-05-16T00:00:00.000',
    'inspirations': [
      {
        'id': 9,
        'content': '其他设备的灵感',
        'createdAt': 2000,
        'updatedAt': 2000,
        'isPinned': false,
      },
    ],
    'projects': <Map<String, dynamic>>[],
    'tasks': <Map<String, dynamic>>[],
    'customSources': <Map<String, dynamic>>[],
    'attachments': <Map<String, dynamic>>[],
    'chatMessages': <Map<String, dynamic>>[],
    'inspirationLinks': <Map<String, dynamic>>[],
    'clusters': <Map<String, dynamic>>[],
    'deletedRecords': <Map<String, dynamic>>[],
    'reports': <Map<String, dynamic>>[],
  });

  Map<String, List<String>> _versionHeaders() {
    final value = etag;
    return value == null ? const {} : {'etag': [value]};
  }

  Future<ResponseBody> handle(
    RequestOptions options,
    List<int> body,
  ) async {
    switch (options.method) {
      case 'MKCOL':
        return ResponseBody.fromString('', 201);
      case 'HEAD':
        if (headUnsupported) return ResponseBody.fromString('', 405);
        if (content == null) return ResponseBody.fromString('', 404);
        return ResponseBody.fromString('', 200, headers: _versionHeaders());
      case 'GET':
        if (unauthorizedGet) return ResponseBody.fromString('', 401);
        if (simulateCreateRace) {
          content = _otherDeviceContent;
          etag = '"other"';
          return ResponseBody.fromString('', 404);
        }
        if (content == null) return ResponseBody.fromString('', 404);
        return ResponseBody.fromString(
          content!,
          200,
          headers: _versionHeaders(),
        );
      case 'PUT':
        putCount++;
        if (rejectPut) return ResponseBody.fromString('', 412);
        final ifNoneMatch = options.headers['If-None-Match']?.toString();
        final ifMatch = options.headers['If-Match']?.toString();
        if (ifNoneMatch == '*' && content != null) {
          return ResponseBody.fromString('', 412);
        }
        if (ifMatch != null && content != null && ifMatch != etag) {
          return ResponseBody.fromString('', 412);
        }
        content = utf8.decode(body);
        etag = '"v$putCount"';
        return ResponseBody.fromString('', 201);
    }
    return ResponseBody.fromString('', 405);
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, List<int> body)
  handler;
  final List<RequestOptions> requests = [];

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
    return await handler(options, body);
  }

  @override
  void close({bool force = false}) {}
}
