import 'package:flashnote/domain/entities/chat_message.dart';

abstract class ChatMessageRepository {
  Future<List<ChatMessage>> getByInspirationId(int inspirationId);
  Future<int> create(int inspirationId, ChatRole role, String content);
  Future<void> deleteByInspirationId(int inspirationId);
}
