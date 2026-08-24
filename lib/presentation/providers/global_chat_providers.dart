import 'package:flashnote/data/datasources/local/user_profile_storage.dart';
import 'package:flashnote/data/repositories/global_chat_message_repository_impl.dart';
import 'package:flashnote/data/services/corpus_builder.dart';
import 'package:flashnote/domain/repositories/global_chat_message_repository.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final globalChatMessageRepositoryProvider =
    Provider<GlobalChatMessageRepository>((ref) {
  return GlobalChatMessageRepositoryImpl(ref.watch(databaseProvider));
});

final userProfileStorageProvider = Provider<UserProfileStorage>((ref) {
  return UserProfileStorage();
});

final corpusBuilderProvider = Provider<CorpusBuilder>((ref) {
  return CorpusBuilder();
});
