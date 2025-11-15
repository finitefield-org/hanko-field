import 'dart:async';

import 'package:app/features/profile/domain/support_center.dart';

abstract class SupportCenterRepository {
  Future<SupportCenterSnapshot> fetch();
  Future<SupportTicket> createTicket({
    required String subject,
    SupportChannel channel = SupportChannel.portal,
  });
}

class FakeSupportCenterRepository implements SupportCenterRepository {
  FakeSupportCenterRepository({
    Duration latency = const Duration(milliseconds: 280),
  }) : _latency = latency,
       _snapshot = SupportCenterSnapshot(
         actions: _defaultActions,
         tickets: _seedTickets,
         updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
       );

  final Duration _latency;
  SupportCenterSnapshot _snapshot;

  static List<SupportQuickAction> get _defaultActions => [
    SupportQuickAction(
      id: 'faq',
      kind: SupportQuickActionKind.faq,
      availabilityLabel: '24/7',
      availabilityStatus: SupportAvailabilityStatus.online,
      target: Uri.parse('app://support/faq'),
    ),
    SupportQuickAction(
      id: 'chat',
      kind: SupportQuickActionKind.chat,
      availabilityLabel: 'Live now',
      availabilityStatus: SupportAvailabilityStatus.online,
      target: Uri.parse('https://support.hanko-field.com/chat'),
    ),
    SupportQuickAction(
      id: 'call',
      kind: SupportQuickActionKind.call,
      availabilityLabel: 'Weekdays 10-18',
      availabilityStatus: SupportAvailabilityStatus.limited,
      target: Uri.parse('tel:+81312345678'),
    ),
  ];

  static List<SupportTicket> get _seedTickets {
    final now = DateTime.now();
    return [
      SupportTicket(
        id: 'ticket-1',
        subject: 'Update proof for Kaneko order',
        reference: '#HF-34211',
        status: SupportTicketStatus.open,
        updatedAt: now.subtract(const Duration(hours: 2)),
        channel: SupportChannel.chat,
      ),
      SupportTicket(
        id: 'ticket-2',
        subject: 'Change shipping address for batch B',
        reference: '#HF-33198',
        status: SupportTicketStatus.waitingCustomer,
        updatedAt: now.subtract(const Duration(days: 1, hours: 3)),
        channel: SupportChannel.portal,
      ),
      SupportTicket(
        id: 'ticket-3',
        subject: 'Payment receipt request',
        reference: '#HF-32870',
        status: SupportTicketStatus.resolved,
        updatedAt: now.subtract(const Duration(days: 4)),
        channel: SupportChannel.email,
      ),
    ];
  }

  @override
  Future<SupportCenterSnapshot> fetch() async {
    await Future.delayed(_latency);
    return _snapshot;
  }

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    SupportChannel channel = SupportChannel.portal,
  }) async {
    final now = DateTime.now();
    final reference =
        '#HF-${now.millisecondsSinceEpoch.toString().substring(6)}';
    final ticket = SupportTicket(
      id: 'ticket-${now.microsecondsSinceEpoch}',
      subject: subject,
      reference: reference,
      status: SupportTicketStatus.open,
      updatedAt: now,
      channel: channel,
    );
    await Future.delayed(_latency * 2);
    _snapshot = _snapshot.copyWith(
      tickets: [ticket, ..._snapshot.tickets],
      updatedAt: now,
    );
    return ticket;
  }
}
