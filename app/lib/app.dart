// ignore_for_file: public_member_api_docs

import 'package:app/config/app_flavor.dart';
import 'package:app/core/routing/app_router.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:miniriverpod/miniriverpod.dart';

class HankoFieldApp extends ConsumerWidget {
  const HankoFieldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(appFlavorProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeBundle = ref.watch(themeBundleProvider);
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: flavor.displayLabel,
      theme: themeBundle.light,
      darkTheme: themeBundle.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: AppLocalizations.resolveLocale,
      routerConfig: router,
      builder: (context, child) {
        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: AppMessageOverlay(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
