// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/auth/view/auth_page.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view/design_ai_page.dart';
import 'package:app/features/designs/view/design_check_page.dart';
import 'package:app/features/designs/view/design_editor_page.dart';
import 'package:app/features/designs/view/design_export_page.dart';
import 'package:app/features/designs/view/design_input_page.dart';
import 'package:app/features/designs/view/design_preview_page.dart';
import 'package:app/features/designs/view/design_style_selection_page.dart';
import 'package:app/features/designs/view/design_type_selection_page.dart';
import 'package:app/features/designs/view/kanji_mapping_page.dart';
import 'package:app/features/home/view/home_page.dart';
import 'package:app/features/notifications/view/notifications_page.dart';
import 'package:app/features/onboarding/view/onboarding_page.dart';
import 'package:app/features/preferences/view/locale_selection_page.dart';
import 'package:app/features/preferences/view/persona_selection_page.dart';
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
          builder: (context, state) => const TabPlaceholderPage(
            title: 'バージョン履歴',
            routePath: AppRoutePaths.designVersions,
            showBack: true,
          ),
        ),
        GoRoute(
          path: 'share',
          builder: (context, state) => const TabPlaceholderPage(
            title: '共有',
            routePath: AppRoutePaths.designShare,
            showBack: true,
          ),
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
      pageBuilder: (context, state) => const NoTransitionPage(
        child: TabPlaceholderPage(
          title: 'ショップ',
          routePath: AppRoutePaths.shop,
          detail: 'Shop tab root',
        ),
      ),
    ),
    GoRoute(
      path: AppRoutePaths.cart,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: 'カート',
        routePath: AppRoutePaths.cart,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutAddress,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '配送先',
        routePath: AppRoutePaths.checkoutAddress,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutShipping,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '配送方法',
        routePath: AppRoutePaths.checkoutShipping,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutPayment,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '支払い',
        routePath: AppRoutePaths.checkoutPayment,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutReview,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '注文確認',
        routePath: AppRoutePaths.checkoutReview,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.checkoutComplete,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '注文完了',
        routePath: AppRoutePaths.checkoutComplete,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.materialDetail,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '素材詳細',
        routePath: AppRoutePaths.materialDetail,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.productDetail,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: '商品詳細',
        routePath: AppRoutePaths.productDetail,
        showBack: true,
      ),
    ),
    GoRoute(
      path: AppRoutePaths.productAddons,
      parentNavigatorKey: tabKey,
      builder: (context, state) => const TabPlaceholderPage(
        title: 'オプション',
        routePath: AppRoutePaths.productAddons,
        showBack: true,
      ),
    ),
  ];
}

List<RouteBase> _ordersRoutes(GlobalKey<NavigatorState> tabKey) {
  return [
    GoRoute(
      path: AppRoutePaths.orders,
      parentNavigatorKey: tabKey,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: TabPlaceholderPage(
          title: '注文',
          routePath: AppRoutePaths.orders,
          detail: 'Orders tab root',
        ),
      ),
      routes: [
        GoRoute(
          path: ':orderId',
          builder: (context, state) => TabPlaceholderPage(
            title: '注文詳細',
            routePath:
                '${AppRoutePaths.orders}/${state.pathParameters['orderId'] ?? ''}',
            showBack: true,
          ),
          routes: [
            GoRoute(
              path: 'production',
              builder: (context, state) => const TabPlaceholderPage(
                title: '制作進捗',
                routePath: AppRoutePaths.orderProduction,
                showBack: true,
              ),
            ),
            GoRoute(
              path: 'tracking',
              builder: (context, state) => const TabPlaceholderPage(
                title: '配送トラッキング',
                routePath: AppRoutePaths.orderTracking,
                showBack: true,
              ),
            ),
            GoRoute(
              path: 'invoice',
              builder: (context, state) => const TabPlaceholderPage(
                title: '領収書',
                routePath: AppRoutePaths.orderInvoice,
                showBack: true,
              ),
            ),
            GoRoute(
              path: 'reorder',
              builder: (context, state) => const TabPlaceholderPage(
                title: '再注文',
                routePath: AppRoutePaths.orderReorder,
                showBack: true,
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
      pageBuilder: (context, state) => const NoTransitionPage(
        child: TabPlaceholderPage(
          title: 'マイ印鑑',
          routePath: AppRoutePaths.library,
          detail: 'Library tab root',
        ),
      ),
      routes: [
        GoRoute(
          path: ':designId',
          builder: (context, state) => TabPlaceholderPage(
            title: '印鑑詳細',
            routePath:
                '${AppRoutePaths.library}/${state.pathParameters['designId'] ?? ''}',
            showBack: true,
          ),
          routes: [
            GoRoute(
              path: 'versions',
              builder: (context, state) => const TabPlaceholderPage(
                title: 'バージョン',
                routePath: AppRoutePaths.libraryVersions,
                showBack: true,
              ),
            ),
            GoRoute(
              path: 'duplicate',
              builder: (context, state) => const TabPlaceholderPage(
                title: '複製',
                routePath: AppRoutePaths.libraryDuplicate,
                showBack: true,
              ),
            ),
            GoRoute(
              path: 'export',
              builder: (context, state) => const TabPlaceholderPage(
                title: '出力',
                routePath: AppRoutePaths.libraryExport,
                showBack: true,
              ),
            ),
            GoRoute(
              path: 'shares',
              builder: (context, state) => const TabPlaceholderPage(
                title: '共有リンク',
                routePath: AppRoutePaths.libraryShares,
                showBack: true,
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
      pageBuilder: (context, state) => const NoTransitionPage(
        child: TabPlaceholderPage(
          title: 'プロフィール',
          routePath: AppRoutePaths.profile,
          detail: 'Profile tab root',
        ),
      ),
      routes: [
        GoRoute(
          path: 'guides',
          builder: (context, state) => const TabPlaceholderPage(
            title: 'ガイド一覧',
            routePath: AppRoutePaths.guides,
            showBack: true,
          ),
          routes: [
            GoRoute(
              path: ':slug',
              builder: (context, state) => TabPlaceholderPage(
                title: 'ガイド詳細',
                routePath:
                    '${AppRoutePaths.guides}/${state.pathParameters['slug'] ?? ''}',
                showBack: true,
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'kanji/dictionary',
          builder: (context, state) => const TabPlaceholderPage(
            title: '漢字辞典',
            routePath: AppRoutePaths.kanjiDictionary,
            showBack: true,
          ),
        ),
        GoRoute(
          path: 'howto',
          builder: (context, state) => const TabPlaceholderPage(
            title: '使い方',
            routePath: AppRoutePaths.howto,
            showBack: true,
          ),
        ),
        GoRoute(
          path: 'addresses',
          builder: (context, state) => const TabPlaceholderPage(
            title: '住所',
            routePath: AppRoutePaths.profileAddresses,
            showBack: true,
          ),
        ),
        GoRoute(
          path: 'payments',
          builder: (context, state) => const TabPlaceholderPage(
            title: '支払い方法',
            routePath: AppRoutePaths.profilePayments,
            showBack: true,
          ),
        ),
        GoRoute(
          path: 'notifications',
          builder: (context, state) => const TabPlaceholderPage(
            title: '通知設定',
            routePath: AppRoutePaths.profileNotifications,
            showBack: true,
          ),
        ),
        GoRoute(
          path: 'locale',
          builder: (context, state) =>
              const LocaleSelectionPage(onCompleteRoute: AppRoutePaths.profile),
        ),
        GoRoute(
          path: 'legal',
          builder: (context, state) => const TabPlaceholderPage(
            title: '規約',
            routePath: AppRoutePaths.profileLegal,
            showBack: true,
          ),
        ),
        GoRoute(
          path: 'support',
          builder: (context, state) => const TabPlaceholderPage(
            title: 'サポート',
            routePath: AppRoutePaths.profileSupport,
            showBack: true,
          ),
        ),
        GoRoute(
          path: 'linked-accounts',
          builder: (context, state) => const TabPlaceholderPage(
            title: '連携アカウント',
            routePath: AppRoutePaths.profileLinkedAccounts,
            showBack: true,
          ),
        ),
        GoRoute(
          path: 'export',
          builder: (context, state) => const TabPlaceholderPage(
            title: 'データ出力',
            routePath: AppRoutePaths.profileExport,
            showBack: true,
          ),
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
