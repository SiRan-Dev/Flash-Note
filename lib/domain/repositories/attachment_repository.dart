import 'package:flashnote/domain/entities/attachment.dart';

abstract class AttachmentRepository {
  Future<List<Attachment>> getByOwner(AttachmentOwnerType ownerType, int ownerId);
  Future<Attachment?> getById(int id);
  Future<int> create(Attachment attachment);
  Future<int> delete(int id);
  Future<int> deleteByOwner(AttachmentOwnerType ownerType, int ownerId);
}
