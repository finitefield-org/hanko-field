// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/notifications/data/notification_repository.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
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
    final logger = Logger('PushNotificationNavigation');

    Future<void> handle(RemoteMessage? message) async {
      if (message == null) return;
      final data = Map<String, Object?>.from(message.data);
      final link = _extractLink(data);
      final notificationId = data['notification_id'] ?? data['id'];

      if (notificationId is String && notificationId.isNotEmpty) {
        final count = await repository.setReadState(notificationId, read: true);
        unawaited(ref.invoke(unreadNotificationsProvider.seed(count)));
      }

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
    }

    final initial = await messaging.getInitialMessage();
    await handle(initial);

    final sub = FirebaseMessaging.onMessageOpenedApp.listen(handle);
    ref.onDispose(sub.cancel);
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
}

final pushNotificationNavigationInitializerProvider =
    PushNotificationNavigationInitializer();
