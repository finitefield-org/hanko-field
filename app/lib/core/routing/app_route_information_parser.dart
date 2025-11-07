import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:flutter/material.dart';

/// RouteInformationParser to handle deep links.
class AppRouteInformationParser extends RouteInformationParser<AppRoute> {
  const AppRouteInformationParser();

  @override
  Future<AppRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    if (uri.pathSegments.isEmpty) {
      return const TabRoute(currentTab: kDefaultAppTab);
    }
    if (uri.pathSegments.first == 'auth') {
      final next = uri.queryParameters['next'];
      return TabRoute(
        currentTab: kDefaultAppTab,
        stack: [
          AuthFlowRoute(
            nextPath: (next != null && next.isNotEmpty) ? next : null,
          ),
        ],
      );
    }
    if (uri.pathSegments.first == 'cart') {
      return const TabRoute(currentTab: AppTab.shop, stack: [CartRoute()]);
    }
    if (uri.pathSegments.first == 'checkout') {
      final segments = uri.pathSegments.skip(1).toList();
      final route = CheckoutRoute(segments);
      return TabRoute(currentTab: AppTab.shop, stack: [route]);
    }
    if (uri.pathSegments.first == 'kanji' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[1] == 'dictionary') {
      return const TabRoute(
        currentTab: AppTab.creation,
        stack: [KanjiDictionaryRoute()],
      );
    }
    final firstSegment = uri.pathSegments.first;
    final remaining = uri.pathSegments.skip(1).toList();
    final routeSegments = _extractRouteSegments(remaining);
    final tab = _tabFromSegment(firstSegment);
    switch (tab) {
      case AppTab.creation:
        return TabRoute(
          currentTab: AppTab.creation,
          stack: _buildCreationStack(routeSegments),
        );
      case AppTab.shop:
        return TabRoute(
          currentTab: AppTab.shop,
          stack: _buildShopStack(routeSegments),
        );
      case AppTab.orders:
        return TabRoute(
          currentTab: AppTab.orders,
          stack: _buildOrderStack(routeSegments),
        );
      case AppTab.library:
        return TabRoute(
          currentTab: AppTab.library,
          stack: _buildLibraryStack(routeSegments),
        );
      case AppTab.profile:
        return TabRoute(
          currentTab: AppTab.profile,
          stack: _buildProfileStack(routeSegments),
        );
    }
  }

  @override
  RouteInformation restoreRouteInformation(AppRoute configuration) {
    return RouteInformation(uri: Uri.parse(configuration.location));
  }

  AppTab _tabFromSegment(String segment) {
    for (final tab in AppTab.values) {
      if (tab.pathSegment == segment) {
        return tab;
      }
    }
    return kDefaultAppTab;
  }

  List<IndependentRoute> _buildCreationStack(List<List<String>> routes) {
    if (routes.isEmpty) {
      return const [];
    }
    return [
      for (final segments in routes)
        if (segments.isNotEmpty)
          _specialRouteFromSegments(segments) ?? CreationStageRoute(segments),
    ];
  }

  List<IndependentRoute> _buildShopStack(List<List<String>> routes) {
    if (routes.isEmpty) {
      return const [];
    }
    final result = <IndependentRoute>[];
    for (final segments in routes) {
      final special = _specialRouteFromSegments(segments);
      if (special != null) {
        result.add(special);
        continue;
      }
      if (segments.length < 2) {
        continue;
      }
      result.add(
        ShopDetailRoute(
          entity: segments[0],
          identifier: segments[1],
          trailingSegments: segments.length > 2
              ? segments.sublist(2)
              : const <String>[],
        ),
      );
    }
    return result;
  }

  List<IndependentRoute> _buildOrderStack(List<List<String>> routes) {
    if (routes.isEmpty) {
      return const [];
    }
    final result = <IndependentRoute>[];
    for (final segments in routes) {
      final special = _specialRouteFromSegments(segments);
      if (special != null) {
        result.add(special);
        continue;
      }
      if (segments.isEmpty) {
        continue;
      }
      final orderId = segments.first;
      if (segments.length >= 2 && segments[1] == 'tracking') {
        result.add(OrderTrackingRoute(orderId: orderId));
        continue;
      }
      if (segments.length >= 2 && segments[1] == 'invoice') {
        result.add(OrderInvoiceRoute(orderId: orderId));
        continue;
      }
      if (segments.length >= 2 && segments[1] == 'reorder') {
        result.add(OrderReorderRoute(orderId: orderId));
        continue;
      }
      result.add(
        OrderDetailsRoute(
          orderId: orderId,
          trailing: segments.length > 1
              ? segments.sublist(1)
              : const <String>[],
        ),
      );
    }
    return result;
  }

  List<IndependentRoute> _buildLibraryStack(List<List<String>> routes) {
    if (routes.isEmpty) {
      return const [];
    }
    final result = <IndependentRoute>[];
    for (final segments in routes) {
      final special = _specialRouteFromSegments(segments);
      if (special != null) {
        result.add(special);
        continue;
      }
      if (segments.isEmpty) {
        continue;
      }
      result.add(
        LibraryEntryRoute(
          designId: segments.first,
          trailing: segments.length > 1
              ? segments.sublist(1)
              : const <String>[],
        ),
      );
    }
    return result;
  }

  List<IndependentRoute> _buildProfileStack(List<List<String>> routes) {
    if (routes.isEmpty) {
      return const [];
    }
    return [
      for (final segments in routes)
        if (segments.isNotEmpty)
          _specialRouteFromSegments(segments) ?? ProfileSectionRoute(segments),
    ];
  }

  List<List<String>> _extractRouteSegments(List<String> segments) {
    if (segments.isEmpty) {
      return const [];
    }
    if (!segments.contains(kStackBoundarySegment)) {
      return [List.unmodifiable(segments)];
    }
    final result = <List<String>>[];
    var current = <String>[];
    for (final segment in segments) {
      if (segment == kStackBoundarySegment) {
        if (current.isNotEmpty) {
          result.add(List.unmodifiable(current));
          current = <String>[];
        }
        continue;
      }
      current.add(segment);
    }
    if (current.isNotEmpty) {
      result.add(List.unmodifiable(current));
    }
    return result;
  }

  IndependentRoute? _specialRouteFromSegments(List<String> segments) {
    if (segments.isEmpty) {
      return null;
    }
    final key = segments.first;
    switch (key) {
      case 'notifications':
        return const NotificationsRoute();
      case 'search':
        return const GlobalSearchRoute();
      case 'auth':
        if (segments.length >= 3 && segments[1] == 'redirect') {
          final decoded = Uri.decodeComponent(segments[2]);
          return AuthFlowRoute(nextPath: decoded);
        }
        return const AuthFlowRoute();
      case 'guides':
        return GuidesRoute(
          sectionSegments: segments.length > 1
              ? segments.sublist(1)
              : const <String>[],
        );
      case 'kanji':
        if (segments.length >= 2 && segments[1] == 'dictionary') {
          return const KanjiDictionaryRoute();
        }
        break;
      case 'cart':
        return const CartRoute();
      case 'checkout':
        return CheckoutRoute(
          segments.length > 1 ? segments.sublist(1) : const ['address'],
        );
    }
    return null;
  }
}
