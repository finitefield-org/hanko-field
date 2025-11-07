import 'dart:collection';

import 'package:app/core/routing/app_tab.dart';
import 'package:app/features/auth/presentation/auth_screen.dart';
import 'package:app/features/cart/presentation/cart_screen.dart';
import 'package:app/features/cart/presentation/checkout_address_screen.dart';
import 'package:app/features/cart/presentation/checkout_complete_screen.dart';
import 'package:app/features/cart/presentation/checkout_payment_screen.dart';
import 'package:app/features/cart/presentation/checkout_review_screen.dart';
import 'package:app/features/cart/presentation/checkout_shipping_screen.dart';
import 'package:app/features/design_creation/presentation/design_ai_suggestions_page.dart';
import 'package:app/features/design_creation/presentation/design_editor_page.dart';
import 'package:app/features/design_creation/presentation/design_export_page.dart';
import 'package:app/features/design_creation/presentation/design_kanji_mapping_page.dart';
import 'package:app/features/design_creation/presentation/design_name_input_page.dart';
import 'package:app/features/design_creation/presentation/design_preview_page.dart';
import 'package:app/features/design_creation/presentation/design_registrability_check_page.dart';
import 'package:app/features/design_creation/presentation/design_share_page.dart';
import 'package:app/features/design_creation/presentation/design_style_selection_page.dart';
import 'package:app/features/design_creation/presentation/design_type_selection_page.dart';
import 'package:app/features/design_creation/presentation/design_version_history_page.dart';
import 'package:app/features/library/presentation/library_entry_screen.dart';
import 'package:app/features/library/presentation/library_versions_page.dart';
import 'package:app/features/navigation/presentation/deep_link_pages.dart';
import 'package:app/features/notifications/presentation/notification_inbox_page.dart';
import 'package:app/features/orders/presentation/order_details_screen.dart';
import 'package:app/features/orders/presentation/order_invoice_screen.dart';
import 'package:app/features/orders/presentation/order_reorder_screen.dart';
import 'package:app/features/orders/presentation/order_tracking_screen.dart';
import 'package:app/features/search/presentation/global_search_page.dart';
import 'package:flutter/material.dart';

/// スタックの境界を表すパスセグメント
const String kStackBoundarySegment = '__stack__';

/// タブ横断で積み上げるルート
sealed class IndependentRoute {
  List<String> get pathSegments;
  Widget get page;
  Object stackKey(AppTab tab, int index);
}

mixin StandaloneLocationRoute on IndependentRoute {
  String get standaloneLocation;
}

/// ルーターが復元するルート情報
sealed class AppRoute {
  AppRoute? get parent;
  Object get key;
  AppTab get tab;
  List<IndependentRoute> get stack;
  String get location;
}

/// 指定タブのルート/スタック
class TabRoute implements AppRoute {
  const TabRoute({
    required this.currentTab,
    List<IndependentRoute> stack = const [],
  }) : _stack = stack;

  final AppTab currentTab;
  final List<IndependentRoute> _stack;

  @override
  AppRoute? get parent => null;

  @override
  Object get key =>
      'TabRoute(${currentTab.name}-${_stack.map((route) => route.hashCode).join('-')})';

  @override
  AppTab get tab => currentTab;

  @override
  List<IndependentRoute> get stack => UnmodifiableListView(_stack);

  @override
  String get location {
    if (_stack.length == 1 && _stack.first is StandaloneLocationRoute) {
      final standalone = _stack.first as StandaloneLocationRoute;
      return '/${standalone.standaloneLocation}';
    }
    final segments = <String>[currentTab.pathSegment];
    for (final route in _stack) {
      final routeSegments = route.pathSegments;
      if (routeSegments.isEmpty) {
        continue;
      }
      segments.add(kStackBoundarySegment);
      segments.addAll(routeSegments);
    }
    return '/${segments.join('/')}';
  }

  TabRoute copyWith({List<IndependentRoute>? stack}) {
    return TabRoute(currentTab: currentTab, stack: stack ?? _stack);
  }

  @override
  String toString() {
    return 'TabRoute(tab: ${currentTab.name}, stack: $_stack)';
  }
}

/// 作成フロー内のステージ
class CreationStageRoute implements IndependentRoute {
  CreationStageRoute(List<String> segments)
    : stageSegments = List.unmodifiable(segments);

  final List<String> stageSegments;

  @override
  Widget get page {
    if (stageSegments.isEmpty || stageSegments.first == 'new') {
      return const DesignTypeSelectionPage();
    }
    if (stageSegments.first == 'input' && stageSegments.length == 1) {
      return const DesignNameInputPage();
    }
    if (stageSegments.length >= 2 &&
        stageSegments.first == 'input' &&
        stageSegments[1] == 'kanji-map') {
      return const DesignKanjiMappingPage();
    }
    if (stageSegments.first == 'style') {
      return const DesignStyleSelectionPage();
    }
    if (stageSegments.first == 'ai') {
      return const DesignAiSuggestionsPage();
    }
    if (stageSegments.first == 'check') {
      return const DesignRegistrabilityCheckPage();
    }
    if (stageSegments.first == 'editor') {
      return const DesignEditorPage();
    }
    if (stageSegments.first == 'preview') {
      return const DesignPreviewPage();
    }
    if (stageSegments.first == 'export') {
      return const DesignExportPage();
    }
    if (stageSegments.first == 'share') {
      return const DesignSharePage();
    }
    if (stageSegments.first == 'versions') {
      return const DesignVersionHistoryPage();
    }
    return CreationStagePage(stageSegments: stageSegments);
  }

  @override
  Object stackKey(AppTab tab, int index) =>
      'creation-${stageSegments.join('-')}-$index';

  @override
  List<String> get pathSegments => stageSegments;

  @override
  String toString() => 'CreationStageRoute(${stageSegments.join('/')})';
}

/// ショップ詳細（素材/商品など）
class ShopDetailRoute implements IndependentRoute {
  ShopDetailRoute({
    required this.entity,
    required this.identifier,
    List<String> trailingSegments = const [],
  }) : trailingSegments = List.unmodifiable(trailingSegments);

  final String entity;
  final String identifier;
  final List<String> trailingSegments;

  @override
  Widget get page => ShopDetailPage(
    entity: entity,
    identifier: identifier,
    subPage: trailingSegments.join('/'),
  );

  @override
  Object stackKey(AppTab tab, int index) =>
      'shop-$entity-$identifier-${trailingSegments.isEmpty ? 'root' : trailingSegments.join('-')}-$index';

  @override
  List<String> get pathSegments => [entity, identifier, ...trailingSegments];

  @override
  String toString() =>
      'ShopDetailRoute(entity: $entity, id: $identifier, sub: $trailingSegments)';
}

class CartRoute implements IndependentRoute, StandaloneLocationRoute {
  const CartRoute();

  @override
  Widget get page => const CartScreen();

  @override
  Object stackKey(AppTab tab, int index) => 'cart-$index';

  @override
  List<String> get pathSegments => const ['cart'];

  @override
  String get standaloneLocation => 'cart';

  @override
  String toString() => 'CartRoute()';
}

class CheckoutRoute implements IndependentRoute, StandaloneLocationRoute {
  CheckoutRoute([List<String> segments = const ['address']])
    : segments = List.unmodifiable(
        segments.isEmpty ? const ['address'] : segments,
      );

  final List<String> segments;

  @override
  Widget get page {
    final primary = segments.isEmpty ? 'address' : segments.first;
    switch (primary) {
      case 'address':
        return const CheckoutAddressScreen();
      case 'shipping':
        return const CheckoutShippingScreen();
      case 'payment':
        return const CheckoutPaymentScreen();
      case 'review':
        return const CheckoutReviewScreen();
      case 'complete':
        final orderId = segments.length >= 2 ? segments[1] : null;
        return CheckoutCompleteScreen(orderId: orderId);
      default:
        return const CheckoutAddressScreen();
    }
  }

  @override
  Object stackKey(AppTab tab, int index) =>
      'checkout-${segments.join('-')}-$index';

  @override
  List<String> get pathSegments => ['checkout', ...segments];

  @override
  String get standaloneLocation => ['checkout', ...segments].join('/');

  @override
  String toString() => 'CheckoutRoute(${segments.join('/')})';
}

/// 注文詳細
class OrderDetailsRoute implements IndependentRoute {
  OrderDetailsRoute({required this.orderId, List<String> trailing = const []})
    : trailingSegments = List.unmodifiable(trailing);

  final String orderId;
  final List<String> trailingSegments;

  @override
  Widget get page =>
      OrderDetailsScreen(orderId: orderId, subPage: trailingSegments.join('/'));

  @override
  Object stackKey(AppTab tab, int index) =>
      'orders-$orderId-${trailingSegments.isEmpty ? 'root' : trailingSegments.join('-')}-$index';

  @override
  List<String> get pathSegments => [orderId, ...trailingSegments];

  @override
  String toString() =>
      'OrderDetailsRoute(orderId: $orderId, sub: $trailingSegments)';
}

class OrderTrackingRoute implements IndependentRoute {
  const OrderTrackingRoute({required this.orderId});

  final String orderId;

  @override
  Widget get page => OrderTrackingScreen(orderId: orderId);

  @override
  Object stackKey(AppTab tab, int index) => 'orders-$orderId-tracking-$index';

  @override
  List<String> get pathSegments => [orderId, 'tracking'];

  @override
  String toString() => 'OrderTrackingRoute(orderId: $orderId)';
}

class OrderInvoiceRoute implements IndependentRoute {
  const OrderInvoiceRoute({required this.orderId});

  final String orderId;

  @override
  Widget get page => OrderInvoiceScreen(orderId: orderId);

  @override
  Object stackKey(AppTab tab, int index) => 'orders-$orderId-invoice-$index';

  @override
  List<String> get pathSegments => [orderId, 'invoice'];

  @override
  String toString() => 'OrderInvoiceRoute(orderId: $orderId)';
}

class OrderReorderRoute implements IndependentRoute {
  const OrderReorderRoute({required this.orderId});

  final String orderId;

  @override
  Widget get page => OrderReorderScreen(orderId: orderId);

  @override
  Object stackKey(AppTab tab, int index) => 'orders-$orderId-reorder-$index';

  @override
  List<String> get pathSegments => [orderId, 'reorder'];

  @override
  String toString() => 'OrderReorderRoute(orderId: $orderId)';
}

/// マイ印鑑詳細
class LibraryEntryRoute implements IndependentRoute {
  LibraryEntryRoute({required this.designId, List<String> trailing = const []})
    : trailingSegments = List.unmodifiable(trailing);

  final String designId;
  final List<String> trailingSegments;

  @override
  Widget get page {
    if (trailingSegments.isNotEmpty) {
      final primary = trailingSegments.first;
      if (primary == 'versions') {
        return LibraryDesignVersionsPage(designId: designId);
      }
    }
    return LibraryEntryScreen(
      designId: designId,
      subPage: trailingSegments.isEmpty ? null : trailingSegments.join('/'),
    );
  }

  @override
  Object stackKey(AppTab tab, int index) =>
      'library-$designId-${trailingSegments.isEmpty ? 'root' : trailingSegments.join('-')}-$index';

  @override
  List<String> get pathSegments => [designId, ...trailingSegments];

  @override
  String toString() =>
      'LibraryEntryRoute(designId: $designId, sub: $trailingSegments)';
}

/// プロフィール配下セクション
class ProfileSectionRoute implements IndependentRoute {
  ProfileSectionRoute(List<String> segments)
    : sectionSegments = List.unmodifiable(segments);

  final List<String> sectionSegments;

  @override
  Widget get page => ProfileSectionPage(sectionSegments: sectionSegments);

  @override
  Object stackKey(AppTab tab, int index) =>
      'profile-${sectionSegments.join('-')}-$index';

  @override
  List<String> get pathSegments => sectionSegments;

  @override
  String toString() => 'ProfileSectionRoute(${sectionSegments.join('/')})';
}

/// ガイドコンテンツ
class GuidesRoute implements IndependentRoute {
  GuidesRoute({List<String> sectionSegments = const []})
    : sectionSegments = List.unmodifiable(sectionSegments);

  final List<String> sectionSegments;

  @override
  Widget get page => GuidesPage(sectionSegments: sectionSegments);

  @override
  Object stackKey(AppTab tab, int index) =>
      'guides-${sectionSegments.isEmpty ? 'root' : sectionSegments.join('-')}-$index';

  @override
  List<String> get pathSegments => ['guides', ...sectionSegments];

  @override
  String toString() => 'GuidesRoute(sectionSegments: $sectionSegments)';
}

/// グローバル通知スタック
class NotificationsRoute implements IndependentRoute {
  const NotificationsRoute();

  @override
  Widget get page => const NotificationInboxPage();

  @override
  Object stackKey(AppTab tab, int index) => 'notifications-$index';

  @override
  List<String> get pathSegments => const ['notifications'];

  @override
  String toString() => 'NotificationsRoute()';
}

/// グローバル検索スタック
class GlobalSearchRoute implements IndependentRoute {
  const GlobalSearchRoute();

  @override
  Widget get page => const GlobalSearchPage();

  @override
  Object stackKey(AppTab tab, int index) => 'search-$index';

  @override
  List<String> get pathSegments => const ['search'];

  @override
  String toString() => 'GlobalSearchRoute()';
}

class AuthFlowRoute implements IndependentRoute, StandaloneLocationRoute {
  const AuthFlowRoute({this.nextPath});

  final String? nextPath;

  @override
  Widget get page => AuthScreen(nextPath: nextPath);

  @override
  Object stackKey(AppTab tab, int index) => 'auth-${nextPath ?? 'root'}-$index';

  @override
  List<String> get pathSegments {
    if (nextPath == null || nextPath!.isEmpty) {
      return const ['auth'];
    }
    final encoded = Uri.encodeComponent(nextPath!);
    return ['auth', 'redirect', encoded];
  }

  @override
  String get standaloneLocation {
    if (nextPath == null || nextPath!.isEmpty) {
      return 'auth';
    }
    final uri = Uri(path: 'auth', queryParameters: {'next': nextPath});
    return uri.toString();
  }

  @override
  String toString() => 'AuthFlowRoute(nextPath: $nextPath)';
}
