import 'package:drift/native.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/data/repositories/attachment_repository_impl.dart';
import 'package:flashnote/data/repositories/inspiration_repository_impl.dart';
import 'package:flashnote/data/services/share_intake_controller.dart';
import 'package:flashnote/data/services/share_intake_service.dart';
import 'package:flashnote/domain/entities/attachment.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFileImporter implements SharedFileImporter {
  final Set<String> failingPaths = <String>{};
  final List<String> discardedTempPaths = <String>[];
  final List<String> deletedStoredPaths = <String>[];

  @override
  Future<ImportedShareFile> importAttachment(
    IncomingShareAttachment attachment,
  ) async {
    if (failingPaths.contains(attachment.path)) {
      throw Exception('cannot read ${attachment.path}');
    }
    return ImportedShareFile(
      path: '/stored/${attachment.fileName}',
      fileName: attachment.fileName,
      mimeType: attachment.mimeType.isEmpty
          ? 'image/jpeg'
          : attachment.mimeType,
      size: attachment.size,
    );
  }

  @override
  Future<void> discardTemporaryFile(String path) async {
    discardedTempPaths.add(path);
  }

  @override
  Future<void> deleteStoredFile(String path) async {
    deletedStoredPaths.add(path);
  }
}

void main() {
  late AppDatabase db;
  late InspirationRepositoryImpl inspirationRepository;
  late AttachmentRepositoryImpl attachmentRepository;
  late _FakeFileImporter fileImporter;
  late ShareIntakeService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    inspirationRepository = InspirationRepositoryImpl(db);
    attachmentRepository = AttachmentRepositoryImpl(db);
    fileImporter = _FakeFileImporter();
    service = ShareIntakeService(
      inspirationRepository: inspirationRepository,
      attachmentRepository: attachmentRepository,
      fileImporter: fileImporter,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ShareIntakeService', () {
    test('纯文本分享创建一条灵感', () async {
      final result = await service.ingest(
        const IncomingShare(text: '记下这个想法'),
        fallbackContent: '分享的图片',
      );

      expect(result.status, ShareIntakeStatus.saved);
      expect(result.attachmentCount, 0);
      final inspirations = await inspirationRepository.getAll();
      expect(inspirations, hasLength(1));
      expect(inspirations.single.content, '记下这个想法');
      expect(inspirations.single.source, isNull);
    });

    test('分享内容里的 URL 以 reading 来源标记', () async {
      final result = await service.ingest(
        const IncomingShare(text: '看看这篇文章 https://example.com/post'),
        fallbackContent: '分享的图片',
      );

      expect(result.status, ShareIntakeStatus.saved);
      final inspiration = await inspirationRepository.getById(
        result.inspirationId!,
      );
      expect(inspiration!.content, contains('https://example.com/post'));
      expect(inspiration.source, 'reading');
    });

    test('text/uri-list 形式的纯链接同样识别 URL', () async {
      final result = await service.ingest(
        const IncomingShare(
          text: 'https://example.com/a\nhttps://example.com/b',
        ),
        fallbackContent: '分享的图片',
      );

      expect(result.status, ShareIntakeStatus.saved);
      final inspiration = await inspirationRepository.getById(
        result.inspirationId!,
      );
      expect(inspiration!.source, 'reading');
    });

    test('空分享不写入任何记录', () async {
      final result = await service.ingest(
        const IncomingShare(),
        fallbackContent: '分享的图片',
      );

      expect(result.status, ShareIntakeStatus.empty);
      expect(await inspirationRepository.getAll(), isEmpty);
    });

    test('多张图片生成一条记录和多个附件', () async {
      final result = await service.ingest(
        const IncomingShare(
          attachments: [
            IncomingShareAttachment(
              path: '/cache/one.jpg',
              fileName: 'one.jpg',
              mimeType: 'image/jpeg',
              size: 10,
            ),
            IncomingShareAttachment(
              path: '/cache/two.png',
              fileName: 'two.png',
              mimeType: 'image/png',
              size: 20,
            ),
          ],
        ),
        fallbackContent: '分享的图片',
      );

      expect(result.status, ShareIntakeStatus.saved);
      expect(result.attachmentCount, 2);

      final inspiration = await inspirationRepository.getById(
        result.inspirationId!,
      );
      expect(inspiration!.content, '分享的图片');

      final attachments = await attachmentRepository.getByOwner(
        AttachmentOwnerType.inspiration,
        result.inspirationId!,
      );
      expect(attachments, hasLength(2));
      expect(
        attachments.map((item) => item.fileName),
        containsAll(['one.jpg', 'two.png']),
      );
      expect(
        fileImporter.discardedTempPaths,
        containsAll(['/cache/one.jpg', '/cache/two.png']),
      );
    });

    test('图片全部读取失败且没有文本时不留下空记录', () async {
      fileImporter.failingPaths.addAll(['/cache/bad1.jpg', '/cache/bad2.jpg']);
      final result = await service.ingest(
        const IncomingShare(
          attachments: [
            IncomingShareAttachment(
              path: '/cache/bad1.jpg',
              fileName: 'bad1.jpg',
              mimeType: 'image/jpeg',
            ),
            IncomingShareAttachment(
              path: '/cache/bad2.jpg',
              fileName: 'bad2.jpg',
              mimeType: 'image/jpeg',
            ),
          ],
        ),
        fallbackContent: '分享的图片',
      );

      expect(result.status, ShareIntakeStatus.failed);
      expect(result.failedAttachmentCount, 2);
      expect(await inspirationRepository.getAll(), isEmpty);
      expect(fileImporter.discardedTempPaths, hasLength(2));
    });

    test('部分图片失败时保留文本记录并报告失败数量', () async {
      fileImporter.failingPaths.add('/cache/bad.jpg');
      final result = await service.ingest(
        const IncomingShare(
          text: '标题',
          attachments: [
            IncomingShareAttachment(
              path: '/cache/good.jpg',
              fileName: 'good.jpg',
              mimeType: 'image/jpeg',
            ),
            IncomingShareAttachment(
              path: '/cache/bad.jpg',
              fileName: 'bad.jpg',
              mimeType: 'image/jpeg',
            ),
          ],
        ),
        fallbackContent: '分享的图片',
      );

      expect(result.status, ShareIntakeStatus.saved);
      expect(result.attachmentCount, 1);
      expect(result.failedAttachmentCount, 1);
      final attachments = await attachmentRepository.getByOwner(
        AttachmentOwnerType.inspiration,
        result.inspirationId!,
      );
      expect(attachments.single.fileName, 'good.jpg');
    });

    test('同一次分享重复投递只写入一条记录', () async {
      final controller = ShareIntakeController(service);
      const share = IncomingShare(shareId: 'share-1', text: '同一个分享');

      final first = await controller.handle(share, fallbackContent: '分享的图片');
      final second = await controller.handle(share, fallbackContent: '分享的图片');

      expect(first.status, ShareIntakeStatus.saved);
      expect(second.status, ShareIntakeStatus.duplicate);
      expect(await inspirationRepository.getAll(), hasLength(1));
    });

    test('原生 payload 解析保留文本、附件与失败计数', () {
      final share = IncomingShare.fromMap({
        'shareId': 'native-1',
        'text': '来自系统分享',
        'files': [
          {
            'path': '/cache/a.jpg',
            'fileName': 'a.jpg',
            'mimeType': 'image/jpeg',
            'size': 12,
          },
        ],
        'failedFileCount': 1,
      });

      expect(share.shareId, 'native-1');
      expect(share.text, '来自系统分享');
      expect(share.attachments, hasLength(1));
      expect(share.attachments.single.fileName, 'a.jpg');
      expect(share.failedAttachmentCount, 1);
    });
  });
}
