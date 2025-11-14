import 'dart:async';

import 'package:app/features/profile/data/support_center_repository.dart';
import 'package:app/features/profile/data/support_center_repository_provider.dart';
import 'package:app/features/profile/domain/support_center.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfileSupportState {
  ProfileSupportState({
    required List<SupportQuickAction> quickActions,
    required List<SupportTicket> tickets,
    required this.lastUpdated,
    this.isRefreshing = false,
    this.isCreatingTicket = false,
  }) : quickActions = List.unmodifiable(quickActions),
       tickets = List.unmodifiable(tickets);

  final List<SupportQuickAction> quickActions;
  final List<SupportTicket> tickets;
  final DateTime? lastUpdated;
  final bool isRefreshing;
  final bool isCreatingTicket;

  bool get hasTickets => tickets.isNotEmpty;

  ProfileSupportState copyWith({
    List<SupportQuickAction>? quickActions,
    List<SupportTicket>? tickets,
    DateTime? lastUpdated,
    bool? isRefreshing,
    bool? isCreatingTicket,
  }) {
    return ProfileSupportState(
      quickActions: quickActions == null
          ? this.quickActions
          : List.unmodifiable(quickActions),
      tickets: tickets == null ? this.tickets : List.unmodifiable(tickets),
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCreatingTicket: isCreatingTicket ?? this.isCreatingTicket,
    );
  }
}

class ProfileSupportController extends AsyncNotifier<ProfileSupportState> {
  SupportCenterRepository get _repository =>
      ref.read(supportCenterRepositoryProvider);

  @override
  FutureOr<ProfileSupportState> build() async {
    final snapshot = await _repository.fetch();
    return _stateFromSnapshot(snapshot);
  }

  Future<void> reload() async {
    final current = state.asData?.value;
    if (current == null) {
      state = const AsyncLoading();
    } else {
      state = AsyncData(current.copyWith(isRefreshing: true));
    }
    try {
      final snapshot = await _repository.fetch();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(_stateFromSnapshot(snapshot));
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> createTicket(String subject) async {
    final previous = state.asData?.value ?? await future;
    if (previous.isCreatingTicket) {
      return;
    }
    final placeholder = SupportTicket(
      id: 'temp-${DateTime.now().microsecondsSinceEpoch}',
      subject: subject,
      reference: 'pending',
      status: SupportTicketStatus.open,
      updatedAt: DateTime.now(),
      channel: SupportChannel.portal,
    );
    final optimistic = previous.copyWith(
      tickets: [placeholder, ...previous.tickets],
      isCreatingTicket: true,
    );
    state = AsyncData(optimistic);
    try {
      final saved = await _repository.createTicket(subject: subject);
      if (!ref.mounted) {
        return;
      }
      final latest = state.asData?.value ?? optimistic;
      final sanitized = [
        saved,
        ...latest.tickets.where((ticket) => ticket.id != placeholder.id),
      ];
      state = AsyncData(
        latest.copyWith(
          tickets: sanitized,
          isCreatingTicket: false,
          lastUpdated: saved.updatedAt,
        ),
      );
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(previous.copyWith(isCreatingTicket: false));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  ProfileSupportState _stateFromSnapshot(SupportCenterSnapshot snapshot) {
    return ProfileSupportState(
      quickActions: snapshot.actions,
      tickets: snapshot.tickets,
      lastUpdated: snapshot.updatedAt,
    );
  }
}

final profileSupportControllerProvider =
    AsyncNotifierProvider<ProfileSupportController, ProfileSupportState>(
      ProfileSupportController.new,
    );
