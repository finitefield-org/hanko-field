import 'package:app/analytics/analytics.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/shared/providers/app_persona_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class NoopAnalyticsClient implements AnalyticsClient {
  @override
  Future<void> track(AppAnalyticsEvent event) async {}
}

List<Override> buildTestOverrides({
  Locale locale = const Locale('en'),
  UserPersona persona = UserPersona.foreigner,
  UserSession session = const UserSession.signedOut(),
  AnalyticsClient? analytics,
}) {
  final unreadOverride = Provider<AsyncValue<int>>(
    (_) => const AsyncData<int>(0),
  );
  return [
    appLocaleScope.overrideWithValue(locale),
    appPersonaScope.overrideWithValue(persona),
    userSessionScope.overrideWithValue(session),
    analyticsClientProvider.overrideWithValue(
      analytics ?? NoopAnalyticsClient(),
    ),
    unreadNotificationsProvider.overrideWith(unreadOverride),
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

Widget buildTestRouterApp({
  required GoRouter router,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: _TestRouterApp(locale: locale, router: router),
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, required this.locale});

  final Widget child;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
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
      home: child,
    );
  }
}

class _TestRouterApp extends StatelessWidget {
  const _TestRouterApp({required this.router, required this.locale});

  final GoRouter router;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
      routerConfig: router,
    );
  }
}
