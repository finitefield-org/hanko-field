import 'dart:async';

import 'package:app/core/app_state/notification_badge.dart';
import 'package:app/features/notifications/data/notification_repository.dart';
import 'package:app/features/notifications/data/notification_repository_provider.dart';
import 'package:app/features/notifications/domain/app_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final notificationFilterProvider = StateProvider<NotificationFilter>(
  (ref) => NotificationFilter.all,
);

final notificationsListControllerProvider =
    AsyncNotifierProvider<NotificationsListController, NotificationsListState>(
      NotificationsListController.new,
    );

class NotificationsListState {
  const NotificationsListState({
    required this.items,
    required this.filter,
    required this.unreadCount,
    this.nextCursor,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    Set<String>? pendingUpdates,
  }) : pendingUpdates = pendingUpdates ?? const <String>{};

  final List<AppNotification> items;
  final NotificationFilter filter;
  final int unreadCount;
  final String? nextCursor;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Set<String> pendingUpdates;

  bool get hasMore => nextCursor != null;

  NotificationsListState copyWith({
    List<AppNotification>? items,
    NotificationFilter? filter,
    int? unreadCount,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isRefreshing,
    Set<String>? pendingUpdates,
  }) {
    return NotificationsListState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      unreadCount: unreadCount ?? this.unreadCount,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      pendingUpdates: pendingUpdates ?? this.pendingUpdates,
    );
  }
}

class NotificationsListController
    extends AsyncNotifier<NotificationsListState> {
  NotificationsListState? get _current => state.asData?.value;

  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  NotificationBadgeNotifier get _badge =>
      ref.read(notificationBadgeProvider.notifier);

  @override
  FutureOr<NotificationsListState> build() {
    final filter = ref.watch(notificationFilterProvider);
    return _loadInitial(filter);
  }

  Future<NotificationsListState> _loadInitial(NotificationFilter filter) async {
    final page = await _repository.fetch(unreadOnly: filter.unreadOnly);
    return NotificationsListState(
      items: List.unmodifiable(page.items),
      filter: filter,
      unreadCount: page.unreadCount,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> refresh() async {
    final currentFilter = ref.read(notificationFilterProvider);
    final currentState = _current;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(isRefreshing: true));
    }

    try {
      final page = await _repository.fetch(
        unreadOnly: currentFilter.unreadOnly,
      );
      final nextState = NotificationsListState(
        items: List.unmodifiable(page.items),
        filter: currentFilter,
        unreadCount: page.unreadCount,
        nextCursor: page.nextCursor,
      );
      state = AsyncValue.data(nextState);
      _badge.updateCount(page.unreadCount);
    } catch (error, stackTrace) {
      if (currentState != null) {
        state = AsyncValue.data(currentState.copyWith(isRefreshing: false));
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> changeFilter(NotificationFilter next) async {
    final controller = ref.read(notificationFilterProvider.notifier);
    if (controller.state == next) {
      return;
    }
    controller.state = next;
    state = const AsyncValue.loading();
  }

  Future<void> loadMore() async {
    final current = _current;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        state.isLoading) {
      return;
    }
    final pending = current.copyWith(isLoadingMore: true);
    state = AsyncValue.data(pending);
    try {
      final page = await _repository.fetch(
        cursor: current.nextCursor,
        unreadOnly: current.filter.unreadOnly,
      );
      final existingIds = {for (final item in current.items) item.id};
      final merged = [
        ...current.items,
        for (final item in page.items)
          if (!existingIds.contains(item.id)) item,
      ];
      final updated = pending.copyWith(
        items: List.unmodifiable(merged),
        nextCursor: page.nextCursor,
        unreadCount: page.unreadCount,
        isLoadingMore: false,
      );
      state = AsyncValue.data(updated);
      _badge.updateCount(page.unreadCount);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  AppNotification? _findNotification(List<AppNotification> items, String id) {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<AppNotification?> setReadState({
    required String id,
    required bool read,
  }) async {
    final current = _current;
    if (current == null || current.pendingUpdates.contains(id)) {
      return current != null ? _findNotification(current.items, id) : null;
    }
    final existing = _findNotification(current.items, id);
    if (existing != null && existing.read == read) {
      return existing;
    }
    final inFlight = {...current.pendingUpdates, id};
    state = AsyncValue.data(current.copyWith(pendingUpdates: inFlight));
    try {
      final updated = await _repository.updateReadState(id: id, read: read);
      final baseItems = current.items;
      List<AppNotification> nextItems;
      if (current.filter.unreadOnly) {
        if (updated.read) {
          nextItems = [
            for (final item in baseItems)
              if (item.id != id) item,
          ];
        } else {
          final temp = [
            for (final item in baseItems)
              if (item.id != id) item,
          ];
          temp.add(updated);
          temp.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          nextItems = temp;
        }
      } else {
        nextItems = [
          for (final item in baseItems)
            if (item.id == id) updated else item,
        ];
      }
      final unreadCount = nextItems.where((item) => !item.read).length;
      final pending = {...inFlight}..remove(id);
      final nextState = current.copyWith(
        items: List.unmodifiable(nextItems),
        unreadCount: unreadCount,
        pendingUpdates: pending,
      );
      state = AsyncValue.data(nextState);
      _badge.updateCount(unreadCount);
      return updated;
    } catch (error, stackTrace) {
      final pending = {...inFlight}..remove(id);
      state = AsyncValue.data(current.copyWith(pendingUpdates: pending));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> markAllAsRead() async {
    final current = _current;
    if (current == null || current.unreadCount == 0) {
      return;
    }
    state = AsyncValue.data(current.copyWith(isRefreshing: true));
    try {
      await _repository.markAllAsRead();
      final cleared = [
        for (final item in current.items) item.copyWith(read: true),
      ];
      final items = current.filter.unreadOnly
          ? const <AppNotification>[]
          : cleared;
      final next = current.copyWith(
        items: List.unmodifiable(items),
        unreadCount: 0,
        isRefreshing: false,
      );
      state = AsyncValue.data(next);
      _badge.updateCount(0);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current.copyWith(isRefreshing: false));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
