// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/auth/view/auth_page.dart';
import 'package:app/features/cart/view/cart_page.dart';
import 'package:app/features/catalog/view/material_detail_page.dart';
import 'package:app/features/catalog/view/product_addons_page.dart';
import 'package:app/features/catalog/view/product_detail_page.dart';
import 'package:app/features/catalog/view/shop_home_page.dart';
import 'package:app/features/checkout/view/checkout_address_page.dart';
import 'package:app/features/checkout/view/checkout_complete_page.dart';
import 'package:app/features/checkout/view/checkout_payment_page.dart';
import 'package:app/features/checkout/view/checkout_review_page.dart';
import 'package:app/features/checkout/view/checkout_shipping_page.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view/design_ai_page.dart';
import 'package:app/features/designs/view/design_check_page.dart';
import 'package:app/features/designs/view/design_editor_page.dart';
import 'package:app/features/designs/view/design_export_page.dart';
import 'package:app/features/designs/view/design_input_page.dart';
import 'package:app/features/designs/view/design_preview_page.dart';
import 'package:app/features/designs/view/design_share_page.dart';
import 'package:app/features/designs/view/design_style_selection_page.dart';
import 'package:app/features/designs/view/design_type_selection_page.dart';
import 'package:app/features/designs/view/design_versions_page.dart';
import 'package:app/features/designs/view/kanji_mapping_page.dart';
import 'package:app/features/guides/view/guide_detail_page.dart';
import 'package:app/features/guides/view/guides_list_page.dart';
import 'package:app/features/home/view/home_page.dart';
import 'package:app/features/howto/view/howto_page.dart';
import 'package:app/features/kanji_dictionary/view/kanji_dictionary_page.dart';
import 'package:app/features/library/view/library_design_detail_page.dart';
import 'package:app/features/library/view/library_design_duplicate_page.dart';
import 'package:app/features/library/view/library_design_export_page.dart';
import 'package:app/features/library/view/library_design_shares_page.dart';
import 'package:app/features/library/view/library_design_versions_page.dart';
import 'package:app/features/library/view/library_list_page.dart';
import 'package:app/features/notifications/view/notifications_page.dart';
import 'package:app/features/onboarding/view/onboarding_page.dart';
import 'package:app/features/orders/view/order_detail_page.dart';
import 'package:app/features/orders/view/order_invoice_page.dart';
import 'package:app/features/orders/view/order_production_timeline_page.dart';
import 'package:app/features/orders/view/order_reorder_page.dart';
import 'package:app/features/orders/view/order_tracking_page.dart';
import 'package:app/features/orders/view/orders_page.dart';
import 'package:app/features/preferences/view/locale_selection_page.dart';
import 'package:app/features/preferences/view/persona_selection_page.dart';
import 'package:app/features/profile/view/profile_addresses_page.dart';
import 'package:app/features/profile/view/profile_export_page.dart';
import 'package:app/features/profile/view/profile_home_page.dart';
import 'package:app/features/profile/view/profile_legal_page.dart';
import 'package:app/features/profile/view/profile_linked_accounts_page.dart';
import 'package:app/features/profile/view/profile_locale_page.dart';
import 'package:app/features/profile/view/profile_notifications_page.dart';
import 'package:app/features/profile/view/profile_payments_page.dart';
import 'package:app/features/profile/view/profile_support_page.dart';
import 'package:app/features/search/view/search_page.dart';
import 'package:app/features/shell/view/navigation_shell.dart';
import 'package:app/features/shell/view/tab_placeholder_page.dart';
import 'package:app/features/splash/view/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

final tabNavigatorKeysProvider = Provider<TabNavigatorKeys>((ref) {
  return TabNavigatorKeys();
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final keys = ref.watch(tabNavigatorKeysProvider);

  return GoRouter(
    navigatorKey: keys.rootKey,
    initialLocation: AppRoutePaths.splash,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShellScaffold(
            navigationShell: navigationShell,
            navigatorForIndex: keys.navigatorForIndex,
          );
        },
        branches: [
          StatefulShellBranch(
            initialLocation: AppRoutePaths.home,
            navigatorKey: keys.designTabKey,
            routes: _designRoutes(keys.designTabKey),
          ),
          StatefulShellBranch(
            navigatorKey: keys.shopTabKey,
            routes: _shopRoutes(keys.shopTabKey),
          ),
          StatefulShellBranch(
            navigatorKey: keys.ordersTabKey,
            routes: _ordersRoutes(keys.ordersTabKey),
          ),
          StatefulShellBranch(
            navigatorKey: keys.libraryTabKey,
            routes: _libraryRoutes(keys.libraryTabKey),
          ),
          StatefulShellBranch(
            navigatorKey: keys.profileTabKey,
            routes: _profileRoutes(keys.profileTabKey),
          ),
        ],
      ),
      ..._globalRoutes(keys),
    ],
    errorBuilder: (context, state) => TabPlaceholderPage(
      title: 'Not found',
      routePath: state.uri.toString(),
      detail: 'No route matched this path.',
      showBack: true,
    ),
  );
});

class TabNavigatorKeys {
  TabNavigatorKeys()
    : rootKey = GlobalKey<NavigatorState>(debugLabel: 'rootNavigator'),
      designTabKey = GlobalKey<NavigatorState>(debugLabel: 'designTab'),
      shopTabKey = GlobalKey<NavigatorState>(debugLabel: 'shopTab'),
      ordersTabKey = GlobalKey<NavigatorState>(debugLabel: 'ordersTab'),
      libraryTabKey = GlobalKey<NavigatorState>(debugLabel: 'libraryTab'),
      profileTabKey = GlobalKey<NavigatorState>(debugLabel: 'profileTab');

  final GlobalKey<NavigatorState> rootKey;
  final GlobalKey<NavigatorState> designTabKey;
  final GlobalKey<NavigatorState> shopTabKey;
  final GlobalKey<NavigatorState> ordersTabKey;
  final GlobalKey<NavigatorState> libraryTabKey;
  final GlobalKey<NavigatorState> profileTabKey;

  GlobalKey<NavigatorState> navigatorForIndex(int index) {
    return switch (index) {
      0 => designTabKey,
      1 => shopTabKey,
      2 => ordersTabKey,
      3 => libraryTabKey,
      _ => profileTabKey,
    };
  }
}

List<RouteBase> _designRoutes(GlobalKey<NavigatorState> tabKey) {
  return [
    GoRoute(
      path: AppRoutePaths.home,
      parentNavigatorKey: tabKey,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: HomePage()),
    ),
    GoRoute(
      path: AppRoutePaths.design,
      parentNavigatorKey: tabKey,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: TabPlaceholderPage(
          title: '作成',
          routePath: AppRoutePaths.design,
          detail: 'Design tab root',
        ),
      ),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const DesignTypeSelectionPage(),
        ),
        GoRoute(
          path: 'input',
          builder: (context, state) {
            final mode = state.uri.queryParameters['mode'];
            DesignSourceType? sourceType;
            if (mode != null) {
              try {
                sourceType = DesignSourceTypeX.fromJson(mode);
              } catch (_) {}
            }
            return DesignInputPage(sourceType: sourceType);
          },
          routes: [
            GoRoute(
              path: 'kanji-map',
              builder: (context, state) => const KanjiMappingPage(),
            ),
          ],
        ),
        GoRoute(
          path: 'style',
          builder: (context, state) {
            final mode = state.uri.queryParameters['mode'];
            DesignSourceType? sourceType;
            if (mode != null) {
              try {
                sourceType = DesignSourceTypeX.fromJson(mode);
              } catch (_) {}
            }
            final filters =
                state.uri.queryParameters['filters']
                    ?.split(',')
                    .where((value) => value.trim().isNotEmpty)
                    .map((value) => value.trim())
                    .toSet() ??
                const <String>{};

            return DesignStyleSelectionPage(
              sourceType: sourceType,
              queryFilters: filters,
            );
          },
        ),
        GoRoute(
          path: 'editor',
          builder: (context, state) => const DesignEditorPage(),
        ),
        GoRoute(path: 'ai', builder: (context, state) => const DesignAiPage()),
        GoRoute(
          path: 'check',
          builder: (context, state) => const DesignCheckPage(),
        ),
        GoRoute(
          path: 'preview',
          builder: (context, state) => const DesignPreviewPage(),
        ),
        GoRoute(
          path: 'export',
          builder: (context, state) => const DesignExportPage(),
        ),
        GoRoute(
          path: 'versions',
          builder: (context, state) => const DesignVersionsPage(),
        ),
        GoRoute(
          path: 'share',
          builder: (context, state) => const DesignSharePage(),
        ),
      ],
    ),
  ];
}

List<RouteBase> _shopRoutes(GlobalKey<NavigatorState> tabKey) {
  return [
    GoRoute(
      path: AppRoutePaths.shop,
      parentNavigatorKey: tabKey,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: ShopHomePage()),
    ),
    GoRoute(
      path: AppRoutePaths.cart,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const CartPage(),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutAddress,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const CheckoutAddressPage(),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutShipping,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const CheckoutShippingPage(),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutPayment,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const CheckoutPaymentPage(),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutReview,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const CheckoutReviewPage(),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutComplete,
      parentNavigatorKey: tabKey,
      builder: (context, state) {
        final orderId = state.uri.queryParameters['orderId'];
        final orderNumber = state.uri.queryParameters['orderNumber'];
        return CheckoutCompletePage(orderId: orderId, orderNumber: orderNumber);
      },
    ),
    GoRoute(
      path: AppRoutePaths.materialDetail,
      parentNavigatorKey: tabKey,
      builder: (context, state) => MaterialDetailPage(
        materialId: state.pathParameters['materialId'] ?? '',
      ),
    ),
    GoRoute(
      path: AppRoutePaths.productDetail,
      parentNavigatorKey: tabKey,
      builder: (context, state) =>
          ProductDetailPage(productId: state.pathParameters['productId'] ?? ''),
    ),
    GoRoute(
      path: AppRoutePaths.productAddons,
      parentNavigatorKey: tabKey,
      builder: (context, state) =>
          ProductAddonsPage(productId: state.pathParameters['productId'] ?? ''),
    ),
  ];
}

List<RouteBase> _ordersRoutes(GlobalKey<NavigatorState> tabKey) {
  return [
    GoRoute(
      path: AppRoutePaths.orders,
      parentNavigatorKey: tabKey,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: OrdersPage()),
      routes: [
        GoRoute(
          path: ':orderId',
          builder: (context, state) =>
              OrderDetailPage(orderId: state.pathParameters['orderId'] ?? ''),
          routes: [
            GoRoute(
              path: 'production',
              builder: (context, state) => OrderProductionTimelinePage(
                orderId: state.pathParameters['orderId'] ?? '',
              ),
            ),
            GoRoute(
              path: 'tracking',
              builder: (context, state) => OrderTrackingPage(
                orderId: state.pathParameters['orderId'] ?? '',
              ),
            ),
            GoRoute(
              path: 'invoice',
              builder: (context, state) => OrderInvoicePage(
                orderId: state.pathParameters['orderId'] ?? '',
              ),
            ),
            GoRoute(
              path: 'reorder',
              builder: (context, state) => OrderReorderPage(
                orderId: state.pathParameters['orderId'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}

List<RouteBase> _libraryRoutes(GlobalKey<NavigatorState> tabKey) {
  return [
    GoRoute(
      path: AppRoutePaths.library,
      parentNavigatorKey: tabKey,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: LibraryListPage()),
      routes: [
        GoRoute(
          path: ':designId',
          builder: (context, state) => LibraryDesignDetailPage(
            designId: state.pathParameters['designId'] ?? '',
          ),
          routes: [
            GoRoute(
              path: 'versions',
              builder: (context, state) => LibraryDesignVersionsPage(
                designId: state.pathParameters['designId'] ?? '',
              ),
            ),
            GoRoute(
              path: 'duplicate',
              builder: (context, state) => LibraryDesignDuplicatePage(
                designId: state.pathParameters['designId'] ?? '',
              ),
            ),
            GoRoute(
              path: 'export',
              builder: (context, state) => LibraryDesignExportPage(
                designId: state.pathParameters['designId'] ?? '',
                designOverride: state.extra is Design
                    ? state.extra! as Design
                    : null,
              ),
            ),
            GoRoute(
              path: 'shares',
              builder: (context, state) => LibraryDesignSharesPage(
                designId: state.pathParameters['designId'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}

List<RouteBase> _profileRoutes(GlobalKey<NavigatorState> tabKey) {
  return [
    GoRoute(
      path: AppRoutePaths.profile,
      parentNavigatorKey: tabKey,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: ProfileHomePage()),
      routes: [
        GoRoute(
          path: 'guides',
          builder: (context, state) => const GuidesListPage(),
          routes: [
            GoRoute(
              path: ':slug',
              builder: (context, state) => GuideDetailPage(
                slug: state.pathParameters['slug'] ?? '',
                lang: state.uri.queryParameters['lang'],
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'kanji/dictionary',
          builder: (context, state) {
            final initialQuery = state.uri.queryParameters['q'];
            final insertField = parseNameFieldParam(
              state.uri.queryParameters['insertField'],
            );
            final returnTo = state.uri.queryParameters['returnTo'];
            return KanjiDictionaryPage(
              initialQuery: initialQuery,
              insertField: insertField,
              returnTo: returnTo,
            );
          },
        ),
        GoRoute(path: 'howto', builder: (context, state) => const HowtoPage()),
        GoRoute(
          path: 'addresses',
          builder: (context, state) => const ProfileAddressesPage(),
        ),
        GoRoute(
          path: 'payments',
          builder: (context, state) => const ProfilePaymentsPage(),
        ),
        GoRoute(
          path: 'notifications',
          builder: (context, state) => const ProfileNotificationsPage(),
        ),
        GoRoute(
          path: 'locale',
          builder: (context, state) => const ProfileLocalePage(),
        ),
        GoRoute(
          path: 'legal',
          builder: (context, state) => const ProfileLegalPage(),
        ),
        GoRoute(
          path: 'support',
          builder: (context, state) => const ProfileSupportPage(),
        ),
        GoRoute(
          path: 'linked-accounts',
          builder: (context, state) => const ProfileLinkedAccountsPage(),
        ),
        GoRoute(
          path: 'export',
          builder: (context, state) => const ProfileExportPage(),
        ),
        GoRoute(
          path: 'delete',
          builder: (context, state) => const TabPlaceholderPage(
            title: 'アカウント削除',
            routePath: AppRoutePaths.profileDelete,
            showBack: true,
          ),
        ),
      ],
    ),
  ];
}

List<RouteBase> _globalRoutes(TabNavigatorKeys keys) {
  return [
    GoRoute(
      path: AppRoutePaths.guides,
      parentNavigatorKey: keys.rootKey,
      redirect: (context, state) => '${AppRoutePaths.profile}/guides',
    ),
    GoRoute(
      path: AppRoutePaths.guideDetail,
      parentNavigatorKey: keys.rootKey,
      redirect: (context, state) {
        final slug = state.pathParameters['slug'] ?? '';
        final lang = state.uri.queryParameters['lang'];
        final qp = lang != null && lang.isNotEmpty ? '?lang=$lang' : '';
        return '${AppRoutePaths.profile}/guides/$slug$qp';
      },
    ),
    GoRoute(
      path: AppRoutePaths.kanjiDictionary,
      parentNavigatorKey: keys.rootKey,
      redirect: (context, state) {
        final qp = state.uri.query.isEmpty ? '' : '?${state.uri.query}';
        return '${AppRoutePaths.profile}/kanji/dictionary$qp';
      },
    ),
    GoRoute(
      path: AppRoutePaths.howto,
      parentNavigatorKey: keys.rootKey,
      redirect: (context, state) => '${AppRoutePaths.profile}/howto',
    ),
    GoRoute(
      path: AppRoutePaths.splash,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: AppRoutePaths.onboarding,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: AppRoutePaths.locale,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const LocaleSelectionPage(),
    ),
    GoRoute(
      path: AppRoutePaths.persona,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const PersonaSelectionPage(),
    ),
    GoRoute(
      path: AppRoutePaths.auth,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const AuthPage(),
    ),
    GoRoute(
      path: AppRoutePaths.notifications,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: AppRoutePaths.search,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: AppRoutePaths.supportFaq,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: 'FAQ',
        routePath: AppRoutePaths.supportFaq,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.supportContact,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '問い合わせ',
        routePath: AppRoutePaths.supportContact,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.supportChat,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: 'チャット',
        routePath: AppRoutePaths.supportChat,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.status,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: 'ステータス',
        routePath: AppRoutePaths.status,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.permissions,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '権限',
        routePath: AppRoutePaths.permissions,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.changelog,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '変更履歴',
        routePath: AppRoutePaths.changelog,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.appUpdate,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: 'アップデート',
        routePath: AppRoutePaths.appUpdate,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.offline,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: 'オフライン',
        routePath: AppRoutePaths.offline,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.error,
      parentNavigatorKey: keys.rootKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: 'エラー',
        routePath: AppRoutePaths.error,
        showBack: true,
      ),
    ),
  ];
}
