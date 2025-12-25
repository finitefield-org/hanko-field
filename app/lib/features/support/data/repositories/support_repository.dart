// ignore_for_file: public_member_api_docs

import 'package:app/features/support/data/models/support_ticket_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SupportTicketDraft {
  const SupportTicketDraft({
    required this.topic,
    required this.subject,
    required this.message,
    required this.orderId,
    required this.attachments,
  });

  final SupportTopic topic;
  final String subject;
  final String message;
  final String orderId;
  final List<SupportAttachment> attachments;
}

abstract class SupportRepository {
  static const fallback = Scope<SupportRepository>.required(
    'support.repository',
  );

  Future<SupportTicketSubmission> createTicket(SupportTicketDraft draft);
}
