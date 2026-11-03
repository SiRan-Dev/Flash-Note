import 'package:flashnote/core/constants/app_constants.dart';
import 'package:flashnote/domain/entities/attachment.dart';
import 'package:flashnote/domain/repositories/attachment_repository.dart';
import 'package:flashnote/domain/repositories/inspiration_repository.dart';
import 'package:flutter/foundation.dart';

/// 一条来自系统分享（Android ACTION_SEND）的附件。
///
/// [path] 指向应用私有缓存中的临时副本，由原生侧从外部的 `content://`
/// Uri 复制而来；Dart 侧会再次复制到附件目录并删除这个临时文件。
class IncomingShareAttachment {
  const IncomingShareAttachment({
    required this.path,
    required this.fileName,
    required this.mimeType,
    this.size = 0,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final int size;

  static IncomingShareAttachment? fromMap(Object? value) {
    if (value is! Map) return null;
    final path = value['path'] as String?;
    final fileName = value['fileName'] as String?;
    if (path == null || path.isEmpty) return null;
    return IncomingShareAttachment(
      path: path,
      fileName: fileName == null || fileName.isEmpty
          ? 'shared_image'
          : fileName,
      mimeType: value['mimeType'] as String? ?? '',
      size: (value['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 原生侧传来的分享内容。
class IncomingShare {
  const IncomingShare({
    this.shareId,
    this.text = '',
    this.attachments = const [],
    this.failedAttachmentCount = 0,
  });

  /// 同一次分享的稳定标识，用于避免重复投递产生多条记录。
  final String? shareId;
  final String text;
  final List<IncomingShareAttachment> attachments;
  final int failedAttachmentCount;

  bool get isEmpty =>
      text.trim().isEmpty && attachments.isEmpty && failedAttachmentCount == 0;

  factory IncomingShare.fromMap(Object? arguments) {
    if (arguments is! Map) return const IncomingShare();
    final rawFiles = arguments['files'];
    final attachments = <IncomingShareAttachment>[];
    if (rawFiles is List) {
      for (final item in rawFiles) {
        final attachment = IncomingShareAttachment.fromMap(item);
        if (attachment != null) attachments.add(attachment);
      }
    }
    return IncomingShare(
      shareId: arguments['shareId'] as String?,
      text: arguments['text'] as String? ?? '',
      attachments: attachments,
      failedAttachmentCount:
          (arguments['failedFileCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 已复制到应用附件目录的文件。
class ImportedShareFile {
  const ImportedShareFile({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.size,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final int size;
}

/// 把原生缓存中的临时文件搬进应用私有附件目录。
abstract class SharedFileImporter {
  Future<ImportedShareFile> importAttachment(
    IncomingShareAttachment attachment,
  );

  Future<void> discardTemporaryFile(String path);

  Future<void> deleteStoredFile(String path);
}

enum ShareIntakeStatus { saved, empty, failed, duplicate }

class ShareIntakeResult {
  const ShareIntakeResult({
    required this.status,
    this.inspirationId,
    this.attachmentCount = 0,
    this.failedAttachmentCount = 0,
  });

  final ShareIntakeStatus status;
  final int? inspirationId;
  final int attachmentCount;
  final int failedAttachmentCount;

  const ShareIntakeResult.duplicate()
    : status = ShareIntakeStatus.duplicate,
      inspirationId = null,
      attachmentCount = 0,
      failedAttachmentCount = 0;
}

/// 将分享内容写入现有 inspiration / attachment 仓库。
///
/// 这里不直接读写数据库，也不新造来源结构：纯文本按现有习惯落库，
/// 内容里出现 URL 时复用内置来源 "reading"（阅读启发）做来源标记。
class ShareIntakeService {
  ShareIntakeService({
    required InspirationRepository inspirationRepository,
    required AttachmentRepository attachmentRepository,
    required SharedFileImporter fileImporter,
  }) : _inspirationRepository = inspirationRepository,
       _attachmentRepository = attachmentRepository,
       _fileImporter = fileImporter;

  final InspirationRepository _inspirationRepository;
  final AttachmentRepository _attachmentRepository;
  final SharedFileImporter _fileImporter;

  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  Future<ShareIntakeResult> ingest(
    IncomingShare share, {
    required String fallbackContent,
  }) async {
    final text = share.text.trim();
    if (text.isEmpty && share.attachments.isEmpty) {
      return const ShareIntakeResult(status: ShareIntakeStatus.empty);
    }

    final imported = <ImportedShareFile>[];
    var failedAttachments = share.failedAttachmentCount;

    for (final attachment in share.attachments) {
      try {
        imported.add(await _fileImporter.importAttachment(attachment));
      } catch (error, stackTrace) {
        failedAttachments += 1;
        debugPrint('Share intake: failed to import attachment: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        await _fileImporter.discardTemporaryFile(attachment.path);
      }
    }

    final content = text.isNotEmpty ? text : fallbackContent.trim();
    // 纯图片分享里所有图片都读失败时，不要留下一条空记录。
    if (text.isEmpty && imported.isEmpty) {
      return ShareIntakeResult(
        status: ShareIntakeStatus.failed,
        failedAttachmentCount: failedAttachments,
      );
    }
    if (content.isEmpty) {
      await _discardImported(imported);
      return ShareIntakeResult(
        status: ShareIntakeStatus.failed,
        failedAttachmentCount: failedAttachments,
      );
    }

    int inspirationId;
    try {
      inspirationId = await _inspirationRepository.create(
        content,
        source: _urlPattern.hasMatch(content)
            ? AppConstants.sharedLinkSourceKey
            : null,
      );
    } catch (error, stackTrace) {
      debugPrint('Share intake: failed to create inspiration: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _discardImported(imported);
      return ShareIntakeResult(
        status: ShareIntakeStatus.failed,
        failedAttachmentCount: failedAttachments,
      );
    }

    var savedAttachments = 0;
    for (final file in imported) {
      try {
        await _attachmentRepository.create(
          Attachment(
            id: 0,
            ownerType: AttachmentOwnerType.inspiration,
            ownerId: inspirationId,
            fileName: file.fileName,
            filePath: file.path,
            mimeType: file.mimeType,
            size: file.size,
            createdAt: DateTime.now(),
          ),
        );
        savedAttachments += 1;
      } catch (error, stackTrace) {
        failedAttachments += 1;
        debugPrint('Share intake: failed to save attachment: $error');
        debugPrintStack(stackTrace: stackTrace);
        await _fileImporter.deleteStoredFile(file.path);
      }
    }

    return ShareIntakeResult(
      status: ShareIntakeStatus.saved,
      inspirationId: inspirationId,
      attachmentCount: savedAttachments,
      failedAttachmentCount: failedAttachments,
    );
  }

  Future<void> _discardImported(List<ImportedShareFile> files) async {
    for (final file in files) {
      await _fileImporter.deleteStoredFile(file.path);
    }
  }
}
