// ignore_for_file: public_member_api_docs

import 'package:app/core/network/network_providers.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/app_update/view/app_update_page.dart';
import 'package:app/features/auth/view/auth_page.dart';
import 'package:app/features/error/view/error_page.dart';
import 'package:app/features/notifications/view/notifications_page.dart';
import 'package:app/features/offline/view/offline_page.dart';
import 'package:app/features/onboarding/view/onboarding_page.dart';
import 'package:app/features/permissions/view/permissions_onboarding_page.dart';
import 'package:app/features/preferences/view/locale_selection_page.dart';
import 'package:app/features/preferences/view/persona_selection_page.dart';
import 'package:app/features/search/view/search_page.dart';
import 'package:app/features/shell/view/navigation_shell.dart';
import 'package:app/features/shell/view/tab_placeholder_page.dart';
import 'package:app/features/splash/view/splash_page.dart';
import 'package:app/features/status/view/system_status_page.dart';
import 'package:app/features/support/view/faq_page.dart';
import 'package:app/features/support/view/support_chat_page.dart';
import 'package:app/features/support/view/support_contact_page.dart';
import 'package:app/features/updates/view/changelog_page.dart';
import 'package:app/shared/providers/app_update_provider.dart';
import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

final appNavigationProvider = AppNavigationViewModel();

class AppNavState {
  const AppNavState({
    required this.rootPages,
    required this.currentTab,
    required this.pagesByTab,
    required this.currentLocation,
    this.lastOnlineLocation,
  });

  final List<PageEntry> rootPages;
  final AppTab currentTab;
  final Map<AppTab, List<PageEntry>> pagesByTab;
  final String currentLocation;
  final String? lastOnlineLocation;

  AppNavState copyWith({
    List<PageEntry>? rootPages,
    AppTab? currentTab,
    Map<AppTab, List<PageEntry>>? pagesByTab,
    String? currentLocation,
    String? lastOnlineLocation,
  }) {
    return AppNavState(
      rootPages: rootPages ?? this.rootPages,
      currentTab: currentTab ?? this.currentTab,
      pagesByTab: pagesByTab ?? this.pagesByTab,
      currentLocation: currentLocation ?? this.currentLocation,
      lastOnlineLocation: lastOnlineLocation ?? this.lastOnlineLocation,
    );
  }
}

class AppNavigationViewModel extends Provider<AppNavState> {
  AppNavigationViewModel() : super.args(null);

  static const PageEntry _shellPage = PageEntry(
    key: 'shell_root',
    name: '__shell__',
  );

  int _pageCounter = 0;

  @override
  AppNavState build(Ref<AppNavState> ref) {
    return const AppNavState(
      rootPages: [PageEntry(key: 'splash', name: AppRoutePaths.splash)],
      currentTab: AppTab.design,
      pagesByTab: {
        AppTab.design: [
          PageEntry(key: 'tab_design_root', name: AppRoutePaths.home),
        ],
        AppTab.shop: [
          PageEntry(key: 'tab_shop_root', name: AppRoutePaths.shop),
        ],
        AppTab.orders: [
          PageEntry(key: 'tab_orders_root', name: AppRoutePaths.orders),
        ],
        AppTab.library: [
          PageEntry(key: 'tab_library_root', name: AppRoutePaths.library),
        ],
        AppTab.profile: [
          PageEntry(key: 'tab_profile_root', name: AppRoutePaths.profile),
        ],
      },
      currentLocation: AppRoutePaths.splash,
    );
  }

  late final selectTabMut = mutation<void>(#selectTab);
  Call<void, AppNavState> selectTab(AppTab tab) =>
      mutate(selectTabMut, (ref) async {
        ref.state = ref.watch(this).copyWith(currentTab: tab);
      });

  late final setPagesMut = mutation<void>(#setPages);
  Call<void, AppNavState> setPages(AppTab tab, List<PageEntry> pages) =>
      mutate(setPagesMut, (ref) async {
        ref.state = ref
            .watch(this)
            .copyWith(pagesByTab: {...ref.watch(this).pagesByTab, tab: pages});
      });

  late final goMut = mutation<void>(#go);
  Call<void, AppNavState> go(String location) => mutate(goMut, (ref) async {
    _applyNavigation(ref, location, isPush: false);
  });

  late final pushMut = mutation<void>(#push);
  Call<void, AppNavState> push(String location) => mutate(pushMut, (ref) async {
    _applyNavigation(ref, location, isPush: true);
  });

  late final popMut = mutation<void>(#pop);
  Call<void, AppNavState> pop() => mutate(popMut, (ref) async {
    final state = ref.watch(this);
    if (state.rootPages.length > 1) {
      final nextRoot = state.rootPages.sublist(0, state.rootPages.length - 1);
      ref.state = state.copyWith(
        rootPages: nextRoot,
        currentLocation: _currentLocationFor(state, rootPages: nextRoot),
      );
      return;
    }

    final pages = state.pagesByTab[state.currentTab] ?? const <PageEntry>[];
    if (pages.length <= 1) {
      return;
    }
    final nextPages = pages.sublist(0, pages.length - 1);
    ref.state = state.copyWith(
      pagesByTab: {...state.pagesByTab, state.currentTab: nextPages},
      currentLocation: _currentLocationFor(
        state,
        pagesByTab: {...state.pagesByTab, state.currentTab: nextPages},
      ),
    );
  });

  late final popToRootMut = mutation<void>(#popToRoot);
  Call<void, AppNavState> popToRoot(AppTab tab) =>
      mutate(popToRootMut, (ref) async {
        final state = ref.watch(this);
        final pages = state.pagesByTab[tab] ?? const <PageEntry>[];
        if (pages.length <= 1) return;
        final nextPages = [pages.first];
        ref.state = state.copyWith(
          pagesByTab: {...state.pagesByTab, tab: nextPages},
          currentLocation: _currentLocationFor(
            state,
            pagesByTab: {...state.pagesByTab, tab: nextPages},
          ),
        );
      });

  void _applyNavigation(
    Ref<AppNavState> ref,
    String location, {
    required bool isPush,
  }) {
    final state = ref.watch(this);
    final normalized = _normalizeLocation(location);
    final resolved = _resolveRoute(normalized.location);

    if (resolved == null) {
      final fallback = Uri(
        path: AppRoutePaths.error,
        queryParameters: {
          'code': 'not_found',
          'message': 'No route matched ${normalized.location}',
        },
      ).toString();
      _applyNavigation(ref, fallback, isPush: false);
      return;
    }

    if (resolved.isRootOnly) {
      final rootPages = [
        PageEntry(key: _nextKey(resolved.keyPrefix), name: resolved.location),
      ];
      ref.state = state.copyWith(
        rootPages: rootPages,
        currentLocation: resolved.location,
      );
      return;
    }

    if (resolved.isGlobalOverlay) {
      final useExisting =
          isPush &&
          state.rootPages.isNotEmpty &&
          state.rootPages.first.key == AppNavigationViewModel._shellPage.key;
      final basePages = useExisting
          ? state.rootPages
          : const [AppNavigationViewModel._shellPage];
      final overlayPages = List<PageEntry>.from(basePages)
        ..add(
          PageEntry(key: _nextKey(resolved.keyPrefix), name: resolved.location),
        );
      ref.state = state.copyWith(
        rootPages: overlayPages,
        currentLocation: resolved.location,
        lastOnlineLocation: resolved.location == AppRoutePaths.offline
            ? state.currentLocation
            : state.lastOnlineLocation,
      );
      return;
    }

    final tab = resolved.tab;
    if (tab == null) return;

    final currentPages = state.pagesByTab[tab] ?? const <PageEntry>[];
    final rootPage = _rootPageForTab(tab);

    List<PageEntry> nextPages;
    if (resolved.isTabRoot) {
      nextPages = [rootPage];
    } else if (isPush && currentPages.isNotEmpty) {
      nextPages = [...currentPages, _pageForResolved(resolved)];
    } else {
      nextPages = [
        rootPage,
        ..._parentPagesForResolved(resolved),
        _pageForResolved(resolved),
      ];
    }

    ref.state = state.copyWith(
      rootPages: const [AppNavigationViewModel._shellPage],
      currentTab: tab,
      pagesByTab: {...state.pagesByTab, tab: nextPages},
      currentLocation: resolved.location,
    );
  }

  PageEntry _pageForResolved(_ResolvedRoute resolved) {
    return PageEntry(
      key: _nextKey(resolved.keyPrefix),
      name: resolved.location,
    );
  }

  List<PageEntry> _parentPagesForResolved(_ResolvedRoute resolved) {
    if (resolved.parentPatterns.isEmpty) return const [];
    return [
      for (final pattern in resolved.parentPatterns)
        PageEntry(
          key: _nextKey(_keyPrefixForPattern(pattern)),
          name: _buildLocation(pattern, resolved.pathParams),
        ),
    ];
  }

  String _nextKey(String prefix) {
    final key = '${prefix}_$_pageCounter';
    _pageCounter += 1;
    return key;
  }

  PageEntry _rootPageForTab(AppTab tab) {
    return switch (tab) {
      AppTab.design => const PageEntry(
        key: 'tab_design_root',
        name: AppRoutePaths.home,
      ),
      AppTab.shop => const PageEntry(
        key: 'tab_shop_root',
        name: AppRoutePaths.shop,
      ),
      AppTab.orders => const PageEntry(
        key: 'tab_orders_root',
        name: AppRoutePaths.orders,
      ),
      AppTab.library => const PageEntry(
        key: 'tab_library_root',
        name: AppRoutePaths.library,
      ),
      AppTab.profile => const PageEntry(
        key: 'tab_profile_root',
        name: AppRoutePaths.profile,
      ),
    };
  }
}

class _NormalizedLocation {
  const _NormalizedLocation(this.location);

  final String location;
}

_NormalizedLocation _normalizeLocation(String location) {
  final uri = Uri.parse(location);
  final normalizedPath = uri.path.isEmpty ? AppRoutePaths.home : uri.path;

  String redirectedPath = normalizedPath;
  if (normalizedPath == AppRoutePaths.guides ||
      normalizedPath.startsWith('${AppRoutePaths.guides}/')) {
    redirectedPath = normalizedPath.replaceFirst(
      AppRoutePaths.guides,
      '${AppRoutePaths.profile}/guides',
    );
  }

  if (normalizedPath == AppRoutePaths.kanjiDictionary) {
    redirectedPath = '${AppRoutePaths.profile}/kanji/dictionary';
  }

  if (normalizedPath == AppRoutePaths.howto) {
    redirectedPath = '${AppRoutePaths.profile}/howto';
  }

  final normalizedUri = Uri(
    path: redirectedPath.startsWith('/') ? redirectedPath : '/$redirectedPath',
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
    fragment: uri.fragment.isEmpty ? null : uri.fragment,
  );

  return _NormalizedLocation(normalizedUri.toString());
}

String _currentLocationFor(
  AppNavState state, {
  List<PageEntry>? rootPages,
  Map<AppTab, List<PageEntry>>? pagesByTab,
}) {
  final effectiveRoot = rootPages ?? state.rootPages;
  if (effectiveRoot.isNotEmpty && effectiveRoot.last.key != 'shell_root') {
    return effectiveRoot.last.name;
  }
  final effectivePagesByTab = pagesByTab ?? state.pagesByTab;
  final pages = effectivePagesByTab[state.currentTab] ?? const <PageEntry>[];
  return pages.isNotEmpty ? pages.last.name : AppRoutePaths.home;
}

class _ResolvedRoute {
  const _ResolvedRoute({
    required this.location,
    required this.keyPrefix,
    required this.isRootOnly,
    required this.isGlobalOverlay,
    required this.isTabRoot,
    required this.parentPatterns,
    required this.pathParams,
    this.tab,
  });

  final String location;
  final String keyPrefix;
  final bool isRootOnly;
  final bool isGlobalOverlay;
  final bool isTabRoot;
  final List<String> parentPatterns;
  final Map<String, String> pathParams;
  final AppTab? tab;
}

class _RouteSpec {
  const _RouteSpec({
    required this.pattern,
    required this.keyPrefix,
    this.tab,
    this.isRootOnly = false,
    this.isGlobalOverlay = false,
    this.isTabRoot = false,
    this.parentPatterns = const [],
  });

  final String pattern;
  final String keyPrefix;
  final AppTab? tab;
  final bool isRootOnly;
  final bool isGlobalOverlay;
  final bool isTabRoot;
  final List<String> parentPatterns;
}

final List<_RouteSpec> _routeSpecs = [
  const _RouteSpec(
    pattern: AppRoutePaths.splash,
    keyPrefix: 'splash',
    isRootOnly: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.onboarding,
    keyPrefix: 'onboarding',
    isRootOnly: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.locale,
    keyPrefix: 'locale',
    isRootOnly: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.persona,
    keyPrefix: 'persona',
    isRootOnly: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.auth,
    keyPrefix: 'auth',
    isRootOnly: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.notifications,
    keyPrefix: 'notifications',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.search,
    keyPrefix: 'search',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.supportFaq,
    keyPrefix: 'support_faq',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.supportContact,
    keyPrefix: 'support_contact',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.supportChat,
    keyPrefix: 'support_chat',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.status,
    keyPrefix: 'status',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.permissions,
    keyPrefix: 'permissions',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.changelog,
    keyPrefix: 'changelog',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.appUpdate,
    keyPrefix: 'app_update',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.offline,
    keyPrefix: 'offline',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.error,
    keyPrefix: 'error',
    isGlobalOverlay: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.home,
    keyPrefix: 'home',
    tab: AppTab.design,
    isTabRoot: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.design,
    keyPrefix: 'design_root',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designNew,
    keyPrefix: 'design_new',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designInput,
    keyPrefix: 'design_input',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designKanjiMap,
    keyPrefix: 'design_kanji',
    tab: AppTab.design,
    parentPatterns: [AppRoutePaths.designInput],
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designStyle,
    keyPrefix: 'design_style',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designEditor,
    keyPrefix: 'design_editor',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designAi,
    keyPrefix: 'design_ai',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designCheck,
    keyPrefix: 'design_check',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designPreview,
    keyPrefix: 'design_preview',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designExport,
    keyPrefix: 'design_export',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designVersions,
    keyPrefix: 'design_versions',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.designShare,
    keyPrefix: 'design_share',
    tab: AppTab.design,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.shop,
    keyPrefix: 'shop',
    tab: AppTab.shop,
    isTabRoot: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.cart,
    keyPrefix: 'cart',
    tab: AppTab.shop,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.checkoutAddress,
    keyPrefix: 'checkout_address',
    tab: AppTab.shop,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.checkoutShipping,
    keyPrefix: 'checkout_shipping',
    tab: AppTab.shop,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.checkoutPayment,
    keyPrefix: 'checkout_payment',
    tab: AppTab.shop,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.checkoutReview,
    keyPrefix: 'checkout_review',
    tab: AppTab.shop,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.checkoutComplete,
    keyPrefix: 'checkout_complete',
    tab: AppTab.shop,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.materialDetail,
    keyPrefix: 'material_detail',
    tab: AppTab.shop,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.productDetail,
    keyPrefix: 'product_detail',
    tab: AppTab.shop,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.productAddons,
    keyPrefix: 'product_addons',
    tab: AppTab.shop,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.orders,
    keyPrefix: 'orders',
    tab: AppTab.orders,
    isTabRoot: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.orderDetail,
    keyPrefix: 'order_detail',
    tab: AppTab.orders,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.orderProduction,
    keyPrefix: 'order_production',
    tab: AppTab.orders,
    parentPatterns: [AppRoutePaths.orderDetail],
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.orderTracking,
    keyPrefix: 'order_tracking',
    tab: AppTab.orders,
    parentPatterns: [AppRoutePaths.orderDetail],
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.orderInvoice,
    keyPrefix: 'order_invoice',
    tab: AppTab.orders,
    parentPatterns: [AppRoutePaths.orderDetail],
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.orderReorder,
    keyPrefix: 'order_reorder',
    tab: AppTab.orders,
    parentPatterns: [AppRoutePaths.orderDetail],
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.library,
    keyPrefix: 'library',
    tab: AppTab.library,
    isTabRoot: true,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.libraryDetail,
    keyPrefix: 'library_detail',
    tab: AppTab.library,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.libraryVersions,
    keyPrefix: 'library_versions',
    tab: AppTab.library,
    parentPatterns: [AppRoutePaths.libraryDetail],
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.libraryDuplicate,
    keyPrefix: 'library_duplicate',
    tab: AppTab.library,
    parentPatterns: [AppRoutePaths.libraryDetail],
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.libraryExport,
    keyPrefix: 'library_export',
    tab: AppTab.library,
    parentPatterns: [AppRoutePaths.libraryDetail],
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.libraryShares,
    keyPrefix: 'library_shares',
    tab: AppTab.library,
    parentPatterns: [AppRoutePaths.libraryDetail],
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profile,
    keyPrefix: 'profile',
    tab: AppTab.profile,
    isTabRoot: true,
  ),
  const _RouteSpec(
    pattern: '${AppRoutePaths.profile}/guides',
    keyPrefix: 'profile_guides',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: '${AppRoutePaths.profile}/guides/:slug',
    keyPrefix: 'profile_guide_detail',
    tab: AppTab.profile,
    parentPatterns: ['${AppRoutePaths.profile}/guides'],
  ),
  const _RouteSpec(
    pattern: '${AppRoutePaths.profile}/kanji/dictionary',
    keyPrefix: 'profile_kanji_dictionary',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: '${AppRoutePaths.profile}/howto',
    keyPrefix: 'profile_howto',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profileAddresses,
    keyPrefix: 'profile_addresses',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profilePayments,
    keyPrefix: 'profile_payments',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profileNotifications,
    keyPrefix: 'profile_notifications',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profileLocale,
    keyPrefix: 'profile_locale',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profileLegal,
    keyPrefix: 'profile_legal',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profileSupport,
    keyPrefix: 'profile_support',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profileLinkedAccounts,
    keyPrefix: 'profile_linked_accounts',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profileExport,
    keyPrefix: 'profile_export',
    tab: AppTab.profile,
  ),
  const _RouteSpec(
    pattern: AppRoutePaths.profileDelete,
    keyPrefix: 'profile_delete',
    tab: AppTab.profile,
  ),
];

_ResolvedRoute? _resolveRoute(String location) {
  final uri = Uri.parse(location);
  for (final spec in _routeSpecs) {
    final params = _matchPath(uri.path, spec.pattern);
    if (params == null) continue;
    return _ResolvedRoute(
      location: uri.toString(),
      keyPrefix: spec.keyPrefix,
      isRootOnly: spec.isRootOnly,
      isGlobalOverlay: spec.isGlobalOverlay,
      isTabRoot: spec.isTabRoot,
      parentPatterns: spec.parentPatterns,
      pathParams: params,
      tab: spec.tab,
    );
  }
  return null;
}

Map<String, String>? _matchPath(String path, String pattern) {
  final pathSegments = Uri.parse(path).pathSegments;
  final patternSegments = Uri.parse(pattern).pathSegments;
  if (pathSegments.length != patternSegments.length) return null;

  final params = <String, String>{};
  for (var i = 0; i < pathSegments.length; i += 1) {
    final segment = pathSegments[i];
    final patternSegment = patternSegments[i];
    if (patternSegment.startsWith(':')) {
      params[patternSegment.substring(1)] = segment;
    } else if (segment != patternSegment) {
      return null;
    }
  }
  return params;
}

String _buildLocation(String pattern, Map<String, String> params) {
  var path = pattern;
  for (final entry in params.entries) {
    path = path.replaceAll(':${entry.key}', entry.value);
  }
  return path;
}

String _keyPrefixForPattern(String pattern) {
  return pattern
      .replaceAll('/', '_')
      .replaceAll(':', '')
      .replaceAll('-', '_')
      .replaceAll('__', '_')
      .trim();
}

class AppNavigationRoot extends ConsumerStatefulWidget {
  const AppNavigationRoot({super.key});

  @override
  ConsumerState<AppNavigationRoot> createState() => _AppNavigationRootState();
}

class _AppNavigationRootState extends ConsumerState<AppNavigationRoot> {
  bool _didInitListeners = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitListeners) return;
    _didInitListeners = true;

    ref.listen(connectivityStatusProvider, (previous, next) {
      final nav = ref.read(appNavigationProvider);
      if (next.isOffline && !_isOfflineAllowed(nav.currentLocation)) {
        ref.invoke(appNavigationProvider.go(AppRoutePaths.offline));
      } else if (!next.isOffline &&
          nav.currentLocation == AppRoutePaths.offline) {
        final updateStatus = ref.read(appUpdateStatusProvider).valueOrNull;
        final target = updateStatus?.isUpdateRequired == true
            ? AppRoutePaths.appUpdate
            : nav.lastOnlineLocation ?? AppRoutePaths.home;
        ref.invoke(appNavigationProvider.go(target));
      }
    });

    ref.listen(appUpdateStatusProvider, (previous, next) {
      final update = next.valueOrNull;
      if (update?.isUpdateRequired == true) {
        final nav = ref.read(appNavigationProvider);
        if (nav.currentLocation != AppRoutePaths.appUpdate) {
          ref.invoke(appNavigationProvider.go(AppRoutePaths.appUpdate));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(appNavigationProvider);

    final navigator = DeclarativePagesNavigator(
      pages: nav.rootPages,
      buildPage: _buildRootPage,
      onPopTop: () => ref.invoke(appNavigationProvider.pop()),
      canPopTop: () => nav.rootPages.length > 1,
    );

    if (nav.rootPages.length <= 1) return navigator;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.invoke(appNavigationProvider.pop());
      },
      child: navigator,
    );
  }

  Widget _buildRootPage(BuildContext context, PageEntry page) {
    if (page.key == AppNavigationViewModel._shellPage.key) {
      return const NavigationShellScaffold();
    }

    final uri = Uri.parse(page.name);
    final path = uri.path;

    if (path == AppRoutePaths.splash) return const SplashPage();
    if (path == AppRoutePaths.onboarding) return const OnboardingPage();
    if (path == AppRoutePaths.locale) return const LocaleSelectionPage();
    if (path == AppRoutePaths.persona) return const PersonaSelectionPage();
    if (path == AppRoutePaths.auth) return const AuthPage();
    if (path == AppRoutePaths.notifications) return const NotificationsPage();
    if (path == AppRoutePaths.search) return const SearchPage();
    if (path == AppRoutePaths.supportFaq) return const FaqPage();
    if (path == AppRoutePaths.supportContact) return const SupportContactPage();
    if (path == AppRoutePaths.supportChat) return const SupportChatPage();
    if (path == AppRoutePaths.status) return const SystemStatusPage();
    if (path == AppRoutePaths.permissions) {
      return const PermissionsOnboardingPage();
    }
    if (path == AppRoutePaths.changelog) return const ChangelogPage();
    if (path == AppRoutePaths.appUpdate) return const AppUpdatePage();
    if (path == AppRoutePaths.offline) return const OfflinePage();
    if (path == AppRoutePaths.error) {
      return ErrorPage(
        diagnostics: ErrorDiagnostics(
          path: uri.toString(),
          timestamp: DateTime.now(),
          code: uri.queryParameters['code'],
          message: uri.queryParameters['message'],
          source: uri.queryParameters['source'],
          returnTo: uri.queryParameters['returnTo'],
          traceId: uri.queryParameters['traceId'],
        ),
      );
    }

    return TabPlaceholderPage(
      title: 'Not found',
      routePath: page.name,
      detail: 'No route matched this path.',
      showBack: true,
    );
  }
}

bool _isOfflineAllowed(String path) {
  if (path == AppRoutePaths.offline) return true;
  if (path.startsWith(AppRoutePaths.library)) return true;
  if (path.startsWith('${AppRoutePaths.profile}/guides')) return true;
  if (path == AppRoutePaths.howto) return true;
  if (path == '${AppRoutePaths.profile}/howto') return true;
  if (path == AppRoutePaths.supportFaq) return true;
  return false;
}
