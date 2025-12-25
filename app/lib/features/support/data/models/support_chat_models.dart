// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/storage/local_cache.dart';

enum SupportChatSender { user, bot, agent, system }

enum SupportChatStage { bot, handoff, liveAgent }

enum SupportChatConnectionState { connected, reconnecting, offline }

class SupportChatMessage {
  const SupportChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final SupportChatSender sender;
  final String text;
  final DateTime sentAt;

  bool get isUser => sender == SupportChatSender.user;
  bool get isSystem => sender == SupportChatSender.system;

  JsonMap toJson() {
    return {
      'id': id,
      'sender': sender.name,
      'text': text,
      'sentAt': sentAt.millisecondsSinceEpoch,
    };
  }

  static SupportChatMessage fromJson(JsonMap map) {
    final senderValue = map['sender'];
    final sender = senderValue is String
        ? SupportChatSender.values.firstWhere(
            (item) => item.name == senderValue,
            orElse: () => SupportChatSender.bot,
          )
        : SupportChatSender.bot;

    return SupportChatMessage(
      id: map['id'] as String,
      sender: sender,
      text: map['text'] as String,
      sentAt: DateTime.fromMillisecondsSinceEpoch(map['sentAt'] as int),
    );
  }
}

class SupportChatSession {
  const SupportChatSession({
    required this.messages,
    required this.stage,
    required this.updatedAt,
  });

  final List<SupportChatMessage> messages;
  final SupportChatStage stage;
  final DateTime updatedAt;

  SupportChatSession copyWith({
    List<SupportChatMessage>? messages,
    SupportChatStage? stage,
    DateTime? updatedAt,
  }) {
    return SupportChatSession(
      messages: messages ?? this.messages,
      stage: stage ?? this.stage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  JsonMap toJson() {
    return {
      'messages': messages.map((message) => message.toJson()).toList(),
      'stage': stage.name,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  static SupportChatSession fromJson(JsonMap map) {
    final rawMessages = map['messages'];
    final messages = rawMessages is List
        ? rawMessages.whereType<Map<dynamic, dynamic>>().map((entry) {
            final map = Map<String, Object?>.from(entry);
            return SupportChatMessage.fromJson(map);
          }).toList()
        : <SupportChatMessage>[];

    final stageValue = map['stage'];
    final stage = stageValue is String
        ? SupportChatStage.values.firstWhere(
            (item) => item.name == stageValue,
            orElse: () => SupportChatStage.bot,
          )
        : SupportChatStage.bot;

    final updatedAtValue = map['updatedAt'];
    final updatedAt = updatedAtValue is int
        ? DateTime.fromMillisecondsSinceEpoch(updatedAtValue)
        : DateTime.now();

    return SupportChatSession(
      messages: messages,
      stage: stage,
      updatedAt: updatedAt,
    );
  }
}

String createSupportChatMessageId([Random? random]) {
  final now = DateTime.now().microsecondsSinceEpoch;
  final entropy = (random ?? Random()).nextInt(1 << 20);
  return 'support-chat-$now-$entropy';
}
