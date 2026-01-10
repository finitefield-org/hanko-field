import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/network/network_providers.dart';
import 'package:app/core/routing/app_router.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/catalog/view_model/shop_home_providers.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/home/view_model/home_providers.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/shared/providers/app_persona_provider.dart';
import 'package:app/shared/providers/app_update_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:miniriverpod/miniriverpod.dart';

class NoopAnalyticsClient implements AnalyticsClient {
  @override
  Future<void> track(AppAnalyticsEvent event) async {}
}

class FakeConnectivity implements Connectivity {
  FakeConnectivity({ConnectivityResult initial = ConnectivityResult.wifi})
    : _current = [initial];

  final StreamController<List<ConnectivityResult>> _controller =
      StreamController.broadcast();
  List<ConnectivityResult> _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  void emit(ConnectivityResult result) {
    _current = [result];
    _controller.add(_current);
  }

  void dispose() {
    _controller.close();
  }
}

List<Override> buildTestOverrides({
  Locale locale = const Locale('en'),
  UserPersona persona = UserPersona.foreigner,
  UserSession session = const UserSession.signedOut(),
  AnalyticsClient? analytics,
}) {
  final homeFeaturedOverride = Provider<AsyncValue<List<HomeFeaturedItem>>>(
    (_) => const AsyncData<List<HomeFeaturedItem>>([]),
  );
  final homeRecentDesignsOverride = Provider<AsyncValue<List<Design>>>(
    (_) => const AsyncData<List<Design>>([]),
  );
  final homeRecommendedTemplatesOverride =
      Provider<AsyncValue<List<RecommendedTemplate>>>(
        (_) => const AsyncData<List<RecommendedTemplate>>([]),
      );
  final shopCategoriesOverride = Provider<AsyncValue<List<ShopCategory>>>(
    (_) => const AsyncData<List<ShopCategory>>([]),
  );
  final shopPromotionsOverride =
      Provider<AsyncValue<List<ShopPromotionHighlight>>>(
        (_) => const AsyncData<List<ShopPromotionHighlight>>([]),
      );
  final shopMaterialRecommendationsOverride =
      Provider<AsyncValue<List<ShopMaterialHighlight>>>(
        (_) => const AsyncData<List<ShopMaterialHighlight>>([]),
      );
  final shopGuideLinksOverride = Provider<AsyncValue<List<ShopGuideLink>>>(
    (_) => const AsyncData<List<ShopGuideLink>>([]),
  );
  final unreadOverride = Provider<AsyncValue<int>>(
    (_) => const AsyncData<int>(0),
  );
  final fakeConnectivity = FakeConnectivity();
  const updateOverride = AsyncData<AppUpdateStatus>(
    AppUpdateStatus(
      currentVersion: '1.0.0',
      minSupportedVersion: '1.0.0',
      latestVersion: '1.0.0',
      isUpdateRequired: false,
      isUpdateRecommended: false,
      storePrimaryUrl: null,
      storeFallbackUrl: null,
    ),
  );
  return [
    appLocaleScope.overrideWithValue(locale),
    appPersonaScope.overrideWithValue(persona),
    userSessionScope.overrideWithValue(session),
    analyticsClientProvider.overrideWithValue(
      analytics ?? NoopAnalyticsClient(),
    ),
    unreadNotificationsProvider.overrideWith(unreadOverride),
    connectivityProvider.overrideWithValue(fakeConnectivity),
    homeFeaturedProvider.overrideWith(homeFeaturedOverride),
    homeRecentDesignsProvider.overrideWith(homeRecentDesignsOverride),
    homeRecommendedTemplatesProvider.overrideWith(
      homeRecommendedTemplatesOverride,
    ),
    shopCategoriesProvider.overrideWith(shopCategoriesOverride),
    shopPromotionsProvider.overrideWith(shopPromotionsOverride),
    shopMaterialRecommendationsProvider.overrideWith(
      shopMaterialRecommendationsOverride,
    ),
    shopGuideLinksProvider.overrideWith(shopGuideLinksOverride),
    appUpdateStatusProvider.overrideWithValue(updateOverride),
  ];
}

Widget buildTestApp({
  required Widget child,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: _TestApp(locale: locale, child: child),
  );
}

Widget buildTestNavApp({
  String initialLocation = AppRoutePaths.home,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: _TestNavApp(locale: locale, initialLocation: initialLocation),
  );
}

class _TestApp extends ConsumerWidget {
  const _TestApp({required this.child, required this.locale});

  final Widget child;
  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationController = ref.watch(navigationControllerProvider);

    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        extensions: [DesignTokensTheme(tokens: DesignTokens.light())],
      ),
      home: NavigationControllerScope(
        controller: navigationController,
        child: child,
      ),
    );
  }
}

class _TestNavApp extends ConsumerStatefulWidget {
  const _TestNavApp({required this.locale, required this.initialLocation});

  final Locale locale;
  final String initialLocation;

  @override
  ConsumerState<_TestNavApp> createState() => _TestNavAppState();
}

class _TestNavAppState extends ConsumerState<_TestNavApp> {
  bool _didInitRoute = false;

  @override
  Widget build(BuildContext context) {
    if (!_didInitRoute) {
      _didInitRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invoke(appNavigationProvider.go(widget.initialLocation));
      });
    }
    final navigationController = ref.watch(navigationControllerProvider);

    return MaterialApp(
      locale: widget.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        extensions: [DesignTokensTheme(tokens: DesignTokens.light())],
      ),
      home: NavigationControllerScope(
        controller: navigationController,
        child: const AppNavigationRoot(),
      ),
    );
  }
}
