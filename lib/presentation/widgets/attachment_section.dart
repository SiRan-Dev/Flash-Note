import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flashnote/data/services/attachment_file_store.dart';
import 'package:flashnote/domain/entities/attachment.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/attachment_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttachmentSection extends ConsumerWidget {
  const AttachmentSection({
    super.key,
    required this.ownerType,
    required this.ownerId,
  });

  final AttachmentOwnerType ownerType;
  final int ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final attachmentsAsync = ref.watch(attachmentListProvider(
      (ownerType: ownerType, ownerId: ownerId),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(l10n.attachments,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
              onPressed: () => _pickAndAddAttachment(context, ref),
              tooltip: l10n.addAttachment,
            ),
          ],
        ),
        const SizedBox(height: 8),
        attachmentsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Text('${l10n.loadFailed}: $e'),
          data: (attachments) {
            if (attachments.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.attach_file,
                        size: 32, color: theme.colorScheme.outline),
                    const SizedBox(height: 4),
                    Text(l10n.noAttachments,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                itemBuilder: (context, index) {
                  final att = attachments[index];
                  return _AttachmentThumbnail(
                    attachment: att,
                    onTap: () => _previewAttachment(context, att),
                    onLongPress: () =>
                        _showDeleteDialog(context, ref, att),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickAndAddAttachment(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePicker.pickFiles();

      if (result.isEmpty) return;

      final file = result.first;
      final fileName = file.name;
      final sourcePath = file.path;
      if (sourcePath == null) return;

      final stored = await AttachmentFileStore().importFile(
        sourcePath: sourcePath,
        fileName: fileName,
      );

      final attachment = Attachment(
        id: 0,
        ownerType: ownerType,
        ownerId: ownerId,
        fileName: stored.fileName,
        filePath: stored.path,
        mimeType: stored.mimeType,
        size: stored.size,
        createdAt: DateTime.now(),
      );

      final repo = ref.read(attachmentRepositoryProvider);
      await repo.create(attachment);

      ref.invalidate(attachmentListProvider(
        (ownerType: ownerType, ownerId: ownerId),
      ));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.attachmentAdded)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.attachmentAddFailed}: $e')),
        );
      }
    }
  }

  void _previewAttachment(BuildContext context, Attachment att) {
    if (att.mimeType.startsWith('image/')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ImagePreviewPage(attachment: att),
        ),
      );
    } else if (att.mimeType.startsWith('video/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${att.fileName} (${att.mimeType})')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${att.fileName} (${att.mimeType})')),
      );
    }
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, Attachment att) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAttachment),
        content: Text(l10n.deleteAttachmentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Delete file
              final file = File(att.filePath);
              if (await file.exists()) {
                await file.delete();
              }
              // Delete from DB
              final repo = ref.read(attachmentRepositoryProvider);
              await repo.delete(att.id);
              ref.invalidate(attachmentListProvider(
                (ownerType: ownerType, ownerId: ownerId),
              ));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.attachmentDeleted)),
                );
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _AttachmentThumbnail extends StatelessWidget {
  const _AttachmentThumbnail({
    required this.attachment,
    required this.onTap,
    required this.onLongPress,
  });

  final Attachment attachment;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = attachment.mimeType.startsWith('image/');
    final file = File(attachment.filePath);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: isImage && file.existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_iconForMime(attachment.mimeType),
                      size: 24, color: theme.colorScheme.primary),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _iconForMime(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('video/')) return Icons.videocam_outlined;
    if (mime.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('word')) return Icons.description_outlined;
    if (mime.contains('excel') || mime.contains('sheet')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}

class _ImagePreviewPage extends StatelessWidget {
  const _ImagePreviewPage({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final file = File(attachment.filePath);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(attachment.fileName,
            style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: file.existsSync()
              ? Image.file(file)
              : const Icon(Icons.broken_image,
                  color: Colors.white, size: 64),
        ),
      ),
    );
  }
}
