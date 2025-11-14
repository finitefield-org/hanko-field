import 'package:flutter/foundation.dart';

@immutable
class SupportCenterSnapshot {
  SupportCenterSnapshot({
    required List<SupportQuickAction> actions,
    required List<SupportTicket> tickets,
    required this.updatedAt,
  }) : actions = List.unmodifiable(actions),
       tickets = List.unmodifiable(tickets);

  final List<SupportQuickAction> actions;
  final List<SupportTicket> tickets;
  final DateTime updatedAt;

  SupportCenterSnapshot copyWith({
    List<SupportQuickAction>? actions,
    List<SupportTicket>? tickets,
    DateTime? updatedAt,
  }) {
    return SupportCenterSnapshot(
      actions: actions == null ? this.actions : List.unmodifiable(actions),
      tickets: tickets == null ? this.tickets : List.unmodifiable(tickets),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class SupportQuickAction {
  const SupportQuickAction({
    required this.id,
    required this.kind,
    required this.availabilityLabel,
    required this.availabilityStatus,
    required this.target,
  });

  final String id;
  final SupportQuickActionKind kind;
  final String availabilityLabel;
  final SupportAvailabilityStatus availabilityStatus;
  final Uri target;
}

enum SupportQuickActionKind { faq, chat, call }

enum SupportAvailabilityStatus { online, limited, offline }

@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.reference,
    required this.status,
    required this.updatedAt,
    required this.channel,
  });

  final String id;
  final String subject;
  final String reference;
  final SupportTicketStatus status;
  final DateTime updatedAt;
  final SupportChannel channel;

  SupportTicket copyWith({
    String? id,
    String? subject,
    String? reference,
    SupportTicketStatus? status,
    DateTime? updatedAt,
    SupportChannel? channel,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      channel: channel ?? this.channel,
    );
  }
}

enum SupportTicketStatus { open, waitingCustomer, resolved }

enum SupportChannel { portal, chat, phone, email }
