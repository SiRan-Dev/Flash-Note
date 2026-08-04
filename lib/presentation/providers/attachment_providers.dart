import 'package:flashnote/data/repositories/attachment_repository_impl.dart';
import 'package:flashnote/domain/entities/attachment.dart';
import 'package:flashnote/domain/repositories/attachment_repository.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return AttachmentRepositoryImpl(ref.watch(databaseProvider));
});

/// 获取指定 owner 的附件列表
final attachmentListProvider = FutureProvider.family<List<Attachment>,
    ({AttachmentOwnerType ownerType, int ownerId})>((ref, params) {
  final repo = ref.watch(attachmentRepositoryProvider);
  return repo.getByOwner(params.ownerType, params.ownerId);
});
