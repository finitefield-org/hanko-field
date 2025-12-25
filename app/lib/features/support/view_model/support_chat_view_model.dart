// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/features/support/data/models/support_chat_models.dart';
import 'package:app/features/support/data/repositories/support_chat_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SupportChatState {
  const SupportChatState({
    required this.messages,
    required this.stage,
    required this.connectionState,
    required this.isAgentTyping,
  });

  final List<SupportChatMessage> messages;
  final SupportChatStage stage;
  final SupportChatConnectionState connectionState;
  final bool isAgentTyping;

  bool get isLiveAgent => stage == SupportChatStage.liveAgent;
  bool get showConnectionBanner =>
      connectionState == SupportChatConnectionState.offline;

  SupportChatState copyWith({
    List<SupportChatMessage>? messages,
    SupportChatStage? stage,
    SupportChatConnectionState? connectionState,
    bool? isAgentTyping,
  }) {
    return SupportChatState(
      messages: messages ?? this.messages,
      stage: stage ?? this.stage,
      connectionState: connectionState ?? this.connectionState,
      isAgentTyping: isAgentTyping ?? this.isAgentTyping,
    );
  }
}

final supportChatViewModel = SupportChatViewModel();

class SupportChatViewModel extends AsyncProvider<SupportChatState> {
  SupportChatViewModel() : super.args(null, autoDispose: true);

  late final sendMut = mutation<void>(#send);
  late final retryConnectionMut = mutation<void>(#retryConnection);

  final Random _random = Random();
  SupportChatConnectionState _lastConnectionState =
      SupportChatConnectionState.connected;

  @override
  Future<SupportChatState> build(Ref ref) async {
    final repository = ref.watch(supportChatRepositoryProvider);
    final session = await repository.fetchSession();

    final sub = repository.incomingMessages.listen((_) {
      ref.invalidate(this);
    });
    ref.onDispose(sub.cancel);

    return SupportChatState(
      messages: session.messages,
      stage: session.stage,
      connectionState: _lastConnectionState,
      isAgentTyping: false,
    );
  }

  Call<void> sendMessage(String text) => mutate(sendMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (current.connectionState != SupportChatConnectionState.connected) {
      return;
    }

    final repository = ref.watch(supportChatRepositoryProvider);
    final now = DateTime.now();
    final userMessage = SupportChatMessage(
      id: createSupportChatMessageId(_random),
      sender: SupportChatSender.user,
      text: trimmed,
      sentAt: now,
    );

    final withUser = current.copyWith(
      messages: [...current.messages, userMessage],
      isAgentTyping: true,
    );
    ref.state = AsyncData(withUser);
    await repository.saveSession(
      SupportChatSession(
        messages: withUser.messages,
        stage: withUser.stage,
        updatedAt: now,
      ),
    );

    await _respondToUser(ref, withUser, trimmed);
  }, concurrency: Concurrency.dropLatest);

  Call<void> retryConnection() => mutate(retryConnectionMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;

    ref.state = AsyncData(
      current.copyWith(
        connectionState: SupportChatConnectionState.reconnecting,
      ),
    );
    _lastConnectionState = SupportChatConnectionState.reconnecting;
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final recovered = _random.nextBool();
    final nextState = recovered
        ? SupportChatConnectionState.connected
        : SupportChatConnectionState.offline;
    _lastConnectionState = nextState;
    ref.state = AsyncData(current.copyWith(connectionState: nextState));
  }, concurrency: Concurrency.dropLatest);

  Future<void> _respondToUser(
    Ref ref,
    SupportChatState state,
    String message,
  ) async {
    final repository = ref.watch(supportChatRepositoryProvider);
    final prefersEnglish = ref.watch(appExperienceGatesProvider).prefersEnglish;
    final now = DateTime.now();

    if (state.stage == SupportChatStage.bot) {
      final shouldHandoff = _shouldHandoff(state.messages, message);
      final botReply = _botReply(message, prefersEnglish, shouldHandoff);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      var nextState = _appendIncoming(
        state,
        SupportChatMessage(
          id: createSupportChatMessageId(_random),
          sender: SupportChatSender.bot,
          text: botReply,
          sentAt: now.add(const Duration(milliseconds: 700)),
        ),
      );
      ref.state = AsyncData(nextState.copyWith(isAgentTyping: shouldHandoff));
      await repository.saveSession(
        SupportChatSession(
          messages: nextState.messages,
          stage: nextState.stage,
          updatedAt: DateTime.now(),
        ),
      );

      if (!shouldHandoff) {
        ref.state = AsyncData(nextState.copyWith(isAgentTyping: false));
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 900));
      final systemMessage = prefersEnglish
          ? 'You are now connected with Rina (Support Agent).'
          : 'サポート担当の理奈が参加しました。';
      nextState = _appendIncoming(
        nextState.copyWith(stage: SupportChatStage.handoff),
        SupportChatMessage(
          id: createSupportChatMessageId(_random),
          sender: SupportChatSender.system,
          text: systemMessage,
          sentAt: now.add(const Duration(milliseconds: 1600)),
        ),
      );
      ref.state = AsyncData(nextState);
      await repository.saveSession(
        SupportChatSession(
          messages: nextState.messages,
          stage: nextState.stage,
          updatedAt: DateTime.now(),
        ),
      );

      final agentReply = prefersEnglish
          ? "Hi, I'm Rina. I can take it from here. Could you share an order ID?"
          : '理奈です。こちらで対応します。注文IDがあれば教えてください。';
      await Future<void>.delayed(const Duration(milliseconds: 700));
      nextState = _appendIncoming(
        nextState.copyWith(stage: SupportChatStage.liveAgent),
        SupportChatMessage(
          id: createSupportChatMessageId(_random),
          sender: SupportChatSender.agent,
          text: agentReply,
          sentAt: now.add(const Duration(milliseconds: 2300)),
        ),
      );
      ref.state = AsyncData(nextState.copyWith(isAgentTyping: false));
      await repository.saveSession(
        SupportChatSession(
          messages: nextState.messages,
          stage: nextState.stage,
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }

    final agentReply = _agentReply(message, prefersEnglish);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final nextState = _appendIncoming(
      state,
      SupportChatMessage(
        id: createSupportChatMessageId(_random),
        sender: SupportChatSender.agent,
        text: agentReply,
        sentAt: now.add(const Duration(milliseconds: 700)),
      ),
    );
    ref.state = AsyncData(nextState.copyWith(isAgentTyping: false));
    await repository.saveSession(
      SupportChatSession(
        messages: nextState.messages,
        stage: nextState.stage,
        updatedAt: DateTime.now(),
      ),
    );
  }

  bool _shouldHandoff(List<SupportChatMessage> messages, String message) {
    final lowered = message.toLowerCase();
    if (lowered.contains('agent') ||
        lowered.contains('human') ||
        lowered.contains('support')) {
      return true;
    }
    if (message.contains('担当') || message.contains('オペレーター')) {
      return true;
    }
    final userMessages = messages
        .where((item) => item.sender == SupportChatSender.user)
        .length;
    return userMessages >= 2;
  }

  String _botReply(String message, bool prefersEnglish, bool handingOff) {
    if (handingOff) {
      return prefersEnglish
          ? 'Got it. I am connecting you to a specialist.'
          : '承知しました。担当者におつなぎします。';
    }
    if (message.toLowerCase().contains('delivery') || message.contains('配送')) {
      return prefersEnglish
          ? 'Delivery usually takes 3-5 business days. Do you have an order ID?'
          : '通常は3〜5営業日でお届けします。注文IDはお持ちですか？';
    }
    if (message.toLowerCase().contains('order') || message.contains('注文')) {
      return prefersEnglish
          ? 'I can check order status. Please share the order ID if you have it.'
          : '注文状況を確認できます。注文IDを教えてください。';
    }
    return prefersEnglish
        ? 'I can help with orders, delivery, or seal specs. What do you need?'
        : '注文状況、配送、印面についてお手伝いできます。ご用件を教えてください。';
  }

  String _agentReply(String message, bool prefersEnglish) {
    if (message.toLowerCase().contains('refund') || message.contains('返金')) {
      return prefersEnglish
          ? 'I can help with refunds. Which order should we review?'
          : '返金の件ですね。対象の注文IDを教えてください。';
    }
    if (message.toLowerCase().contains('address') || message.contains('住所')) {
      return prefersEnglish
          ? 'I can update the delivery address if production has not started.'
          : '制作前であれば配送先の変更が可能です。注文IDを教えてください。';
    }
    return prefersEnglish
        ? 'Thanks, I am checking now. I will update you shortly.'
        : '確認しますので少々お待ちください。';
  }

  SupportChatState _appendIncoming(
    SupportChatState state,
    SupportChatMessage message,
  ) {
    return state.copyWith(messages: [...state.messages, message]);
  }
}
