import 'package:app/core/routing/app_route_configuration.dart';
import 'package:flutter/foundation.dart';

/// Logical categories for inbox entries. Used to map colors, icons, and chips.
enum NotificationCategory { order, production, promotion, guide, system }

enum NotificationFilter { all, unread }

extension NotificationFilterX on NotificationFilter {
  bool get unreadOnly => this == NotificationFilter.unread;
}

@immutable
class NotificationAction {
  const NotificationAction({required this.label, required this.destination});

  /// Button label displayed in the trailing assist chip.
  final String label;

  /// Route to push when the user taps the entry or CTA.
  final IndependentRoute destination;
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.read = false,
    this.action,
    this.deepLink,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime timestamp;
  final bool read;
  final NotificationAction? action;
  final String? deepLink;

  AppNotification copyWith({bool? read, NotificationAction? action}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      timestamp: timestamp,
      read: read ?? this.read,
      action: action ?? this.action,
      deepLink: deepLink,
    );
  }
}

@immutable
class NotificationsPage {
  const NotificationsPage({
    required this.items,
    required this.unreadCount,
    this.nextCursor,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
