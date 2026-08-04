import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/app_database.dart' as db;
import 'package:flashnote/domain/entities/attachment.dart' as domain;
import 'package:flashnote/domain/repositories/attachment_repository.dart';

class AttachmentRepositoryImpl implements AttachmentRepository {
  final db.AppDatabase _db;

  AttachmentRepositoryImpl(this._db);

  String _ownerTypeToString(domain.AttachmentOwnerType type) {
    switch (type) {
      case domain.AttachmentOwnerType.inspiration:
        return 'inspiration';
      case domain.AttachmentOwnerType.project:
        return 'project';
    }
  }

  domain.AttachmentOwnerType _ownerTypeFromString(String value) {
    switch (value) {
      case 'inspiration':
        return domain.AttachmentOwnerType.inspiration;
      case 'project':
        return domain.AttachmentOwnerType.project;
      default:
        return domain.AttachmentOwnerType.inspiration;
    }
  }

  domain.Attachment _fromRow(db.Attachment row) {
    return domain.Attachment(
      id: row.id,
      ownerType: _ownerTypeFromString(row.ownerType),
      ownerId: row.ownerId,
      fileName: row.fileName,
      filePath: row.filePath,
      mimeType: row.mimeType,
      size: row.size,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }

  @override
  Future<List<domain.Attachment>> getByOwner(
    domain.AttachmentOwnerType ownerType,
    int ownerId,
  ) async {
    final rows = await _db.getAttachmentsByOwner(
      _ownerTypeToString(ownerType),
      ownerId,
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<domain.Attachment?> getById(int id) async {
    final row = await _db.getAttachmentById(id);
    return row != null ? _fromRow(row) : null;
  }

  @override
  Future<int> create(domain.Attachment attachment) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = db.AttachmentsCompanion.insert(
      ownerType: _ownerTypeToString(attachment.ownerType),
      ownerId: attachment.ownerId,
      fileName: attachment.fileName,
      filePath: attachment.filePath,
      mimeType: attachment.mimeType,
      size: Value(attachment.size),
      createdAt: now,
    );
    return _db.insertAttachment(entry);
  }

  @override
  Future<int> delete(int id) async {
    await _db.markRecordDeleted('attachments', id);
    return _db.deleteAttachment(id);
  }

  @override
  Future<int> deleteByOwner(
    domain.AttachmentOwnerType ownerType,
    int ownerId,
  ) async {
    final ownerTypeValue = _ownerTypeToString(ownerType);
    final attachments = await _db.getAttachmentsByOwner(
      ownerTypeValue,
      ownerId,
    );
    for (final attachment in attachments) {
      await _db.markRecordDeleted('attachments', attachment.id);
    }
    return _db.deleteAttachmentsByOwner(ownerTypeValue, ownerId);
  }
}
