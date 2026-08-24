import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

enum ChatRole { user, assistant }

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required ChatRole role,
    required String content,
    @Default(false) bool isLoading,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
