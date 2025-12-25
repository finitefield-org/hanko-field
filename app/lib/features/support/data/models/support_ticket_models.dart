// ignore_for_file: public_member_api_docs

class SupportAttachment {
  const SupportAttachment({
    required this.id,
    required this.name,
    required this.bytes,
    required this.sizeBytes,
    required this.mimeType,
  });

  final String id;
  final String name;
  final List<int> bytes;
  final int sizeBytes;
  final String mimeType;
}

enum SupportTopic { order, shipping, payment, account, app, other }

extension SupportTopicX on SupportTopic {
  String toJson() => switch (this) {
    SupportTopic.order => 'order',
    SupportTopic.shipping => 'shipping',
    SupportTopic.payment => 'payment',
    SupportTopic.account => 'account',
    SupportTopic.app => 'app',
    SupportTopic.other => 'other',
  };
}

class SupportTicketSubmission {
  const SupportTicketSubmission({
    required this.ticketId,
    required this.createdAt,
  });

  final String ticketId;
  final DateTime createdAt;
}
