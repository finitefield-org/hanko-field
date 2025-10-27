import 'dart:async';

import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the unread notification count for the global app bar badge.
final notificationBadgeProvider =
    AsyncNotifierProvider<NotificationBadgeNotifier, int>(
      NotificationBadgeNotifier.new,
    );

class NotificationBadgeNotifier extends AsyncNotifier<int> {
  OfflineCacheRepository get _cache => ref.read(offlineCacheRepositoryProvider);

  @override
  FutureOr<int> build() async {
    return _loadUnreadCount();
  }

  /// Reloads the cached unread count (SWr policy handled by the repository).
  Future<void> refresh() async {
    state = await AsyncValue.guard(_loadUnreadCount);
  }

  /// Allows imperative updates when inbox screen marks notifications as read.
  void updateCount(int unreadCount) {
    state = AsyncValue.data(unreadCount);
  }

  Future<int> _loadUnreadCount() async {
    final snapshot = await _cache.readNotifications();
    return snapshot.value?.unreadCount ?? 0;
  }
}
