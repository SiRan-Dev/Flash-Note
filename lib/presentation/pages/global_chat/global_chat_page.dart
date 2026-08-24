import 'package:flashnote/core/utils/ai_text_formatter.dart';
import 'package:flashnote/core/utils/app_accent_palette.dart';
import 'package:flashnote/core/utils/source_mapper.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/global_chat_providers.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/providers/project_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GlobalChatPage extends ConsumerStatefulWidget {
  const GlobalChatPage({super.key});

  @override
  ConsumerState<GlobalChatPage> createState() => _GlobalChatPageState();
}

class _GlobalChatPageState extends ConsumerState<GlobalChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history =
        await ref.read(globalChatMessageRepositoryProvider).getMessages();
    if (mounted && history.isNotEmpty) {
      setState(() => _messages.addAll(history));
    }
  }

  /// 组装系统上下文（记忆）：用户背景 + 全部灵感/项目汇总。
  Future<String> _buildSystemContext() async {
    final background =
        await ref.read(userProfileStorageProvider).background();
    final inspirations =
        await ref.read(inspirationRepositoryProvider).getAll();
    final projects = await ref.read(projectRepositoryProvider).getAll();

    // 预构建来源显示名映射（CorpusBuilder 保持 context-free）
    final knownSources = [
      'flash',
      'reading',
      'dialogue',
      'observation',
      'problem',
    ];
    final sourceLabels = {
      for (final s in knownSources) s: SourceMapper.displayName(context, s),
    };

    return ref.read(corpusBuilderProvider).build(
      background: background,
      inspirations: inspirations,
      projects: projects,
      sourceLabels: sourceLabels,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _messages.add(
        const ChatMessage(
          role: ChatRole.assistant,
          content: '',
          isLoading: true,
        ),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    final preset = await ref.read(selectedPresetProvider.future);
    final apiKey = await ref.read(currentApiKeyProvider.future);

    if (preset == null || apiKey == null || apiKey.isEmpty) {
      setState(() {
        _messages.last = ChatMessage(
          role: ChatRole.assistant,
          content: AppLocalizations.of(context).apiKeyRequired,
        );
        _isLoading = false;
      });
      return;
    }

    final systemContext = await _buildSystemContext();

    try {
      final service = ref.read(aiServiceProvider);
      final stream = service.globalChat(
        text,
        _messages.sublist(0, _messages.length - 1),
        systemContext,
        preset,
        apiKey,
      );
      await for (final chunk in stream) {
        if (!mounted) break;
        setState(() {
          final current = _messages.last;
          _messages.last = ChatMessage(
            role: ChatRole.assistant,
            content: current.content + chunk,
          );
        });
        _scrollToBottom();
      }
      if (!mounted) return;
      final normalizedAssistant = normalizeAiPlainText(_messages.last.content);
      setState(() {
        _messages.last = ChatMessage(
          role: ChatRole.assistant,
          content: normalizedAssistant,
        );
      });
      final repo = ref.read(globalChatMessageRepositoryProvider);
      await repo.create(ChatRole.user, text);
      await repo.create(ChatRole.assistant, normalizedAssistant);
      setState(() => _isLoading = false);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      final failure = AppLocalizations.of(context).messageSendFailed;
      setState(() {
        final current = _messages.last;
        _messages.last = ChatMessage(
          role: ChatRole.assistant,
          content:
              current.content.isEmpty
                  ? failure
                  : '${current.content}\n\n[$failure]',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.clearGlobalChat),
            content: Text(l10n.clearGlobalChatConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.clearGlobalChat),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await ref.read(globalChatMessageRepositoryProvider).deleteAll();
    if (!mounted) return;
    setState(() => _messages.clear());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.chatCleared)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.globalChat),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.clearGlobalChat,
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              AppPanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppAccentPalette.tintSurfaceStrong(
                          theme.colorScheme,
                          theme.colorScheme.primary,
                          amount: 0.26,
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AppMetricChip(
                                icon: Icons.psychology_alt_outlined,
                                label: l10n.globalChat,
                              ),
                              if (_isLoading)
                                AppMetricChip(
                                  icon: Icons.auto_awesome_rounded,
                                  label: l10n.aiThinking,
                                  accentColor: theme.colorScheme.tertiary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.globalChatDesc,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    _messages.isEmpty
                        ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: AppPanel(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.psychology_alt_outlined,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.globalChat,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.globalChatDesc,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _GlobalMessageBubble(
                              message: _messages[index],
                            );
                          },
                        ),
              ),
              const SizedBox(height: 12),
              AppPanel(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: l10n.typeMessage,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          enabled: !_isLoading,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isLoading ? null : _send,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalMessageBubble extends StatelessWidget {
  const _GlobalMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == ChatRole.user;
    final content =
        isUser ? message.content : normalizeAiPlainText(message.content);
    final accent =
        isUser ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final fill =
        isUser
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.96)
            : AppAccentPalette.tintSurface(
              theme.colorScheme,
              accent,
              amount: 0.12,
            ).withValues(alpha: 0.98);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child:
              message.isLoading
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppLocalizations.of(context).aiThinking,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  )
                  : SelectableText(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          isUser
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                      height: 1.42,
                    ),
                  ),
        ),
      ),
    );
  }
}
