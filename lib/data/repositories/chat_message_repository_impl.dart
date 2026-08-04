import 'package:flashnote/data/datasources/local/app_database.dart' as db;
import 'package:flashnote/domain/entities/chat_message.dart' as domain;
import 'package:flashnote/domain/repositories/chat_message_repository.dart';

class ChatMessageRepositoryImpl implements ChatMessageRepository {
  final db.AppDatabase _db;

  ChatMessageRepositoryImpl(this._db);

  domain.ChatMessage _fromRow(db.ChatMessage row) {
    return domain.ChatMessage(
      role:
          row.role == 'user' ? domain.ChatRole.user : domain.ChatRole.assistant,
      content: row.content,
    );
  }

  @override
  Future<List<domain.ChatMessage>> getByInspirationId(int inspirationId) async {
    final rows = await _db.getChatMessagesByInspirationId(inspirationId);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> create(int inspirationId, domain.ChatRole role, String content) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = db.ChatMessagesCompanion.insert(
      inspirationId: inspirationId,
      role: role == domain.ChatRole.user ? 'user' : 'assistant',
      content: content,
      createdAt: now,
    );
    return _db.insertChatMessage(entry);
  }

  @override
  Future<void> deleteByInspirationId(int inspirationId) async {
    final rows = await _db.getChatMessagesByInspirationId(inspirationId);
    for (final row in rows) {
      await _db.markRecordDeleted('chatMessages', row.id);
    }
    await _db.deleteChatMessagesByInspirationId(inspirationId);
  }
}
