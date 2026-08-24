import 'package:drift/drift.dart';
import 'package:flashnote/data/datasources/local/app_database.dart' as db;
import 'package:flashnote/domain/entities/chat_message.dart' as domain;
import 'package:flashnote/domain/repositories/global_chat_message_repository.dart';

class GlobalChatMessageRepositoryImpl implements GlobalChatMessageRepository {
  final db.AppDatabase _db;

  GlobalChatMessageRepositoryImpl(this._db);

  domain.ChatMessage _fromRow(db.GlobalChatMessage row) {
    return domain.ChatMessage(
      role:
          row.role == 'user' ? domain.ChatRole.user : domain.ChatRole.assistant,
      content: row.content,
    );
  }

  @override
  Future<List<domain.ChatMessage>> getMessages() async {
    final rows = await _db.getAllGlobalChatMessages();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> create(
    domain.ChatRole role,
    String content, {
    int? inspirationId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = db.GlobalChatMessagesCompanion.insert(
      role: role == domain.ChatRole.user ? 'user' : 'assistant',
      content: content,
      createdAt: now,
      inspirationId: inspirationId == null
          ? const Value.absent()
          : Value(inspirationId),
    );
    return _db.insertGlobalChatMessage(entry);
  }

  @override
  Future<void> deleteAll() async {
    await _db.deleteAllGlobalChatMessages();
  }
}
