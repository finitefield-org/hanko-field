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

  static const _rtlLanguages = <String>{
    'ar', // Arabic
    'fa', // Persian
    'he', // Hebrew
    'iw', // Hebrew (legacy)
    'ps', // Pashto
    'ur', // Urdu
    'dv', // Divehi
    'ku', // Kurdish
    'ug', // Uyghur
    'sd', // Sindhi
    'yi', // Yiddish
  };

  TextDirection _resolveTextDirection(Locale? locale) {
    final resolvedLocale =
        locale ?? WidgetsBinding.instance.platformDispatcher.locale;
    final isRtl = _rtlLanguages.contains(resolvedLocale.languageCode);
    return isRtl ? TextDirection.rtl : TextDirection.ltr;
  }

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
        return Directionality(
          textDirection: _resolveTextDirection(locale),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: AppMessageOverlay(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
