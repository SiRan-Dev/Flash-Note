/// FlashNote WebDAV 真实服务器端到端测试。
///
/// 默认跳过；需要先启动 `tool/webdav_e2e/chaos_proxy.py` 与真实 WsgiDAV，
/// 然后设置环境变量：
///
///   FLASHNOTE_WEBDAV_SERVER=http://127.0.0.1:18081
///   FLASHNOTE_WEBDAV_PROXY=http://127.0.0.1:18082
///   FLASHNOTE_WEBDAV_USER=flashnote
///   FLASHNOTE_WEBDAV_PASSWORD=flashnote-pass
///   FLASHNOTE_WEBDAV_ROOT=`WsgiDAV 的 davroot 绝对路径`
///
/// 运行：
///   flutter test test/integration/webdav_live_test.dart
library;

import 'dart:convert';
import 'dart:io';
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
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

final String _envServer = Platform.environment['FLASHNOTE_WEBDAV_SERVER'] ?? '';
final String _envProxy = Platform.environment['FLASHNOTE_WEBDAV_PROXY'] ?? '';
final String _envRoot = Platform.environment['FLASHNOTE_WEBDAV_ROOT'] ?? '';
final String _envUser =
    Platform.environment['FLASHNOTE_WEBDAV_USER'] ?? 'flashnote';
final String _envPassword =
    Platform.environment['FLASHNOTE_WEBDAV_PASSWORD'] ?? 'flashnote-pass';

String? get _skipLive => _envServer.isEmpty || _envProxy.isEmpty
    ? '未设置 FLASHNOTE_WEBDAV_SERVER / FLASHNOTE_WEBDAV_PROXY，跳过真实服务器测试'
    : null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test 默认把全局 HttpClient 换成“所有请求返回 400”的 mock；
  // 本文件必须访问真实服务器，所以恢复默认实现。
  HttpOverrides.global = null;

  group('真实 WebDAV 端到端', () {
    test('基线探测：MKCOL / PUT / HEAD / ETag / 条件请求 / 401 / 3xx', () async {
      await _deleteRemote();

      final mkcol = await _raw('MKCOL', Uri.parse('$_envServer/FlashNote/'));
      _evidence('MKCOL /FlashNote/ -> ${mkcol.status}');
      expect(mkcol.status, anyOf(201, 405));

      final missing = await _raw('HEAD', _fileUri(_envServer));
      _evidence('HEAD missing -> ${missing.status}');
      expect(missing.status, 404);

      final put = await _raw(
        'PUT',
        _fileUri(_envServer),
        body: utf8.encode(
          jsonEncode(
            _snapshot(
              inspirations: [
                _inspiration(
                  '00000000-0000-4000-8000-000000000002',
                  '远端灵感',
                  2000,
                ),
              ],
            ),
          ),
        ),
      );
      final putEtag = put.firstHeader('etag');
      _evidence('PUT new -> ${put.status}, ETag=$putEtag');
      expect(put.status, 201);
      expect(putEtag, isNotNull);

      final head = await _raw('HEAD', _fileUri(_envServer));
      _evidence(
        'HEAD existing -> ${head.status}, ETag=${head.firstHeader('etag')}, '
        'Last-Modified=${head.firstHeader('last-modified')}, '
        'Content-Length=${head.firstHeader('content-length')}',
      );
      expect(head.status, 200);
      expect(head.firstHeader('etag'), isNotNull);
      expect(head.firstHeader('last-modified'), isNotNull);

      final get = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'GET existing -> ${get.status}, ETag=${get.firstHeader('etag')}',
      );
      expect(get.status, 200);
      expect(get.firstHeader('etag'), equals(head.firstHeader('etag')));

      final createOnly = await _raw(
        'PUT',
        _fileUri(_envServer),
        body: utf8.encode(jsonEncode(_snapshot())),
        extraHeaders: {'If-None-Match': '*'},
      );
      _evidence('PUT If-None-Match:* on existing -> ${createOnly.status}');
      expect(createOnly.status, 412);

      final stale = await _raw(
        'PUT',
        _fileUri(_envServer),
        body: utf8.encode(jsonEncode(_snapshot())),
        extraHeaders: {'If-Match': '"stale-etag"'},
      );
      _evidence('PUT If-Match:"stale-etag" -> ${stale.status}');
      expect(stale.status, 412);

      final matching = await _raw(
        'PUT',
        _fileUri(_envServer),
        body: utf8.encode(
          jsonEncode(
            _snapshot(
              inspirations: [
                _inspiration(
                  '00000000-0000-4000-8000-000000000002',
                  '远端灵感',
                  2000,
                ),
              ],
            ),
          ),
        ),
        extraHeaders: {'If-Match': putEtag!},
      );
      _evidence('PUT If-Match:current -> ${matching.status}');
      expect(matching.status, anyOf(200, 204));

      final wrongAuth = await _raw(
        'GET',
        _fileUri(_envServer),
        password: 'wrong-pass',
      );
      _evidence(
        'GET wrong password -> ${wrongAuth.status}, '
        'WWW-Authenticate=${wrongAuth.firstHeader('www-authenticate')}',
      );
      expect(wrongAuth.status, 401);
      expect(wrongAuth.firstHeader('www-authenticate'), isNotNull);

      final noSlash = await _raw(
        'GET',
        Uri.parse('$_envServer/FlashNote'),
        followRedirects: false,
      );
      _evidence(
        'GET /FlashNote (no slash) -> ${noSlash.status}, '
        'Location=${noSlash.firstHeader('location')}',
      );
      expect(noSlash.status, 301);
      expect(noSlash.firstHeader('location'), '/FlashNote/');

      final mkcolAgain = await _raw(
        'MKCOL',
        Uri.parse('$_envServer/FlashNote/'),
      );
      _evidence('MKCOL existing -> ${mkcolAgain.status}');
      expect(mkcolAgain.status, 405);
    }, skip: _skipLive);

    test('首次同步：远端 404 -> 临时对象 If-None-Match:* + MOVE 原子发布', () async {
      // 连目录一起删掉，验证真正的“远端不存在”场景（MKCOL 201）。
      await _raw('DELETE', Uri.parse('$_envServer/FlashNote/'));
      final ctx = await _makeCtx();

      final result = await ctx.service.mergeSync();
      final put = _lastRequest(ctx, 'PUT');
      final moves = ctx.recorder.requests
          .where((r) => r.method == 'MOVE')
          .toList();
      final remote = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'first sync result=${result.isSuccess} "${result.message}"\n'
        '  mode=${result.publishMode}\n'
        '  outgoing PUT ${put.uri.pathSegments.last} '
        'If-None-Match=${_header(put, 'If-None-Match')}\n'
        '  MOVE count=${moves.length}\n'
        '  remote status=${remote.status} ETag=${remote.firstHeader('etag')}\n'
        '  events=${ctx.recorder.events}',
      );

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('首次同步'));
      expect(result.message, contains('原子发布'));
      expect(result.publishMode, 'atomicMove');
      expect(put.uri.pathSegments.last, endsWith('.tmp'));
      expect(_header(put, 'If-None-Match'), '*');
      expect(moves, hasLength(1));
      expect(_header(moves.single, 'Overwrite'), 'T');
      expect(
        _header(moves.single, 'Destination'),
        endsWith('/FlashNote/flashnote_sync_v7.json'),
      );
      expect(
        ctx.recorder.events.any(
          (e) => e.startsWith('MKCOL ') && e.endsWith('-> 201'),
        ),
        isTrue,
      );
      expect(remote.status, 200);
      expect(_contents(remote.text), ['本地灵感']);

      final local = await ctx.db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');

      await ctx.dispose();
    }, skip: _skipLive);

    test('旧文件名隔离：远端只有 v6 旧文件 -> 升级并发布到 v7 文件，旧文件不动', () async {
      await _deleteRemote();
      await _raw('MKCOL', Uri.parse('$_envServer/FlashNote/'));
      final legacyBody = jsonEncode(
        _legacySnapshot(inspirations: [_legacyInspiration(2, '旧文件灵感', 2000)]),
      );
      await _raw(
        'PUT',
        _fileUri(_envServer, 'flashnote_sync.json'),
        body: utf8.encode(legacyBody),
      );
      final before = await _raw(
        'GET',
        _fileUri(_envServer, 'flashnote_sync.json'),
      );

      final ctx = await _makeCtx();
      final result = await ctx.service.mergeSync();
      final after = await _raw(
        'GET',
        _fileUri(_envServer, 'flashnote_sync.json'),
      );
      final v7 = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'legacy upgrade result=${result.isSuccess} "${result.message}"\n'
        '  v7 status=${v7.status} contents=${_contents(v7.text)}\n'
        '  legacy unchanged=${before.text == after.text}',
      );

      expect(result.isSuccess, isTrue);
      expect(v7.status, 200);
      expect(_contents(v7.text), containsAll(['本地灵感', '旧文件灵感']));
      // 旧客户端仍可能继续写旧文件，新客户端升级后不再覆盖它。
      expect(after.text, before.text);
      expect(
        ctx.recorder.events.any(
          (e) => e.startsWith('PUT ') && e.contains('/flashnote_sync.json'),
        ),
        isFalse,
      );

      await ctx.dispose();
    }, skip: _skipLive);

    test('旧双槽位：远端只有旧指针+槽位 -> 升级并发布到 v7 文件，之后不再读旧槽位', () async {
      await _deleteRemote();
      await _raw('MKCOL', Uri.parse('$_envServer/FlashNote/'));
      final slotBody = jsonEncode(
        _legacySnapshot(inspirations: [_legacyInspiration(3, '槽位灵感', 2500)]),
      );
      final slotBytes = utf8.encode(slotBody);
      await _raw(
        'PUT',
        _fileUri(_envServer, 'flashnote_sync.a.json'),
        body: slotBytes,
      );
      await _raw(
        'PUT',
        _fileUri(_envServer, 'flashnote_sync.pointer.json'),
        body: utf8.encode(jsonEncode({'slot': 'a', 'size': slotBytes.length})),
      );

      final ctx = await _makeCtx();
      final result = await ctx.service.mergeSync();
      final v7 = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'legacy slots upgrade result=${result.isSuccess} "${result.message}"\n'
        '  v7 status=${v7.status} contents=${_contents(v7.text)}',
      );

      expect(result.isSuccess, isTrue);
      expect(v7.status, 200);
      expect(_contents(v7.text), containsAll(['本地灵感', '槽位灵感']));
      await ctx.dispose();

      // v7 文件写入后，后续同步不再读取旧指针/旧槽位。
      final ctx2 = await _makeCtx();
      final second = await ctx2.service.mergeSync();
      expect(second.isSuccess, isTrue);
      expect(
        ctx2.recorder.events.any(
          (e) =>
              e.contains('/flashnote_sync.pointer.json') ||
              e.contains('/flashnote_sync.a.json'),
        ),
        isFalse,
      );
      await ctx2.dispose();
    }, skip: _skipLive);

    test('正常合并：两端各自新增 -> 临时对象 + MOVE，双方数据都在', () async {
      await _deleteRemote();
      await _seedRemote(
        _snapshot(
          inspirations: [
            _inspiration('00000000-0000-4000-8000-000000000002', '远端灵感', 2000),
          ],
        ),
      );
      final before = await _raw('HEAD', _fileUri(_envServer));
      final beforeEtag = before.firstHeader('etag');

      final ctx = await _makeCtx();
      final result = await ctx.service.mergeSync();
      final put = _lastRequest(ctx, 'PUT');
      final moves = ctx.recorder.requests
          .where((r) => r.method == 'MOVE')
          .toList();
      final remote = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'merge result=${result.isSuccess} "${result.message}"\n'
        '  mode=${result.publishMode}\n'
        '  HEAD ETag=$beforeEtag\n'
        '  outgoing PUT ${put.uri.pathSegments.last}\n'
        '  MOVE count=${moves.length}\n'
        '  remote ETag=${remote.firstHeader('etag')}\n'
        '  events=${ctx.recorder.events}',
      );

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('合并同步成功'));
      expect(result.message, contains('原子发布'));
      expect(result.publishMode, 'atomicMove');
      expect(put.uri.pathSegments.last, endsWith('.tmp'));
      expect(_header(put, 'If-None-Match'), '*');
      expect(moves, hasLength(1));
      expect(_header(moves.single, 'Overwrite'), 'T');
      expect(_contents(remote.text), containsAll(['本地灵感', '远端灵感']));

      final local = await ctx.db.getAllInspirations();
      expect(local, hasLength(2));
      expect(local.map((i) => i.content), containsAll(['本地灵感', '远端灵感']));

      await ctx.dispose();
    }, skip: _skipLive);

    test('并发冲突：GET 之后另一客户端写入 -> 412 中止，本地与远端均不被覆盖', () async {
      await _deleteRemote();
      await _seedRemote(
        _snapshot(
          inspirations: [
            _inspiration('00000000-0000-4000-8000-000000000002', '远端灵感', 2000),
          ],
        ),
      );

      final ctx = await _makeCtx(serverUrl: '$_envProxy/race');
      final result = await ctx.service.mergeSync();
      final put = _lastRequest(ctx, 'PUT');
      final remote = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'race result=${result.isSuccess} "${result.message}"\n'
        '  outgoing If-Match=${_header(put, 'If-Match')}\n'
        '  remote status=${remote.status} ETag=${remote.firstHeader('etag')}\n'
        '  remote contents=${_contents(remote.text)}\n'
        '  events=${ctx.recorder.events}',
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('其他设备'));
      expect(_contents(remote.text), ['另一台设备写入的灵感']);
      // 旧实现会在 PUT 上得到 412；新实现先写临时对象，冲突在 MOVE 前的
      // 正式文件复核阶段被发现，因此这里断言没有 MOVE。
      expect(ctx.recorder.requests.any((r) => r.method == 'MOVE'), isFalse);

      final local = await ctx.db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');

      await ctx.dispose();
    }, skip: _skipLive);

    test('网络中断：PUT 中途断连 -> 远端仍是合法完整快照', () async {
      await _deleteRemote();
      await _seedRemote(
        _snapshot(
          inspirations: [
            _inspiration('00000000-0000-4000-8000-000000000002', '远端灵感', 2000),
          ],
        ),
      );

      final ctx = await _makeCtx(serverUrl: '$_envProxy/cut');
      final result = await ctx.service.mergeSync();
      // 故障代理会先断开客户端、再等 0.3s 断开上游；等服务器收尾后再读远端，
      // 否则可能读到“正在写入/已截断”的中间状态。
      await Future<void>.delayed(const Duration(seconds: 1));
      final after = await _raw('GET', _fileUri(_envServer));
      final remoteValid = _isValidSnapshot(after.text);
      _evidence(
        'cut result=${result.isSuccess} "${result.message}"\n'
        '  local count=${(await ctx.db.getAllInspirations()).length}\n'
        '  remote status=${after.status} bytes=${after.bytes.length} '
        'validJson=$remoteValid\n'
        '  remote prefix=${_preview(after.text)}\n'
        '  events=${ctx.recorder.events}',
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('失败'));

      final local = await ctx.db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');

      // 新实现先写临时对象：中途断连只会截断临时对象，正式文件必须仍是
      // 合法 JSON，且内容要么是旧完整快照，要么是新的完整快照。
      expect(after.status, 200);
      expect(_isValidSnapshot(after.text), isTrue);
      final contents = _contents(after.text);
      expect(contents, anyOf(equals(['远端灵感']), containsAll(['本地灵感', '远端灵感'])));
      expect(ctx.recorder.requests.any((r) => r.method == 'MOVE'), isFalse);

      await ctx.dispose();
    }, skip: _skipLive);

    test('认证失败：错误密码 -> 明确 401，绝不当作首次同步推送', () async {
      await _deleteRemote();
      final ctx = await _makeCtx(password: 'wrong-pass');
      final merge = await ctx.service.mergeSync();
      final afterMerge = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'wrong password merge=${merge.isSuccess} "${merge.message}"\n'
        '  remote status=${afterMerge.status}\n'
        '  events=${ctx.recorder.events}',
      );

      expect(merge.isSuccess, isFalse);
      expect(merge.message, contains('认证失败'));
      expect(afterMerge.status, 404);
      expect(ctx.recorder.events.any((e) => e.contains('PUT')), isFalse);
      final local = await ctx.db.getAllInspirations();
      expect(local, hasLength(1));
      expect(local.single.content, '本地灵感');
      await ctx.dispose();

      final pushCtx = await _makeCtx(password: 'wrong-pass');
      final push = await pushCtx.service.pushToRemote();
      final afterPush = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'wrong password push=${push.isSuccess} "${push.message}"\n'
        '  remote status=${afterPush.status}\n'
        '  events=${pushCtx.recorder.events}',
      );
      expect(push.isSuccess, isFalse);
      expect(push.message, contains('认证失败'));
      expect(afterPush.status, 404);
      expect(pushCtx.recorder.events.any((e) => e.contains('PUT')), isFalse);
      await pushCtx.dispose();
    }, skip: _skipLive);

    test('重定向：GET 正常但 PUT 302 -> 报 serverUrl 错误，远端不被空 body 覆盖', () async {
      await _deleteRemote();
      await _seedRemote(
        _snapshot(
          inspirations: [
            _inspiration('00000000-0000-4000-8000-000000000002', '远端灵感', 2000),
          ],
        ),
      );
      final before = await _raw('GET', _fileUri(_envServer));

      final ctx = await _makeCtx(serverUrl: '$_envProxy/redirectput');
      final result = await ctx.service.mergeSync();
      final after = await _raw('GET', _fileUri(_envServer));
      final putCount = ctx.recorder.events
          .where((e) => e.startsWith('PUT '))
          .length;
      _evidence(
        'redirect result=${result.isSuccess} "${result.message}"\n'
        '  PUT attempts=$putCount\n'
        '  remote before ETag=${before.firstHeader('etag')} '
        'after ETag=${after.firstHeader('etag')}\n'
        '  remote identical=${before.text == after.text}\n'
        '  events=${ctx.recorder.events}',
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('serverUrl'));
      expect(putCount, 1);
      expect(
        ctx.recorder.events.any((e) => e.contains('PUT') && e.contains('302')),
        isTrue,
      );
      expect(after.text, before.text);
      expect(after.firstHeader('etag'), before.firstHeader('etag'));

      final local = await ctx.db.getAllInspirations();
      expect(local, hasLength(1));
      await ctx.dispose();
    }, skip: _skipLive);

    test(
      '大文件：远端超过 128 MiB -> 明确拒绝且内存不随文件增长',
      () async {
        final file = File(
          p.join(_envRoot, 'FlashNote', 'flashnote_sync_v7.json'),
        );
        final dio = Dio();
        addTearDown(() async {
          // 客户端提前中止 129 MiB 响应后，服务器可能仍持有文件句柄；
          // 强制关闭连接并重试删除，避免把清理失败误报成场景失败。
          dio.close(force: true);
          for (var attempt = 0; attempt < 20; attempt++) {
            if (!await file.exists()) return;
            try {
              await file.delete();
              return;
            } on FileSystemException {
              await Future<void>.delayed(const Duration(milliseconds: 200));
            }
          }
        });
        await file.parent.create(recursive: true);
        await _deleteRemote();
        final raf = await file.open(mode: FileMode.write);
        final chunk = Uint8List(1024 * 1024)..fillRange(0, 1024 * 1024, 0x41);
        for (var i = 0; i < 129; i++) {
          await raf.writeFrom(chunk);
        }
        await raf.close();

        final head = await _raw('HEAD', _fileUri(_envServer));
        final declared = int.tryParse(head.firstHeader('content-length') ?? '');
        final rssBefore = _currentRss();
        final client = WebDavClient(
          serverUrl: _envServer,
          username: _envUser,
          password: _envPassword,
          dio: dio,
          requestTimeout: const Duration(seconds: 30),
        );
        final stopwatch = Stopwatch()..start();
        final error = await client.downloadData().then<Object?>(
          (_) => null,
          onError: (Object e) => e,
        );
        stopwatch.stop();
        final rssAfter = _currentRss();
        dio.close(force: true);
        _evidence(
          'large file HEAD=${head.status} Content-Length=$declared\n'
          '  result=${error.runtimeType}: '
          '${error is WebDavException ? error.message : error}\n'
          '  elapsed=${stopwatch.elapsedMilliseconds}ms '
          'rssBefore=$rssBefore rssAfter=$rssAfter',
        );

        expect(head.status, 200);
        expect(declared, greaterThan(128 * 1024 * 1024));
        expect(error, isA<WebDavException>());
        expect((error! as WebDavException).message, contains('过大'));
        if (rssBefore != null && rssAfter != null) {
          expect(rssAfter - rssBefore, lessThan(64 * 1024 * 1024));
        }
      },
      skip:
          _skipLive?.toString() ??
          (_envRoot.isEmpty ? '未设置 FLASHNOTE_WEBDAV_ROOT，跳过大文件测试' : null),
    );

    test('服务器不返回 ETag：退化为无条件 PUT，合并结果可预期', () async {
      await _deleteRemote();
      await _seedRemote(
        _snapshot(
          inspirations: [
            _inspiration('00000000-0000-4000-8000-000000000002', '远端灵感', 2000),
          ],
        ),
      );
      final head = await _raw(
        'HEAD',
        Uri.parse('$_envProxy/noetag/FlashNote/flashnote_sync_v7.json'),
      );
      _evidence(
        'noetag HEAD -> ${head.status}, ETag=${head.firstHeader('etag')}, '
        'Last-Modified=${head.firstHeader('last-modified')}',
      );
      expect(head.firstHeader('etag'), isNull);
      expect(head.firstHeader('last-modified'), isNull);

      final ctx = await _makeCtx(serverUrl: '$_envProxy/noetag');
      final result = await ctx.service.mergeSync();
      final put = _lastRequest(ctx, 'PUT');
      final remote = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'noetag merge=${result.isSuccess} "${result.message}"\n'
        '  outgoing If-Match=${_header(put, 'If-Match')} '
        'If-Unmodified-Since=${_header(put, 'If-Unmodified-Since')}\n'
        '  remote contents=${_contents(remote.text)}\n'
        '  events=${ctx.recorder.events}',
      );

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('原子发布'));
      expect(result.publishMode, 'atomicMove');
      expect(_header(put, 'If-Match'), isNull);
      expect(_header(put, 'If-Unmodified-Since'), isNull);
      expect(ctx.recorder.requests.any((r) => r.method == 'MOVE'), isTrue);
      expect(_contents(remote.text), containsAll(['本地灵感', '远端灵感']));

      final local = await ctx.db.getAllInspirations();
      expect(local, hasLength(2));
      await ctx.dispose();
    }, skip: _skipLive);

    test('MOVE 405 -> 双槽位降级，指针驱动后续读取', () async {
      await _deleteRemote();
      await _seedRemote(
        _snapshot(
          inspirations: [
            _inspiration('00000000-0000-4000-8000-000000000002', '远端灵感', 2000),
          ],
        ),
      );

      final ctx = await _makeCtx(serverUrl: '$_envProxy/nomove');
      final first = await ctx.service.mergeSync();
      final pointer = await _raw(
        'GET',
        _fileUri(_envServer, 'flashnote_sync_v7.pointer.json'),
      );
      final slotA = await _raw(
        'GET',
        _fileUri(_envServer, 'flashnote_sync_v7.a.json'),
      );
      final mainFile = await _raw('GET', _fileUri(_envServer));
      _evidence(
        'nomove first=${first.isSuccess} "${first.message}"\n'
        '  mode=${first.publishMode}\n'
        '  pointer=${pointer.text}\n'
        '  slotA=${_contents(slotA.text)}\n'
        '  main=${_contents(mainFile.text)}\n'
        '  events=${ctx.recorder.events}',
      );

      expect(first.isSuccess, isTrue);
      expect(first.message, contains('双槽位降级'));
      expect(first.publishMode, 'dualSlotPointer');
      expect(pointer.status, 200);
      final pointerJson = jsonDecode(pointer.text) as Map<String, dynamic>;
      expect(pointerJson['slot'], 'a');
      expect(pointerJson['size'], utf8.encode(slotA.text).length);
      expect(_contents(slotA.text), containsAll(['本地灵感', '远端灵感']));
      // v7 正式文件保持完好，指针模式失败时仍有可读的旧版本。
      expect(_contents(mainFile.text), ['远端灵感']);

      final second = await ctx.service.mergeSync();
      final pointer2 = await _raw(
        'GET',
        _fileUri(_envServer, 'flashnote_sync_v7.pointer.json'),
      );
      final slotB = await _raw(
        'GET',
        _fileUri(_envServer, 'flashnote_sync_v7.b.json'),
      );
      final pointerJson2 = jsonDecode(pointer2.text) as Map<String, dynamic>;
      _evidence(
        'nomove second=${second.isSuccess} "${second.message}"\n'
        '  mode=${second.publishMode}\n'
        '  pointer=${pointer2.text}\n'
        '  slotB=${_contents(slotB.text)}',
      );

      expect(second.isSuccess, isTrue);
      expect(second.publishMode, 'dualSlotPointer');
      expect(pointerJson2['slot'], 'b');
      expect(_contents(slotB.text), containsAll(['本地灵感', '远端灵感']));

      await ctx.dispose();
    }, skip: _skipLive);
  }, skip: _skipLive);
}

Uri _fileUri(String base, [String name = 'flashnote_sync_v7.json']) {
  final normalized = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  return Uri.parse('$normalized/FlashNote/$name');
}

Map<String, dynamic> _snapshot({
  List<Map<String, dynamic>> inspirations = const [],
}) {
  return {
    'version': 7,
    'deviceId': 'device-remote',
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

Map<String, dynamic> _inspiration(String uuid, String content, int timestamp) {
  return {
    'uuid': uuid,
    'content': content,
    'createdAt': timestamp,
    'updatedAt': timestamp,
    'isPinned': false,
  };
}

Map<String, dynamic> _legacySnapshot({
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

Map<String, dynamic> _legacyInspiration(int id, String content, int timestamp) {
  return {
    'id': id,
    'content': content,
    'createdAt': timestamp,
    'updatedAt': timestamp,
    'isPinned': false,
  };
}

List<String> _contents(String jsonText) {
  final data = jsonDecode(jsonText) as Map<String, dynamic>;
  return (data['inspirations'] as List)
      .cast<Map<String, dynamic>>()
      .map((i) => i['content'] as String)
      .toList();
}

bool _isValidSnapshot(String text) {
  try {
    final value = jsonDecode(text);
    return value is Map<String, dynamic> && value['inspirations'] is List;
  } catch (_) {
    return false;
  }
}

String _preview(String text) {
  final flat = text.replaceAll('\n', ' ');
  return flat.length <= 120 ? flat : '${flat.substring(0, 120)}...';
}

Future<void> _deleteRemote() async {
  // 删除所有发布形态，保证每个用例从干净状态开始。
  for (final name in [
    'flashnote_sync_v7.json',
    'flashnote_sync_v7.pointer.json',
    'flashnote_sync_v7.a.json',
    'flashnote_sync_v7.b.json',
    'flashnote_sync.json',
    'flashnote_sync.pointer.json',
    'flashnote_sync.a.json',
    'flashnote_sync.b.json',
  ]) {
    await _raw('DELETE', _fileUri(_envServer, name));
  }
}

Future<void> _seedRemote(Map<String, dynamic> snapshot) async {
  await _raw('MKCOL', Uri.parse('$_envServer/FlashNote/'));
  await _raw(
    'PUT',
    _fileUri(_envServer),
    body: utf8.encode(jsonEncode(snapshot)),
  );
}

Future<_RawResponse> _raw(
  String method,
  Uri uri, {
  String? password,
  List<int>? body,
  Map<String, String>? extraHeaders,
  bool followRedirects = true,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.openUrl(method, uri);
    request.followRedirects = followRedirects;
    final credentials = base64Encode(
      utf8.encode('$_envUser:${password ?? _envPassword}'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $credentials');
    if (extraHeaders != null) {
      for (final entry in extraHeaders.entries) {
        request.headers.set(entry.key, entry.value);
      }
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.contentLength = body.length;
      request.add(body);
    }
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    final headers = <String, List<String>>{};
    response.headers.forEach(
      (name, values) => headers[name.toLowerCase()] = values,
    );
    return _RawResponse(response.statusCode, headers, bytes);
  } finally {
    client.close(force: true);
  }
}

class _RawResponse {
  _RawResponse(this.status, this.headers, this.bytes);

  final int status;
  final Map<String, List<String>> headers;
  final List<int> bytes;

  String get text => utf8.decode(bytes, allowMalformed: true);

  String? firstHeader(String name) {
    final values = headers[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }
}

class _Ctx {
  _Ctx(this.db, this.service, this.recorder, this.dio);

  final AppDatabase db;
  final WebDavSyncService service;
  final _RecordingAdapter recorder;
  final Dio dio;

  Future<void> dispose() async {
    dio.close(force: true);
    await db.close();
  }
}

Future<_Ctx> _makeCtx({String? serverUrl, String? password}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.forTesting(NativeDatabase.memory());

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 120),
      transformTimeout: const Duration(seconds: 30),
    ),
  );
  final recorder = _RecordingAdapter(dio.httpClientAdapter);
  dio.httpClientAdapter = recorder;

  final client = WebDavClient(
    serverUrl: serverUrl ?? _envServer,
    username: _envUser,
    password: password ?? _envPassword,
    dio: dio,
    requestTimeout: const Duration(seconds: 30),
  );

  final service = WebDavSyncService(
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

  return _Ctx(db, service, recorder, dio);
}

RequestOptions _lastRequest(_Ctx ctx, String method) {
  return ctx.recorder.requests.lastWhere((r) => r.method == method);
}

String? _header(RequestOptions request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value?.toString();
    }
  }
  return null;
}

int? _currentRss() {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    return null;
  }
}

void _evidence(String message) {
  // ignore: avoid_print
  print('EVIDENCE|\n$message\n|END');
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.inner);

  final HttpClientAdapter inner;
  final List<RequestOptions> requests = [];
  final List<String> events = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    try {
      final response = await inner.fetch(options, requestStream, cancelFuture);
      events.add(
        '${options.method} ${options.uri.path} -> ${response.statusCode}',
      );
      return response;
    } catch (error) {
      events.add(
        '${options.method} ${options.uri.path} -> ERROR ${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}
