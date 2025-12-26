// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/notifications/data/models/notification_models.dart';
import 'package:app/features/notifications/data/notification_repository.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/features/notifications/view_model/notifications_view_model.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class PushNotificationNavigationInitializer extends AsyncProvider<void> {
  PushNotificationNavigationInitializer()
    : super.args(null, autoDispose: false);

  @override
  Future<void> build(Ref ref) async {
    final messaging = ref.watch(firebaseMessagingProvider);
    final deepLinkHandler = ref.watch(deepLinkHandlerProvider);
    final repository = ref.watch(notificationRepositoryProvider);
    final analytics = ref.watch(analyticsClientProvider);
    final logger = Logger('PushNotificationNavigation');

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      await _handleMessage(
        ref,
        initial,
        deepLinkHandler: deepLinkHandler,
        repository: repository,
        analytics: analytics,
        logger: logger,
        openedByUser: true,
        source: 'initial',
      );
    }

    final openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleMessage(
        ref,
        message,
        deepLinkHandler: deepLinkHandler,
        repository: repository,
        analytics: analytics,
        logger: logger,
        openedByUser: true,
        source: 'background',
      ),
    );
    ref.onDispose(openedSub.cancel);

    final foregroundSub = FirebaseMessaging.onMessage.listen(
      (message) => _handleMessage(
        ref,
        message,
        deepLinkHandler: deepLinkHandler,
        repository: repository,
        analytics: analytics,
        logger: logger,
        openedByUser: false,
        source: 'foreground',
      ),
    );
    ref.onDispose(foregroundSub.cancel);
  }
}

final pushNotificationNavigationInitializerProvider =
    PushNotificationNavigationInitializer();

Future<void> _handleMessage(
  Ref ref,
  RemoteMessage message, {
  required DeepLinkHandler deepLinkHandler,
  required NotificationRepository repository,
  required AnalyticsClient analytics,
  required Logger logger,
  required bool openedByUser,
  required String source,
}) async {
  final data = Map<String, Object?>.from(message.data);
  final notification = _buildNotification(message, data);
  if (notification != null) {
    final count = await repository.upsertNotification(
      notification,
      markRead: openedByUser,
    );
    unawaited(ref.invoke(unreadNotificationsProvider.seed(count)));
    ref.invalidate(notificationsViewModel);
  }

  if (!openedByUser) return;

  final link = _extractLink(data);
  if (link == null) return;
  final uri = Uri.tryParse(link);
  if (uri == null) return;

  final shouldPush = data['push'] == 'true' || data['stack'] == 'push';
  final opened = await deepLinkHandler.open(uri, push: shouldPush);
  if (!opened) {
    logger.fine('Deep link failed for $uri; sending to /notifications');
    await deepLinkHandler.open(
      Uri.parse(AppRoutePaths.notifications),
      push: shouldPush,
    );
  }

  final notificationId = notification?.id ?? _notificationId(message, data);
  if (notificationId == null) return;
  unawaited(
    analytics.track(
      NotificationOpenedEvent(
        notificationId: notificationId,
        route: link,
        source: source,
      ),
    ),
  );
}

AppNotification? _buildNotification(
  RemoteMessage message,
  Map<String, Object?> data,
) {
  final id = _notificationId(message, data);
  if (id == null) return null;

  final title = _readString(data['title']) ?? message.notification?.title ?? '';
  final body = _readString(data['body']) ?? message.notification?.body ?? '';
  if (title.isEmpty && body.isEmpty) return null;

  final category = _notificationCategory(data['category'] ?? data['type']);
  final target = _extractLink(data) ?? AppRoutePaths.notifications;
  final ctaLabel = _readString(data['cta_label']) ?? _readString(data['cta']);

  return AppNotification(
    id: id,
    title: title.isEmpty ? 'Notification' : title,
    body: body,
    category: category,
    createdAt: message.sentTime ?? DateTime.now(),
    target: target,
    ctaLabel: ctaLabel,
  );
}

String? _notificationId(RemoteMessage message, Map<String, Object?> data) {
  final candidates = [
    data['notification_id'],
    data['id'],
    data['message_id'],
    message.messageId,
  ];
  for (final candidate in candidates) {
    final id = _readString(candidate);
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

String? _extractLink(Map<String, Object?> data) {
  for (final key in ['route', 'deep_link', 'deeplink', 'link', 'target']) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
  }

  final orderId = data['order_id'];
  if (orderId is String && orderId.isNotEmpty) {
    return '${AppRoutePaths.orders}/$orderId';
  }

  final designId = data['design_id'];
  if (designId is String && designId.isNotEmpty) {
    return '${AppRoutePaths.library}/$designId';
  }

  return AppRoutePaths.notifications;
}

NotificationCategory _notificationCategory(Object? value) {
  if (value is String && value.isNotEmpty) {
    try {
      return NotificationCategoryX.fromJson(value);
    } on ArgumentError {
      return NotificationCategory.system;
    }
  }
  return NotificationCategory.system;
}

String? _readString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}
