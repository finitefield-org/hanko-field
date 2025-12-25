// ignore_for_file: public_member_api_docs

import 'package:app/features/support/data/models/support_chat_models.dart';
import 'package:app/features/support/view_model/support_chat_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({super.key});

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final router = GoRouter.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(supportChatViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        backgroundColor: tokens.colors.surface,
        centerTitle: true,
        title: Text(prefersEnglish ? 'Support chat' : 'サポートチャット'),
        leading: IconButton(
          tooltip: prefersEnglish ? 'Back' : '戻る',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => router.pop(),
        ),
        actions: [
          if (state.valueOrNull != null)
            Padding(
              padding: EdgeInsets.only(right: tokens.spacing.md),
              child: Chip(
                avatar: Icon(
                  Icons.circle,
                  size: 12,
                  color: _presenceColor(tokens, state.valueOrNull!),
                ),
                label: Text(_presenceLabel(prefersEnglish, state.valueOrNull!)),
              ),
            ),
        ],
      ),
      body: switch (state) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError() => _ErrorState(prefersEnglish: prefersEnglish),
        AsyncData(:final value) => Column(
          children: [
            if (value.showConnectionBanner)
              MaterialBanner(
                backgroundColor: tokens.colors.surfaceVariant,
                content: Text(
                  prefersEnglish
                      ? 'Connection lost. Retry to send messages.'
                      : '接続が切れました。再接続して送信してください。',
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await ref.invoke(supportChatViewModel.retryConnection());
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            prefersEnglish
                                ? 'Retrying connection...'
                                : '再接続しています...',
                          ),
                        ),
                      );
                    },
                    child: Text(prefersEnglish ? 'Retry' : '再試行'),
                  ),
                ],
              ),
            Expanded(
              child: _MessageList(
                controller: _scrollController,
                tokens: tokens,
                messages: value.messages,
                isTyping: value.isAgentTyping,
              ),
            ),
          ],
        ),
      },
      bottomNavigationBar: state.valueOrNull == null
          ? null
          : _ComposerBar(
              controller: _controller,
              tokens: tokens,
              prefersEnglish: prefersEnglish,
              onSend: _sendMessage,
            ),
    );
  }

  Color _presenceColor(DesignTokens tokens, SupportChatState state) {
    if (state.connectionState == SupportChatConnectionState.offline) {
      return tokens.colors.warning;
    }
    return state.isLiveAgent ? tokens.colors.success : tokens.colors.secondary;
  }

  String _presenceLabel(bool prefersEnglish, SupportChatState state) {
    if (state.connectionState == SupportChatConnectionState.offline) {
      return prefersEnglish ? 'Offline' : 'オフライン';
    }
    if (state.connectionState == SupportChatConnectionState.reconnecting) {
      return prefersEnglish ? 'Reconnecting' : '再接続中';
    }
    if (state.stage == SupportChatStage.handoff) {
      return prefersEnglish ? 'Connecting agent' : '担当者に接続中';
    }
    return state.isLiveAgent
        ? (prefersEnglish ? 'Agent online' : '担当者が対応中')
        : (prefersEnglish ? 'Bot online' : 'ボット対応中');
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final state = ref.container.read(supportChatViewModel).valueOrNull;
    if (state?.connectionState != SupportChatConnectionState.connected) {
      final prefersEnglish = ref.container
          .read(appExperienceGatesProvider)
          .prefersEnglish;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish
                ? 'Message not sent. Retry when reconnected.'
                : '接続後に送信してください。',
          ),
        ),
      );
      return;
    }
    await ref.invoke(supportChatViewModel.sendMessage(text));
    _controller.clear();
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.controller,
    required this.tokens,
    required this.messages,
    required this.isTyping,
  });

  final ScrollController controller;
  final DesignTokens tokens;
  final List<SupportChatMessage> messages;
  final bool isTyping;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  int _lastMessageCount = 0;
  bool _lastTyping = false;

  @override
  Widget build(BuildContext context) {
    if (_lastMessageCount != widget.messages.length ||
        _lastTyping != widget.isTyping) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      _lastMessageCount = widget.messages.length;
      _lastTyping = widget.isTyping;
    }

    return ListView.builder(
      controller: widget.controller,
      padding: EdgeInsets.fromLTRB(
        widget.tokens.spacing.lg,
        widget.tokens.spacing.md,
        widget.tokens.spacing.lg,
        widget.tokens.spacing.md,
      ),
      itemCount: widget.messages.length + (widget.isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (widget.isTyping && index == widget.messages.length) {
          return Padding(
            padding: EdgeInsets.only(top: widget.tokens.spacing.sm),
            child: _TypingBubble(tokens: widget.tokens),
          );
        }
        final message = widget.messages[index];
        return _MessageBubble(tokens: widget.tokens, message: message);
      },
    );
  }

  void _scrollToBottom() {
    if (!widget.controller.hasClients) return;
    widget.controller.animateTo(
      widget.controller.position.maxScrollExtent,
      duration: widget.tokens.durations.regular,
      curve: Curves.easeOut,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.tokens, required this.message});

  final DesignTokens tokens;
  final SupportChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isUser;
    final alignment = isOutgoing ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isSystem
        ? tokens.colors.surfaceVariant
        : (isOutgoing ? tokens.colors.surfaceVariant : tokens.colors.surface);
    final textColor = tokens.colors.onSurface;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.74;
    final time = TimeOfDay.fromDateTime(message.sentAt).format(context);

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.sm),
      child: Align(
        alignment: message.isSystem ? Alignment.center : alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(tokens.radii.md),
              border: message.isSystem
                  ? Border.all(
                      color: tokens.colors.outline.withValues(alpha: 0.4),
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.md,
                vertical: tokens.spacing.sm,
              ),
              child: Column(
                crossAxisAlignment: message.isSystem
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Align(
                    alignment: isOutgoing
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Text(
                      time,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: textColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.surface,
          borderRadius: BorderRadius.circular(tokens.radii.md),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.md,
            vertical: tokens.spacing.sm,
          ),
          child: _TypingDots(tokens: tokens),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.tokens});

  final DesignTokens tokens;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final phase = (_controller.value + index * 0.2) % 1.0;
              final opacity = 0.3 + 0.7 * (0.5 - (phase - 0.5).abs());
              return Opacity(
                opacity: opacity,
                child: _Dot(color: widget.tokens.colors.onSurface),
              );
            }),
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.tokens,
    required this.prefersEnglish,
    required this.onSend,
  });

  final TextEditingController controller;
  final DesignTokens tokens;
  final bool prefersEnglish;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: tokens.colors.surface,
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.md,
        tokens.spacing.sm,
        tokens.spacing.md,
        tokens.spacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: prefersEnglish ? 'Attach file' : 'ファイルを添付',
            icon: const Icon(Icons.attach_file_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    prefersEnglish
                        ? 'Attachment uploads are coming soon.'
                        : '添付機能は準備中です。',
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: prefersEnglish ? 'Type your message' : 'メッセージを入力',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radii.md),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radii.md),
                  borderSide: BorderSide(color: tokens.colors.outline),
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.sm),
          FilledButton.tonal(
            onPressed: onSend,
            child: Text(prefersEnglish ? 'Send' : '送信'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.prefersEnglish});

  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        prefersEnglish
            ? 'Unable to load chat. Please try again.'
            : 'チャットを読み込めませんでした。再試行してください。',
      ),
    );
  }
}
