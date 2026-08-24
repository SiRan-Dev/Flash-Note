import 'package:flashnote/domain/entities/chat_message.dart';

abstract class GlobalChatMessageRepository {
  Future<List<ChatMessage>> getMessages();
  Future<int> create(ChatRole role, String content, {int? inspirationId});
  Future<void> deleteAll();
}
