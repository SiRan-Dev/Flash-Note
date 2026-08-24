import 'package:freezed_annotation/freezed_annotation.dart';

part 'attachment.freezed.dart';
part 'attachment.g.dart';

enum AttachmentOwnerType { inspiration, project }

@freezed
abstract class Attachment with _$Attachment {
  const factory Attachment({
    required int id,
    required AttachmentOwnerType ownerType,
    required int ownerId,
    required String fileName,
    required String filePath,
    required String mimeType,
    @Default(0) int size,
    required DateTime createdAt,
  }) = _Attachment;

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);
}
