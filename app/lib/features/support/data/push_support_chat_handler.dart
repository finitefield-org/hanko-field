// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/routes.dart';
import 'package:app/features/support/data/models/support_chat_models.dart';
import 'package:app/features/support/data/repositories/support_chat_repository.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SupportChatPushHandler extends AsyncProvider<void> {
  SupportChatPushHandler() : super.args(null, autoDispose: false);

  @override
  Future<void> build(Ref ref) async {
    final messaging = ref.watch(firebaseMessagingProvider);
    final repository = ref.watch(supportChatRepositoryProvider);
    final logger = Logger('SupportChatPushHandler');

    Future<void> handle(RemoteMessage message) async {
      final data = Map<String, Object?>.from(message.data);
      if (!_isSupportChatMessage(data)) return;

      final body =
          (data['body'] as String?) ?? message.notification?.body ?? '';
      final trimmed = body.trim();
      if (trimmed.isEmpty) return;

      final sender = _parseSender(data['sender'] ?? data['from']);
      final stage = _parseStage(data['stage']);

      try {
        await repository.addIncomingMessage(
          trimmed,
          sender: sender,
          stage: stage,
        );
      } catch (e, stack) {
        logger.warning('Failed to persist support chat push', e, stack);
      }
    }

    final foregroundSub = FirebaseMessaging.onMessage.listen(handle);
    final openedSub = FirebaseMessaging.onMessageOpenedApp.listen(handle);
    ref.onDispose(foregroundSub.cancel);
    ref.onDispose(openedSub.cancel);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      unawaited(handle(initial));
    }
  }

  bool _isSupportChatMessage(Map<String, Object?> data) {
    final route = data['route'] ?? data['target'] ?? data['link'];
    if (route is String && route.contains(AppRoutePaths.supportChat)) {
      return true;
    }
    final category = data['category'] ?? data['type'];
    if (category is String &&
        (category == 'support' || category == 'support_chat')) {
      return true;
    }
    return false;
  }

  SupportChatSender _parseSender(Object? value) {
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'bot':
          return SupportChatSender.bot;
        case 'agent':
        case 'human':
        case 'support':
          return SupportChatSender.agent;
        case 'system':
          return SupportChatSender.system;
      }
    }
    return SupportChatSender.agent;
  }

  SupportChatStage? _parseStage(Object? value) {
    if (value is String) {
      for (final stage in SupportChatStage.values) {
        if (stage.name == value) return stage;
      }
    }
    return null;
  }
}

final supportChatPushHandlerProvider = SupportChatPushHandler();
