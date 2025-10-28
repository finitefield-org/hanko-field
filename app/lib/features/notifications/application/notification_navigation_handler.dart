import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_route_information_parser.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/features/notifications/data/notification_repository_provider.dart';
import 'package:app/features/notifications/domain/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationNavigationHandlerProvider =
    Provider<NotificationNavigationHandler>(NotificationNavigationHandler.new);

class NotificationNavigationHandler {
  NotificationNavigationHandler(this._ref);

  final Ref _ref;
  final AppRouteInformationParser _parser = const AppRouteInformationParser();

  Future<bool> open(AppNotification notification) async {
    final destination = await _buildRouteFromNotification(notification);
    if (destination == null) {
      return false;
    }
    final notifier = _ref.read(appStateProvider.notifier);
    if (destination case AppRoute(:final tab)) {
      notifier.setRouteAndTab(destination, tab);
      return true;
    }
    if (destination is IndependentRoute) {
      notifier.push(destination);
      return true;
    }
    return false;
  }

  Future<bool> openFromPayload({
    String? notificationId,
    String? deepLink,
  }) async {
    final repository = _ref.read(notificationRepositoryProvider);
    AppNotification? notification;
    if (notificationId != null) {
      notification = await repository.findById(notificationId);
    }
    final route = await _resolveRoute(
      notification: notification,
      deepLink: deepLink,
    );
    if (route == null) {
      return false;
    }
    final notifier = _ref.read(appStateProvider.notifier);
    if (route case AppRoute(:final tab)) {
      notifier.setRouteAndTab(route, tab);
      return true;
    }
    if (route is IndependentRoute) {
      notifier.push(route);
      return true;
    }
    return false;
  }

  Future<Object?> _buildRouteFromNotification(
    AppNotification notification,
  ) async {
    return _resolveRoute(
      notification: notification,
      deepLink: notification.deepLink,
    );
  }

  Future<Object?> _resolveRoute({
    AppNotification? notification,
    String? deepLink,
  }) async {
    final link = deepLink ?? notification?.deepLink;
    if (link == null || link.isEmpty) {
      final action = notification?.action;
      return action?.destination;
    }
    final route = await _fromDeepLink(link);
    if (route != null) {
      return route;
    }
    final action = notification?.action;
    return action?.destination;
  }

  Future<AppRoute?> _fromDeepLink(String link) async {
    final normalized = link.startsWith('/') || link.startsWith('http')
        ? link
        : '/$link';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return null;
    }
    final routeInfo = RouteInformation(uri: uri);
    final route = await _parser.parseRouteInformation(routeInfo);
    if (route.stack.isEmpty) {
      return null;
    }
    return route;
  }
}
