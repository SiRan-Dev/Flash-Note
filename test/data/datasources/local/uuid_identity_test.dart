import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/datasources/local/entity_uuids.dart';
import 'package:flashnote/data/repositories/attachment_repository_impl.dart';
import 'package:flashnote/data/repositories/chat_message_repository_impl.dart';
import 'package:flashnote/data/repositories/cluster_repository_impl.dart';
import 'package:flashnote/data/repositories/inspiration_link_repository_impl.dart';
import 'package:flashnote/data/repositories/inspiration_repository_impl.dart';
import 'package:flashnote/data/repositories/project_repository_impl.dart';
import 'package:flashnote/data/repositories/source_repository_impl.dart';
import 'package:flashnote/data/repositories/task_repository_impl.dart';
import 'package:flashnote/domain/entities/attachment.dart' as domain;
import 'package:flashnote/domain/entities/chat_message.dart' as domain;
import 'package:flashnote/domain/entities/cluster.dart' as domain;
import 'package:flashnote/domain/entities/inspiration_link.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InspirationRepositoryImpl inspirations;
  late ProjectRepositoryImpl projects;
  late TaskRepositoryImpl tasks;
  late SourceRepositoryImpl sources;
  late AttachmentRepositoryImpl attachments;
  late ChatMessageRepositoryImpl chats;
  late InspirationLinkRepositoryImpl links;
  late ClusterRepositoryImpl clusters;

  final now = DateTime.fromMillisecondsSinceEpoch(1000);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    inspirations = InspirationRepositoryImpl(db);
    projects = ProjectRepositoryImpl(db);
    tasks = TaskRepositoryImpl(db);
    sources = SourceRepositoryImpl(db);
    attachments = AttachmentRepositoryImpl(db);
    chats = ChatMessageRepositoryImpl(db);
    links = InspirationLinkRepositoryImpl(db);
    clusters = ClusterRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('全新 v12：各 Repository create 后 uuid 非空且表内唯一', () async {
    final i1 = await inspirations.create('灵感一');
    final i2 = await inspirations.create('灵感二');
    final p1 = await projects.create('项目一', inspirationId: i1);
    await projects.create('项目二');
    final t1 = await tasks.create(p1, '任务一');
    final t2 = await tasks.create(p1, '任务二');
    await sources.create('来源一', 'star');
    await sources.create('来源二', 'flag');
    final a1 = await attachments.create(
      domain.Attachment(
        id: 0,
        ownerType: domain.AttachmentOwnerType.inspiration,
        ownerId: i1,
        fileName: 'a.txt',
        filePath: '/tmp/a.txt',
        mimeType: 'text/plain',
        createdAt: now,
      ),
    );
    final a2 = await attachments.create(
      domain.Attachment(
        id: 0,
        ownerType: domain.AttachmentOwnerType.project,
        ownerId: p1,
        fileName: 'b.txt',
        filePath: '/tmp/b.txt',
        mimeType: 'text/plain',
        createdAt: now,
      ),
    );
    await chats.create(i1, domain.ChatRole.user, '你好');
    await chats.create(i1, domain.ChatRole.assistant, '你好');
    await links.create(
      domain.InspirationLink(
        id: 0,
        sourceId: i1,
        targetId: i2,
        linkType: domain.LinkType.similar,
        createdAt: now,
      ),
    );
    await links.create(
      domain.InspirationLink(
        id: 0,
        sourceId: i1,
        targetId: i2,
        linkType: domain.LinkType.causal,
        createdAt: now,
      ),
    );
    await clusters.create(
      domain.Cluster(id: 0, name: '聚类一', createdAt: now, updatedAt: now),
    );
    await clusters.create(
      domain.Cluster(id: 0, name: '聚类二', createdAt: now, updatedAt: now),
    );
    await db.upsertLatestReport('weekly', '周报');
    await db.upsertLatestReport('monthly', '月报');

    expect(t1, isNotNull);
    expect(t2, isNotNull);
    expect(a1, isNotNull);
    expect(a2, isNotNull);

    for (final table in _uuidTables) {
      final uuids = await _uuids(db, table);
      expect(uuids, hasLength(2), reason: '$table 应有两条记录');
      expect(uuids.where((u) => u.isEmpty), isEmpty, reason: '$table 有空 uuid');
      expect(uuids.toSet(), hasLength(2), reason: '$table uuid 重复');
    }
  });

  test('Reports 与内置 CustomSources 的 uuid 确定性，自定义来源保持随机', () async {
    final weeklyId = await db.upsertLatestReport('weekly', '第一版');
    final weeklyUuid = await _uuidOf(db, 'reports', weeklyId);
    expect(weeklyUuid, deterministicReportUuid('weekly'));

    await db.deleteAllReports();
    final weeklyId2 = await db.upsertLatestReport('weekly', '第二版');
    expect(await _uuidOf(db, 'reports', weeklyId2), weeklyUuid);

    await sources.seedBuiltInSources();
    final flashUuid = await _uuidByName(db, 'custom_sources', 'flash');
    expect(flashUuid, deterministicBuiltInSourceUuid('flash'));

    await db.deleteAllSources();
    await sources.seedBuiltInSources();
    expect(await _uuidByName(db, 'custom_sources', 'flash'), flashUuid);

    final allSources = await db.getAllSources();
    expect(allSources, hasLength(5));
    expect(
      allSources.map((s) => s.uuid).toSet(),
      hasLength(5),
      reason: '内置来源 uuid 不能重复',
    );

    await sources.create('自定义来源', 'star');
    final custom = (await db.getAllSources()).firstWhere(
      (s) => s.name == '自定义来源',
    );
    expect(custom.uuid, isNotEmpty);
    expect(custom.uuid, isNot(deterministicBuiltInSourceUuid('自定义来源')));
  });

  test('编辑记录（replace / partial 路径）不修改 uuid', () async {
    final id = await inspirations.create('原始内容');
    final uuid = await _uuidOf(db, 'inspirations', id);
    final created = (await inspirations.getById(id))!;

    await inspirations.update(created.copyWith(content: '修改后内容', tags: ['a']));
    await inspirations.togglePin(id);
    await inspirations.markReviewed(id);
    await inspirations.toggleNeedsFollowUp(id, true);
    await inspirations.updateAiAnalysis(id, '{"summary":"x"}');
    await inspirations.updateMindMapData(id, '{"nodes":[]}');

    final after = (await inspirations.getById(id))!;
    expect(await _uuidOf(db, 'inspirations', id), uuid);
    expect(after.content, '修改后内容');
    expect(after.aiAnalysis, '{"summary":"x"}');

    final projectId = await projects.create('项目', inspirationId: id);
    final projectUuid = await _uuidOf(db, 'projects', projectId);
    final project = (await projects.getById(projectId))!;
    await projects.update(project.copyWith(title: '改名', progress: 60));
    await projects.togglePin(projectId);
    await projects.updateStatus(projectId, 'done');
    expect(await _uuidOf(db, 'projects', projectId), projectUuid);

    final clusterId = await clusters.create(
      domain.Cluster(id: 0, name: '聚类', createdAt: now, updatedAt: now),
    );
    final clusterUuid = await _uuidOf(db, 'clusters', clusterId);
    final cluster = (await clusters.getById(clusterId))!;
    await clusters.update(cluster.copyWith(name: '新聚类'));
    expect(await _uuidOf(db, 'clusters', clusterId), clusterUuid);

    final sourceId = await sources.create('来源', 'star');
    final sourceUuid = await _uuidOf(db, 'custom_sources', sourceId);
    final source = (await sources.getAll()).firstWhere((s) => s.id == sourceId);
    await sources.update(source.copyWith(name: '新来源'));
    expect(await _uuidOf(db, 'custom_sources', sourceId), sourceUuid);

    // 仓储没有暴露 updateTask，直接走 AppDatabase 的 replace 路径。
    final taskId = await tasks.create(projectId, '任务');
    final taskUuid = await _uuidOf(db, 'tasks', taskId);
    final task = (await tasks.getById(taskId))!;
    await db.updateTask(
      TasksCompanion(
        id: Value(taskId),
        projectId: Value(task.projectId),
        title: const Value('新任务'),
        isCompleted: const Value(true),
        isPinned: Value(task.isPinned),
        createdAt: Value(task.createdAt.millisecondsSinceEpoch),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    expect(await _uuidOf(db, 'tasks', taskId), taskUuid);
  });

  test('墓碑写入路径携带实体 uuid；实体不存在时使用确定性 uuid', () async {
    final id = await inspirations.create('会被删除');
    final uuid = await _uuidOf(db, 'inspirations', id);

    await inspirations.delete(id);
    var tombstones = await db.getAllDeletedRecords();
    expect(tombstones, hasLength(1));
    expect(tombstones.single.entityType, 'inspirations');
    expect(tombstones.single.entityUuid, uuid);
    expect(tombstones.single.entityId, id);
    expect(tombstones.single.legacy, isFalse);

    // 重复删除同一实体：不会产生第二条墓碑。
    await db.markRecordDeleted('inspirations', id);
    tombstones = await db.getAllDeletedRecords();
    expect(tombstones, hasLength(1));
    expect(tombstones.single.entityUuid, uuid);

    // 实体已经不存在：退回 legacyTombstoneUuid，保持确定性。
    await db.markRecordDeleted('inspirations', 4242);
    tombstones = await db.getAllDeletedRecords();
    final fallback = tombstones.firstWhere((t) => t.entityId == 4242);
    expect(fallback.entityUuid, legacyTombstoneUuid('inspirations', 4242));

    // 旧快照导入（没有 entityUuid）也走确定性映射。
    await db.insertDeletedRecord(
      DeletedRecordsCompanion.insert(
        entityType: 'tasks',
        entityId: const Value<int?>(777),
        deletedAt: 1000,
      ),
    );
    tombstones = await db.getAllDeletedRecords();
    expect(
      tombstones.firstWhere((t) => t.entityId == 777).entityUuid,
      legacyTombstoneUuid('tasks', 777),
    );
  });
}

const _uuidTables = [
  'inspirations',
  'projects',
  'tasks',
  'attachments',
  'reports',
  'inspiration_links',
  'clusters',
  'custom_sources',
  'chat_messages',
];

Future<List<String>> _uuids(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT uuid FROM "$table"').get();
  return [for (final row in rows) row.read<String>('uuid')];
}

Future<String> _uuidOf(AppDatabase db, String table, int id) async {
  final row = await db
      .customSelect(
        'SELECT uuid FROM "$table" WHERE id = ?',
        variables: [Variable<int>(id)],
      )
      .getSingle();
  return row.read<String>('uuid');
}

Future<String> _uuidByName(AppDatabase db, String table, String name) async {
  final row = await db
      .customSelect(
        'SELECT uuid FROM "$table" WHERE name = ?',
        variables: [Variable<String>(name)],
      )
      .getSingle();
  return row.read<String>('uuid');
}
