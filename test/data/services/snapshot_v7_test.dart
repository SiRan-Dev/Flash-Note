import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flashnote/data/datasources/local/ai_settings_storage.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';
import 'package:flashnote/data/datasources/local/webdav_storage.dart';
import 'package:flashnote/data/services/snapshot_codec.dart';
import 'package:flashnote/data/services/snapshot_validator.dart';
import 'package:flashnote/data/services/webdav_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase dbA;
  late AppDatabase dbB;
  late SnapshotCodec codecA;
  late SnapshotCodec codecB;

  setUp(() {
    dbA = AppDatabase.forTesting(NativeDatabase.memory());
    dbB = AppDatabase.forTesting(NativeDatabase.memory());
    codecA = SnapshotCodec(dbA);
    codecB = SnapshotCodec(dbB);
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  test('两台设备各自新建（本地 id 都是 1）合并后两条都在且 uuid 不同', () async {
    await _insertInspiration(dbA, 'A 的灵感');
    await _insertInspiration(dbB, 'B 的灵感');

    final a = await codecA.exportSnapshot(
      deviceId: 'device-a',
      includeAttachmentContent: false,
    );
    final b = await codecB.exportSnapshot(
      deviceId: 'device-b',
      includeAttachmentContent: false,
    );
    expect(a['inspirations'], hasLength(1));
    expect(b['inspirations'], hasLength(1));

    final merged = mergeSnapshots(a, b);
    final inspirations = (merged['inspirations'] as List)
        .cast<Map<String, dynamic>>();
    expect(inspirations, hasLength(2));
    expect(
      inspirations.map((i) => i['content']),
      containsAll(['A 的灵感', 'B 的灵感']),
    );
    expect(inspirations.map((i) => i['uuid']).toSet(), hasLength(2));

    await codecA.importSnapshot(merged);
    final rows = await dbA.getAllInspirations();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.content), containsAll(['A 的灵感', 'B 的灵感']));
    expect(rows.map((r) => r.uuid).toSet(), hasLength(2));
  });

  test('同一 uuid 两端修改：updatedAt 新者胜；相等时按 deviceId 收敛', () async {
    await _insertInspiration(dbA, '原始');
    final original = await codecA.exportSnapshot(
      deviceId: 'device-a',
      includeAttachmentContent: false,
    );
    await codecB.importSnapshot(original);

    final uuid =
        (original['inspirations'] as List)
                .cast<Map<String, dynamic>>()
                .first['uuid']
            as String;

    // 两端分别修改，A 的 updatedAt 更新。
    await (dbA.update(
      dbA.inspirations,
    )..where((t) => t.uuid.equals(uuid))).write(
      const InspirationsCompanion(
        content: Value('A 新版本'),
        updatedAt: Value(2000),
      ),
    );
    await (dbB.update(
      dbB.inspirations,
    )..where((t) => t.uuid.equals(uuid))).write(
      const InspirationsCompanion(
        content: Value('B 旧版本'),
        updatedAt: Value(1500),
      ),
    );

    final aNew = await codecA.exportSnapshot(
      deviceId: 'device-a',
      includeAttachmentContent: false,
    );
    final bOld = await codecB.exportSnapshot(
      deviceId: 'device-b',
      includeAttachmentContent: false,
    );

    final mergedAB = mergeSnapshots(aNew, bOld);
    final mergedBA = mergeSnapshots(bOld, aNew);
    String onlyContent(Map<String, dynamic> snapshot) =>
        (snapshot['inspirations'] as List)
                .cast<Map<String, dynamic>>()
                .single['content']
            as String;
    expect(onlyContent(mergedAB), 'A 新版本');
    expect(onlyContent(mergedBA), 'A 新版本');

    // updatedAt 相同：device-b 字典序更大，两个方向都选 B 的内容。
    await (dbA.update(dbA.inspirations)..where((t) => t.uuid.equals(uuid)))
        .write(const InspirationsCompanion(updatedAt: Value(2000)));
    await (dbB.update(dbB.inspirations)..where((t) => t.uuid.equals(uuid)))
        .write(const InspirationsCompanion(updatedAt: Value(2000)));

    final aTie = await codecA.exportSnapshot(
      deviceId: 'device-a',
      includeAttachmentContent: false,
    );
    final bTie = await codecB.exportSnapshot(
      deviceId: 'device-b',
      includeAttachmentContent: false,
    );

    final tieAB = mergeSnapshots(aTie, bTie);
    final tieBA = mergeSnapshots(bTie, aTie);
    expect(onlyContent(tieAB), 'B 旧版本');
    expect(onlyContent(tieBA), 'B 旧版本');
  });

  test('删除传播：墓碑压过旧版本，放过更新版本', () {
    const uuid = '00000000-0000-4000-8000-000000000101';
    final withTombstone = _v7(
      deletedRecords: [
        {'entityType': 'inspirations', 'entityUuid': uuid, 'deletedAt': 1000},
      ],
    );
    final olderRecord = _v7(
      deviceId: 'device-b',
      inspirations: [
        _inspirationJson(uuid: uuid, content: '旧版本', updatedAt: 900),
      ],
    );
    final newerRecord = _v7(
      deviceId: 'device-b',
      inspirations: [
        _inspirationJson(uuid: uuid, content: '更新版本', updatedAt: 1100),
      ],
    );

    expect(mergeSnapshots(withTombstone, olderRecord)['inspirations'], isEmpty);
    final survivors =
        (mergeSnapshots(withTombstone, newerRecord)['inspirations'] as List)
            .cast<Map<String, dynamic>>();
    expect(survivors, hasLength(1));
    expect(survivors.single['content'], '更新版本');
  });

  test('v6 快照转换：uuid 非空唯一、关系可解析、旧墓碑 legacy 生效', () async {
    final upgraded = await codecA.upgradeLegacySnapshot(
      _legacyV6(recordUpdatedAt: 1500, deletedAt: 2000),
      deviceId: 'device-a',
    );
    validateSnapshot(upgraded);

    for (final key in const [
      'inspirations',
      'projects',
      'tasks',
      'customSources',
      'attachments',
      'chatMessages',
      'inspirationLinks',
      'clusters',
      'reports',
    ]) {
      final items = (upgraded[key] as List).cast<Map<String, dynamic>>();
      expect(items, isNotEmpty, reason: '$key 不应为空');
      final uuids = items.map((i) => i['uuid'] as String).toSet();
      expect(uuids, hasLength(items.length), reason: '$key uuid 重复');
      expect(uuids.every((u) => u.isNotEmpty), isTrue);
    }

    expect(upgraded['deletedRecords'], hasLength(1));
    final tombstone =
        (upgraded['deletedRecords'] as List).single as Map<String, dynamic>;
    expect(tombstone['legacy'], isTrue);
    expect(tombstone['entityId'], 1);
    expect(tombstone['entityUuid'], legacyTombstoneUuid('inspirations', 1));

    // 旧墓碑只压过同 entityId 的旧记录：id=1 被剔除、id=2 保留；
    // 依赖 id=1 的关系被清理（项目解除关联、任务保留、附件/对话/链接丢弃）。
    final filtered = mergeSnapshots(_v7(deviceId: 'device-b'), upgraded);
    final surviving = (filtered['inspirations'] as List)
        .cast<Map<String, dynamic>>();
    expect(surviving, hasLength(1));
    expect(surviving.single['content'], '旧灵感二');
    final filteredProjects = (filtered['projects'] as List)
        .cast<Map<String, dynamic>>();
    expect(filteredProjects.single['inspirationUuid'], isNull);
    expect(filtered['tasks'], hasLength(1));
    expect(filtered['attachments'], isEmpty);
    expect(filtered['chatMessages'], isEmpty);
    expect(filtered['inspirationLinks'], isEmpty);

    // 更新晚于墓碑的记录会保留下来。
    final alive = await codecB.upgradeLegacySnapshot(
      _legacyV6(recordUpdatedAt: 2500, deletedAt: 2000),
      deviceId: 'device-b',
    );
    final aliveMerged = mergeSnapshots(_v7(), alive);
    expect(aliveMerged['inspirations'], hasLength(2));

    // 空库导入：不再使用快照 id，但关系仍能按 uuid 还原。
    await codecB.importSnapshot(aliveMerged);
    final rows = await dbB.getAllInspirations();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.uuid).toSet(), hasLength(2));
    final project = (await dbB.getAllProjects()).single;
    final inspiration = (await dbB.getInspirationById(project.inspirationId!))!;
    expect(inspiration.content, '旧灵感一');
    final task = (await dbB.getAllTasks()).single;
    expect(task.projectId, project.id);
    final link = (await dbB.getAllInspirationLinks()).single;
    expect(link.sourceId, inspiration.id);
    final target = (await dbB.getInspirationById(link.targetId))!;
    expect(target.content, '旧灵感二');
  });

  test('v6 → v7 转换幂等：同一份旧快照两次转换结果完全一致', () async {
    final first = await codecA.upgradeLegacySnapshot(
      _legacyV6(recordUpdatedAt: 1500, deletedAt: 2500),
      deviceId: 'device-a',
    );
    final second = await codecA.upgradeLegacySnapshot(
      _legacyV6(recordUpdatedAt: 1500, deletedAt: 2500),
      deviceId: 'device-a',
    );
    expect(second, equals(first));
  });

  test('v7 往返：导出→导入空库→再导出，数量/uuid/关系一致，二次导入不新增行', () async {
    await _seedFullGraph(dbA);
    final exportA = await codecA.exportSnapshot(
      deviceId: 'device-a',
      includeAttachmentContent: false,
    );
    validateSnapshot(exportA);

    expect(await dbB.getAllInspirations(), isEmpty);
    await codecB.importSnapshot(exportA);
    validateSnapshot(exportA);

    final exportB = await codecB.exportSnapshot(
      deviceId: 'device-b',
      includeAttachmentContent: false,
    );

    _expectSameSnapshotShape(exportA, exportB);
    await codecB.importSnapshot(exportB);
    _expectSameSnapshotShape(
      exportB,
      await codecB.exportSnapshot(
        deviceId: 'device-b',
        includeAttachmentContent: false,
      ),
    );
    expect(await dbB.getAllInspirations(), hasLength(2));
    expect(await dbB.getAllProjects(), hasLength(1));
    expect(await dbB.getAllTasks(), hasLength(1));
  });

  test('校验器：缺 uuid/重复/非法/关系悬空/version>7 均报错，本地不变', () async {
    await _insertInspiration(dbA, '本地已有');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = WebDavSyncService(
      db: dbA,
      aiStorage: AiSettingsStorage(prefs: prefs),
      webdavStorage: WebDavStorage(prefs: prefs),
    );

    final invalidSnapshots = <String, Map<String, dynamic>>{
      '缺少 uuid': _v7(
        inspirations: [
          {'content': 'x', 'createdAt': 1, 'updatedAt': 1, 'isPinned': false},
        ],
      ),
      '重复 uuid': _v7(
        inspirations: [
          _inspirationJson(
            uuid: '00000000-0000-4000-8000-000000000201',
            content: 'A',
          ),
          _inspirationJson(
            uuid: '00000000-0000-4000-8000-000000000201',
            content: 'B',
          ),
        ],
      ),
      '非法 uuid': _v7(
        inspirations: [_inspirationJson(uuid: 'not-a-uuid', content: 'A')],
      ),
      '关系悬空': _v7(
        projects: [
          {
            'uuid': '00000000-0000-4000-8000-000000000301',
            'inspirationUuid': '00000000-0000-4000-8000-000000000399',
            'title': 'P',
            'createdAt': 1,
            'updatedAt': 1,
          },
        ],
      ),
      'version>7': {..._v7(), 'version': 8},
    };

    for (final entry in invalidSnapshots.entries) {
      await expectLater(
        service.importSnapshotForTesting(entry.value),
        throwsFormatException,
        reason: entry.key,
      );
      final rows = await dbA.getAllInspirations();
      expect(rows, hasLength(1), reason: entry.key);
      expect(rows.single.content, '本地已有', reason: entry.key);
    }
  });

  test('Reports 与内置 CustomSources 跨设备不翻倍', () async {
    await dbA.upsertLatestReport('weekly', '报告');
    await dbA.insertSource(
      CustomSourcesCompanion.insert(
        name: 'flash',
        icon: 'lightbulb',
        createdAt: 500,
        isBuiltIn: const Value(true),
      ),
    );
    final a = await codecA.exportSnapshot(
      deviceId: 'device-a',
      includeAttachmentContent: false,
    );

    final v6 = _v7(version: 6);
    v6['reports'] = [
      {
        'id': 1,
        'type': 'weekly',
        'content': '另一个设备的报告',
        'model': 'm',
        'createdAt': 1000,
        'updatedAt': 1000,
      },
    ];
    v6['customSources'] = [
      {
        'id': 1,
        'name': 'flash',
        'icon': 'lightbulb',
        'sortOrder': 0,
        'isBuiltIn': true,
        'createdAt': 3000,
      },
    ];
    v6.remove('deviceId');
    final upgraded = await codecB.upgradeLegacySnapshot(
      v6,
      deviceId: 'device-b',
    );

    final merged = mergeSnapshots(a, upgraded);
    final reports = merged['reports'] as List;
    final sources = merged['customSources'] as List;
    expect(reports, hasLength(1));
    expect(sources, hasLength(1));
    final report = reports.cast<Map<String, dynamic>>().single;
    final source = sources.cast<Map<String, dynamic>>().single;
    expect(report['uuid'], deterministicReportUuid('weekly'));
    expect(source['uuid'], deterministicBuiltInSourceUuid('flash'));
  });

  group('附件文件恢复与冲突', () {
    const inspirationUuid = '00000000-0000-4000-8000-000000000a01';
    const attachmentUuid = '00000000-0000-4000-8000-000000000a02';

    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flashnote_attach');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Map<String, dynamic> snapshotWithAttachment({String? contentBase64}) {
      return {
        'version': 7,
        'deviceId': 'device-remote',
        'exportedAt': '2026-05-16T00:00:00.000',
        'inspirations': [
          {
            'uuid': inspirationUuid,
            'content': '附件的宿主灵感',
            'createdAt': 1000,
            'updatedAt': 1000,
            'isPinned': false,
          },
        ],
        'projects': <Map<String, dynamic>>[],
        'tasks': <Map<String, dynamic>>[],
        'customSources': <Map<String, dynamic>>[],
        'attachments': [
          {
            'uuid': attachmentUuid,
            'ownerType': 'inspiration',
            'ownerUuid': inspirationUuid,
            'fileName': 'note.txt',
            'filePath': '/other-device/note.txt',
            'mimeType': 'text/plain',
            'size': 6,
            'createdAt': 1000,
            'contentBase64': contentBase64,
          },
        ],
        'chatMessages': <Map<String, dynamic>>[],
        'inspirationLinks': <Map<String, dynamic>>[],
        'clusters': <Map<String, dynamic>>[],
        'reports': <Map<String, dynamic>>[],
        'deletedRecords': <Map<String, dynamic>>[],
      };
    }

    Future<int> seedLocalAttachment(String content) async {
      final inspirationId = await dbA.insertInspiration(
        InspirationsCompanion.insert(
          content: '附件的宿主灵感',
          createdAt: 1000,
          updatedAt: 1000,
          uuid: const Value(inspirationUuid),
        ),
      );
      final filePath = '${tempDir.path}/local_note.txt';
      await File(filePath).writeAsString(content);
      await dbA.insertAttachment(
        AttachmentsCompanion.insert(
          ownerType: 'inspiration',
          ownerId: inspirationId,
          fileName: 'note.txt',
          filePath: filePath,
          mimeType: 'text/plain',
          createdAt: 1000,
          uuid: const Value(attachmentUuid),
        ),
      );
      return inspirationId;
    }

    test('本地缺物理文件但快照带内容 -> 按 uuid 落盘恢复且可读取', () async {
      final summary = await codecB.importSnapshot(
        snapshotWithAttachment(
          contentBase64: base64Encode(utf8.encode('远端内容')),
        ),
      );

      expect(summary.attachmentConflicts, 0);
      final row = (await dbB.getAllAttachments()).single;
      expect(row.uuid, attachmentUuid);
      expect(row.filePath, contains(attachmentUuid));
      final restored = File(row.filePath);
      expect(await restored.exists(), isTrue);
      expect(await restored.readAsString(), '远端内容');
    });

    test('同一 uuid 内容冲突（合并模式）-> 保留本机文件、另存副本并计数', () async {
      final localPath =
          '${tempDir.path}/attachments/${1000}_${attachmentUuid}_note.txt';
      await seedLocalAttachment('本机内容');
      await File(localPath).create(recursive: true);
      await File(localPath).writeAsString('本机内容');
      // 让本地行指向“按 uuid 命名”的正件路径，模拟同步产生的文件。
      final localRow = (await dbA.getAllAttachments()).single;
      await File(localRow.filePath).delete();
      await (dbA.update(dbA.attachments)
            ..where((t) => t.id.equals(localRow.id)))
          .write(AttachmentsCompanion(filePath: Value(localPath)));

      final summary = await codecA.importSnapshot(
        snapshotWithAttachment(
          contentBase64: base64Encode(utf8.encode('远端内容')),
        ),
        preserveConflictingAttachments: true,
      );

      expect(summary.attachmentConflicts, 1);
      // 本机文件原样保留，没有被静默覆盖。
      expect(await File(localPath).readAsString(), '本机内容');
      // 远端内容以 .conflict 副本落盘，两边都不丢。
      final conflict = File('$localPath.conflict');
      expect(await conflict.exists(), isTrue);
      expect(await conflict.readAsString(), '远端内容');
      final row = (await dbA.getAllAttachments()).single;
      expect(row.filePath, localPath);
    });

    test('同一 uuid 内容冲突（拉取/导入的覆盖模式）-> 采用快照内容', () async {
      await seedLocalAttachment('本机内容');

      final summary = await codecA.importSnapshot(
        snapshotWithAttachment(
          contentBase64: base64Encode(utf8.encode('远端内容')),
        ),
      );

      expect(summary.attachmentConflicts, 0);
      final row = (await dbA.getAllAttachments()).single;
      expect(row.filePath, contains(attachmentUuid));
      expect(await File(row.filePath).readAsString(), '远端内容');
      expect(File('${row.filePath}.conflict').existsSync(), isFalse);
    });

    test('内容一致 -> 复用本机文件，不重写也不计冲突', () async {
      await seedLocalAttachment('相同内容');
      final before = (await dbA.getAllAttachments()).single;
      final mtimeBefore = File(before.filePath).lastModifiedSync();

      final summary = await codecA.importSnapshot(
        snapshotWithAttachment(
          contentBase64: base64Encode(utf8.encode('相同内容')),
        ),
        preserveConflictingAttachments: true,
      );

      expect(summary.attachmentConflicts, 0);
      final after = (await dbA.getAllAttachments()).single;
      expect(after.filePath, before.filePath);
      expect(File(after.filePath).lastModifiedSync(), mtimeBefore);
      expect(File('${after.filePath}.conflict').existsSync(), isFalse);
    });

    test('关闭附件同步（快照不带内容）-> 有行没文件也不报错，路径保持', () async {
      await seedLocalAttachment('本机内容');
      final before = (await dbA.getAllAttachments()).single;

      final summary = await codecA.importSnapshot(
        snapshotWithAttachment(),
        preserveConflictingAttachments: true,
      );

      expect(summary.attachmentConflicts, 0);
      final after = (await dbA.getAllAttachments()).single;
      expect(after.filePath, before.filePath);
      expect(await File(after.filePath).readAsString(), '本机内容');
    });
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

Future<int> _insertInspiration(
  AppDatabase db,
  String content, {
  int createdAt = 1000,
  int? updatedAt,
}) {
  return db.insertInspiration(
    InspirationsCompanion.insert(
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
    ),
  );
}

Map<String, dynamic> _v7({
  String deviceId = 'device-a',
  int version = 7,
  List<Map<String, dynamic>> inspirations = const [],
  List<Map<String, dynamic>> projects = const [],
  List<Map<String, dynamic>> deletedRecords = const [],
}) {
  return {
    'version': version,
    'deviceId': deviceId,
    'exportedAt': '2026-05-16T00:00:00.000',
    'inspirations': inspirations,
    'projects': projects,
    'tasks': <Map<String, dynamic>>[],
    'customSources': <Map<String, dynamic>>[],
    'attachments': <Map<String, dynamic>>[],
    'chatMessages': <Map<String, dynamic>>[],
    'inspirationLinks': <Map<String, dynamic>>[],
    'clusters': <Map<String, dynamic>>[],
    'reports': <Map<String, dynamic>>[],
    'deletedRecords': deletedRecords,
  };
}

Map<String, dynamic> _inspirationJson({
  required String uuid,
  required String content,
  int createdAt = 1000,
  int? updatedAt,
}) {
  return {
    'uuid': uuid,
    'content': content,
    'createdAt': createdAt,
    'updatedAt': updatedAt ?? createdAt,
    'isPinned': false,
  };
}

Map<String, dynamic> _legacyV6({
  required int recordUpdatedAt,
  required int deletedAt,
}) {
  return {
    'version': 6,
    'exportedAt': '2026-05-16T00:00:00.000',
    'inspirations': [
      {
        'id': 1,
        'content': '旧灵感一',
        'createdAt': 1000,
        'updatedAt': recordUpdatedAt,
        'isPinned': false,
      },
      {
        'id': 2,
        'content': '旧灵感二',
        'createdAt': 1000,
        'updatedAt': recordUpdatedAt,
        'isPinned': false,
      },
    ],
    'projects': [
      {
        'id': 1,
        'inspirationId': 1,
        'title': '旧项目',
        'createdAt': 1000,
        'updatedAt': recordUpdatedAt,
      },
    ],
    'tasks': [
      {
        'id': 1,
        'projectId': 1,
        'title': '旧任务',
        'createdAt': 1000,
        'updatedAt': recordUpdatedAt,
      },
    ],
    'customSources': [
      {
        'id': 1,
        'name': 'flash',
        'icon': 'lightbulb',
        'createdAt': 1000,
        'isBuiltIn': true,
      },
    ],
    'attachments': [
      {
        'id': 1,
        'ownerType': 'inspiration',
        'ownerId': 1,
        'fileName': 'a.txt',
        'filePath': '/tmp/a.txt',
        'mimeType': 'text/plain',
        'createdAt': 1000,
      },
    ],
    'chatMessages': [
      {
        'id': 1,
        'inspirationId': 1,
        'role': 'user',
        'content': '你好',
        'createdAt': 1000,
      },
    ],
    'inspirationLinks': [
      {
        'id': 1,
        'sourceId': 1,
        'targetId': 2,
        'linkType': 'similar',
        'createdAt': 1000,
      },
    ],
    'clusters': [
      {'id': 1, 'name': '旧聚类', 'createdAt': 1000, 'updatedAt': recordUpdatedAt},
    ],
    'deletedRecords': [
      {'entityType': 'inspirations', 'entityId': 1, 'deletedAt': deletedAt},
    ],
    'reports': [
      {
        'id': 1,
        'type': 'weekly',
        'content': '旧报告',
        'createdAt': 1000,
        'updatedAt': recordUpdatedAt,
      },
    ],
  };
}

Future<void> _seedFullGraph(AppDatabase db) async {
  final i1 = await _insertInspiration(db, '一');
  final i2 = await _insertInspiration(db, '二');
  final projectId = await db.insertProject(
    ProjectsCompanion.insert(
      inspirationId: Value(i1),
      title: '项目',
      createdAt: 1000,
      updatedAt: 1000,
    ),
  );
  await db.insertTask(
    TasksCompanion.insert(
      projectId: projectId,
      title: '任务',
      createdAt: 1000,
      updatedAt: 1000,
    ),
  );
  await db.insertAttachment(
    AttachmentsCompanion.insert(
      ownerType: 'inspiration',
      ownerId: i1,
      fileName: 'a.txt',
      filePath: '/tmp/a.txt',
      mimeType: 'text/plain',
      createdAt: 1000,
    ),
  );
  await db.insertChatMessage(
    ChatMessagesCompanion.insert(
      inspirationId: i1,
      role: 'user',
      content: '你好',
      createdAt: 1000,
    ),
  );
  await db.insertInspirationLink(
    InspirationLinksCompanion.insert(
      sourceId: i1,
      targetId: i2,
      linkType: 'similar',
      createdAt: 1000,
    ),
  );
  await db.insertCluster(
    ClustersCompanion.insert(name: '聚类', createdAt: 1000, updatedAt: 1000),
  );
  await db.insertSource(
    CustomSourcesCompanion.insert(
      name: 'flash',
      icon: 'lightbulb',
      createdAt: 1000,
      isBuiltIn: const Value(true),
    ),
  );
  await db.upsertLatestReport('weekly', '报告');
  await db.insertDeletedRecord(
    DeletedRecordsCompanion.insert(
      entityType: 'inspirations',
      entityUuid: const Value('00000000-0000-4000-8000-000000000401'),
      deletedAt: 500,
    ),
  );
}

void _expectSameSnapshotShape(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  const keys = [
    'inspirations',
    'projects',
    'tasks',
    'customSources',
    'attachments',
    'chatMessages',
    'inspirationLinks',
    'clusters',
    'reports',
    'deletedRecords',
  ];
  for (final key in keys) {
    final firstList = (first[key] as List?) ?? const [];
    final secondList = (second[key] as List?) ?? const [];
    expect(firstList.length, secondList.length, reason: '$key 数量');
    expect(
      firstList.map((e) => (e as Map)['uuid']).toSet(),
      secondList.map((e) => (e as Map)['uuid']).toSet(),
      reason: '$key uuid 集合',
    );
  }

  // 关系图：以 uuid 表达，不受本地 id 影响。
  Map<String, Set<String>> graph(Map<String, dynamic> snapshot) {
    return {
      for (final p
          in (snapshot['projects'] as List).cast<Map<String, dynamic>>())
        'project:${p['uuid']}': {?p['inspirationUuid'] as String?},
      for (final t in (snapshot['tasks'] as List).cast<Map<String, dynamic>>())
        'task:${t['uuid']}': {?t['projectUuid'] as String?},
      for (final a
          in (snapshot['attachments'] as List).cast<Map<String, dynamic>>())
        'attachment:${a['uuid']}': {?a['ownerUuid'] as String?},
      for (final c
          in (snapshot['chatMessages'] as List).cast<Map<String, dynamic>>())
        'chat:${c['uuid']}': {?c['inspirationUuid'] as String?},
      for (final l
          in (snapshot['inspirationLinks'] as List)
              .cast<Map<String, dynamic>>())
        'link:${l['uuid']}': {
          ?l['sourceUuid'] as String?,
          ?l['targetUuid'] as String?,
        },
    };
  }

  expect(graph(first), equals(graph(second)));
}
