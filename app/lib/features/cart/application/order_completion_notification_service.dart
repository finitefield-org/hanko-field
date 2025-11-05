import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/app_state/notification_badge.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/cart/domain/checkout_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final orderCompletionNotificationServiceProvider =
    Provider<OrderCompletionNotificationService>(
      OrderCompletionNotificationService.new,
      name: 'orderCompletionNotificationServiceProvider',
    );

class OrderCompletionNotificationService {
  OrderCompletionNotificationService(this._ref);

  final Ref _ref;

  OfflineCacheRepository get _cacheRepository =>
      _ref.read(offlineCacheRepositoryProvider);

  Future<bool> _hasNotificationOptIn() async {
    try {
      final dataSource = await _ref.read(
        onboardingLocalDataSourceProvider.future,
      );
      final flags = await dataSource.load();
      return flags.stepCompletion[OnboardingStep.notifications] ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> maybeSchedule(CheckoutOrderReceipt receipt) async {
    if (!await _hasNotificationOptIn()) {
      return;
    }
    final experience = await _ref.read(experienceGateProvider.future);
    final cacheSnapshot = await _cacheRepository.readNotifications();
    final existing = cacheSnapshot.value;
    final notificationId = 'order-${receipt.orderId.toLowerCase()}';
    final now = DateTime.now();

    final title = experience.isInternational
        ? 'Order ${receipt.orderId} confirmed'
        : '注文 ${receipt.orderId} を受け付けました';
    final body = experience.isInternational
        ? 'Track the production timeline from your orders tab.'
        : '注文履歴で制作の進捗を確認できます。';

    final newEntry = NotificationCacheItem(
      id: notificationId,
      title: title,
      body: body,
      timestamp: now,
      read: false,
      deepLink: '/orders/${receipt.orderId}',
    );

    final items = <NotificationCacheItem>[
      newEntry,
      if (existing != null)
        for (final item in existing.items)
          if (item.id != notificationId) item,
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final unreadCount =
        existing == null ||
            existing.items.where((item) => item.id == notificationId).isEmpty
        ? (existing?.unreadCount ?? 0) + 1
        : existing.unreadCount;

    final snapshot = CachedNotificationsSnapshot(
      items: items.take(40).toList(),
      unreadCount: unreadCount,
      lastSyncedAt: now,
    );
    await _cacheRepository.writeNotifications(snapshot);
    _ref.read(notificationBadgeProvider.notifier).updateCount(unreadCount);
  }
}
