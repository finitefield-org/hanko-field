// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'package:app/features/notifications/data/models/notification_models.dart';
import 'package:app/features/notifications/data/notification_repository.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum NotificationFilter { all, unread }

extension NotificationFilterX on NotificationFilter {
  bool get unreadOnly => this == NotificationFilter.unread;
}

class NotificationsState {
  const NotificationsState({
    required this.items,
    required this.filter,
    required this.nextPageToken,
    required this.isLoadingMore,
    required this.isRefreshing,
  });

  final List<AppNotification> items;
  final NotificationFilter filter;
  final String? nextPageToken;
  final bool isLoadingMore;
  final bool isRefreshing;

  NotificationsState copyWith({
    List<AppNotification>? items,
    NotificationFilter? filter,
    String? nextPageToken,
    bool? isLoadingMore,
    bool? isRefreshing,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class NotificationsViewModel extends AsyncProvider<NotificationsState> {
  NotificationsViewModel() : super.args(null, autoDispose: true);

  late final loadMoreMut = mutation<void>(#loadMore);
  late final setFilterMut = mutation<NotificationFilter>(#setFilter);
  late final refreshMut = mutation<void>(#refresh);
  late final setReadStateMut = mutation<void>(#setReadState);
  late final markAllMut = mutation<void>(#markAllRead);

  @override
  Future<NotificationsState> build(Ref ref) async {
    final repository = ref.watch(notificationRepositoryProvider);
    final page = await repository.listNotifications();
    final count = await repository.unreadCount();
    unawaited(ref.invoke(unreadNotificationsProvider.seed(count)));

    return NotificationsState(
      items: page.items,
      filter: NotificationFilter.all,
      nextPageToken: page.nextPageToken,
      isLoadingMore: false,
      isRefreshing: false,
    );
  }

  Call<void> loadMore() => mutate(loadMoreMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    if (current.isLoadingMore) return;
    final next = current.nextPageToken;
    if (next == null) return;

    ref.state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final repository = ref.watch(notificationRepositoryProvider);
      final page = await repository.listNotifications(
        unreadOnly: current.filter.unreadOnly,
        pageToken: next,
      );

      ref.state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextPageToken: page.nextPageToken,
          isLoadingMore: false,
        ),
      );
    } catch (e, stack) {
      ref.state = AsyncError(
        e,
        stack,
        previous: AsyncData(current.copyWith(isLoadingMore: false)),
      );
    }
  }, concurrency: Concurrency.dropLatest);

  Call<NotificationFilter> setFilter(NotificationFilter filter) =>
      mutate(setFilterMut, (ref) async {
        final repository = ref.watch(notificationRepositoryProvider);
        final current = ref.watch(this).valueOrNull;

        if (current != null) {
          ref.state = AsyncData(
            current.copyWith(
              filter: filter,
              isRefreshing: true,
              nextPageToken: null,
            ),
          );
        } else {
          ref.state = const AsyncLoading<NotificationsState>();
        }

        try {
          final page = await repository.listNotifications(
            unreadOnly: filter.unreadOnly,
          );
          final count = await repository.unreadCount();
          unawaited(ref.invoke(unreadNotificationsProvider.seed(count)));

          ref.state = AsyncData(
            NotificationsState(
              items: page.items,
              filter: filter,
              nextPageToken: page.nextPageToken,
              isLoadingMore: false,
              isRefreshing: false,
            ),
          );
          return filter;
        } catch (e, stack) {
          ref.state = AsyncError(
            e,
            stack,
            previous: current != null ? AsyncData(current) : null,
          );
          rethrow;
        }
      }, concurrency: Concurrency.restart);

  Call<void> refresh() => mutate(refreshMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    final filter = current?.filter ?? NotificationFilter.all;
    final repository = ref.watch(notificationRepositoryProvider);

    if (current != null) {
      ref.state = AsyncData(current.copyWith(isRefreshing: true));
    } else {
      ref.state = const AsyncLoading<NotificationsState>();
    }

    try {
      final page = await repository.listNotifications(
        unreadOnly: filter.unreadOnly,
      );
      final count = await repository.unreadCount();
      unawaited(ref.invoke(unreadNotificationsProvider.seed(count)));

      ref.state = AsyncData(
        NotificationsState(
          items: page.items,
          filter: filter,
          nextPageToken: page.nextPageToken,
          isLoadingMore: false,
          isRefreshing: false,
        ),
      );
    } catch (e, stack) {
      ref.state = AsyncError(
        e,
        stack,
        previous: current != null
            ? AsyncData(current.copyWith(isRefreshing: false))
            : null,
      );
    }
  }, concurrency: Concurrency.restart);

  Call<void> setReadState(String id, bool read) =>
      mutate(setReadStateMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return;

        final repository = ref.watch(notificationRepositoryProvider);
        final count = await repository.setReadState(id, read: read);
        unawaited(ref.invoke(unreadNotificationsProvider.seed(count)));

        final updated = current.items
            .map((n) => n.id == id ? n.copyWith(read: read) : n)
            .toList();

        final nextToken = current.filter.unreadOnly && read
            ? _decrementToken(current.nextPageToken, by: 1)
            : current.nextPageToken;

        ref.state = AsyncData(
          current.copyWith(items: updated, nextPageToken: nextToken),
        );
      }, concurrency: Concurrency.dropLatest);

  Call<void> markAllRead() => mutate(markAllMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;

    final repository = ref.watch(notificationRepositoryProvider);
    await repository.markAllRead();
    unawaited(ref.invoke(unreadNotificationsProvider.seed(0)));

    final cleared = current.items.map((n) => n.copyWith(read: true)).toList();
    final removedCount = current.filter.unreadOnly
        ? current.items.where((n) => !n.read).length
        : 0;
    final nextToken = _decrementToken(current.nextPageToken, by: removedCount);

    ref.state = AsyncData(
      current.copyWith(
        items: current.filter.unreadOnly ? <AppNotification>[] : cleared,
        nextPageToken: nextToken,
      ),
    );
  }, concurrency: Concurrency.dropLatest);
}

final notificationsViewModel = NotificationsViewModel();

String? _decrementToken(String? token, {required int by}) {
  if (token == null || by <= 0) return token;
  final value = int.tryParse(token);
  if (value == null) return token;
  final next = value - by;
  if (next < 0) return '0';
  return '$next';
}
