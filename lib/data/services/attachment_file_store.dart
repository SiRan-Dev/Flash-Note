import 'dart:io';

import 'package:flashnote/data/services/share_intake_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 把文件复制到 `<应用文档目录>/attachments` 并保留原始文件名。
///
/// 手动添加附件与系统分享共用同一套落盘规则，避免两套命名 / 目录逻辑。
class AttachmentFileStore implements SharedFileImporter {
  AttachmentFileStore({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;
  Future<Directory>? _directory;

  Future<Directory> _attachmentsDirectory() {
    return _directory ??= () async {
      final appDir = await _documentsDirectory();
      final dir = Directory(p.join(appDir.path, 'attachments'));
      await dir.create(recursive: true);
      return dir;
    }();
  }

  Future<ImportedShareFile> importFile({
    required String sourcePath,
    required String fileName,
    String? mimeType,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Source file does not exist', sourcePath);
    }

    final dir = await _attachmentsDirectory();
    final safeName = sanitizeFileName(fileName);
    final destPath = p.join(
      dir.path,
      '${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await source.copy(destPath);

    final size = await File(destPath).length();
    final resolvedMime = (mimeType != null && mimeType.contains('/'))
        ? mimeType
        : mimeTypeFromExtension(p.extension(safeName));

    return ImportedShareFile(
      path: destPath,
      fileName: safeName,
      mimeType: resolvedMime,
      size: size,
    );
  }

  @override
  Future<ImportedShareFile> importAttachment(
    IncomingShareAttachment attachment,
  ) {
    return importFile(
      sourcePath: attachment.path,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
    );
  }

  @override
  Future<void> discardTemporaryFile(String path) => _deleteQuietly(path);

  @override
  Future<void> deleteStoredFile(String path) => _deleteQuietly(path);

  Future<void> _deleteQuietly(String path) async {
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 清理失败不应中断捕捉流程。
    }
  }

  static String sanitizeFileName(String name) {
    final base = name.replaceAll('\\', '/').split('/').last.trim();
    final cleaned = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '_')
        .trim();
    final result = cleaned.isEmpty ? 'attachment' : cleaned;
    return result.length > 120 ? result.substring(result.length - 120) : result;
  }

  static String mimeTypeFromExtension(String extension) {
    return switch (extension.toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.svg' => 'image/svg+xml',
      '.mp4' => 'video/mp4',
      '.mov' => 'video/quicktime',
      '.avi' => 'video/x-msvideo',
      '.pdf' => 'application/pdf',
      '.doc' || '.docx' => 'application/msword',
      '.xls' || '.xlsx' => 'application/vnd.ms-excel',
      '.txt' => 'text/plain',
      '.json' => 'application/json',
      _ => 'application/octet-stream',
    };
  }
}
