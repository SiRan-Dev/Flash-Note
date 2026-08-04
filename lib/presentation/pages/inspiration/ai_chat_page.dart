import 'package:flashnote/core/utils/ai_text_formatter.dart';
import 'package:flashnote/core/utils/app_accent_palette.dart';
import 'package:flashnote/domain/entities/chat_message.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/providers/ai_providers.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({
    super.key,
    required this.inspirationId,
    required this.content,
  });

  final int inspirationId;
  final String content;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
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
    final history = await ref
        .read(chatMessageRepositoryProvider)
        .getByInspirationId(widget.inspirationId);
    if (mounted && history.isNotEmpty) {
      setState(() => _messages.addAll(history));
    }
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

    try {
      final service = ref.read(aiServiceProvider);
      final stream = service.chat(
        widget.content,
        _messages.sublist(0, _messages.length - 1),
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
      final repo = ref.read(chatMessageRepositoryProvider);
      await repo.create(widget.inspirationId, ChatRole.user, text);
      await repo.create(
        widget.inspirationId,
        ChatRole.assistant,
        normalizedAssistant,
      );
      ref.invalidate(chatMessagesCacheProvider(widget.inspirationId));
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
    final copy = _ChatCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.aiChat),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.clearChatHistory,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final message = l10n.chatCleared;
                await ref
                    .read(chatMessageRepositoryProvider)
                    .deleteByInspirationId(widget.inspirationId);
                ref.invalidate(chatMessagesCacheProvider(widget.inspirationId));
                if (!mounted) return;
                setState(() => _messages.clear());
                messenger.showSnackBar(SnackBar(content: Text(message)));
              },
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
                        Icons.lightbulb_outline_rounded,
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
                                icon: Icons.forum_outlined,
                                label: copy.contextTitle,
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
                            widget.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
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
                                    Icons.chat_bubble_outline_rounded,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.aiChatWithInspiration,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    copy.emptySubtitle,
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
                            return _MessageBubble(message: _messages[index]);
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

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

class _ChatCopy {
  const _ChatCopy({required this.isZh});

  _ChatCopy.of(BuildContext context)
    : isZh = Localizations.localeOf(context).languageCode == 'zh';

  final bool isZh;

  String get contextTitle => isZh ? '当前灵感上下文' : 'Current inspiration';
  String get emptySubtitle =>
      isZh
          ? '让 AI 围绕这条灵感继续拆解、追问和延展。'
          : 'Use the chat to expand, challenge, and refine this idea.';
}
