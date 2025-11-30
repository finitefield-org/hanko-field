// ignore_for_file: public_member_api_docs

import 'dart:ui';

import 'package:app/core/storage/preferences.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appLocaleScope = Scope<Locale>.required('app.locale');

class LocalePreferences {
  const LocalePreferences({this.localeTag});

  final String? localeTag;

  static LocalePreferences fromPreferences(SharedPreferences prefs) {
    return LocalePreferences(localeTag: prefs.getString(_localePreferenceKey));
  }

  Future<void> persist(SharedPreferences prefs) async {
    if (localeTag == null || localeTag!.isEmpty) {
      await prefs.remove(_localePreferenceKey);
    } else {
      await prefs.setString(_localePreferenceKey, localeTag!);
    }
  }
}

final localePreferencesProvider = AsyncProvider<LocalePreferences>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return LocalePreferences.fromPreferences(prefs);
});

final appLocaleProvider = Provider<Locale>((ref) {
  try {
    return ref.scope(appLocaleScope);
  } on StateError {
    // Fall through to derived locale resolution.
  }

  final supported = AppLocalizations.supportedLocales;
  final deviceLocale = PlatformDispatcher.instance.locale;
  final stored = ref.watch(localePreferencesProvider).valueOrNull?.localeTag;
  final session = ref.watch(userSessionProvider).valueOrNull;
  final candidates = <String?>[
    stored,
    session?.profile?.preferredLang,
    deviceLocale.toLanguageTag(),
  ];

  for (final tag in candidates) {
    final resolved = _matchLocale(tag, supported);
    if (resolved != null) return resolved;
  }
  return supported.first;
});

final appLocaleServiceProvider = Provider<AppLocaleService>((ref) {
  final logger = Logger('AppLocaleService');
  return AppLocaleService(ref, logger);
});

class AppLocaleService {
  AppLocaleService(this._ref, this._logger);

  final Ref _ref;
  final Logger _logger;

  Future<Locale> update(Locale locale) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final supported = AppLocalizations.supportedLocales;
    final resolved =
        _matchLocale(locale.toLanguageTag(), supported) ?? supported.first;
    await LocalePreferences(localeTag: resolved.toLanguageTag()).persist(prefs);
    _ref.invalidate(localePreferencesProvider);
    _logger.info('Locale updated to ${resolved.toLanguageTag()}');
    return resolved;
  }

  Future<void> clearOverride() async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    await const LocalePreferences(localeTag: null).persist(prefs);
    _ref.invalidate(localePreferencesProvider);
    _logger.info('Locale override cleared');
  }
}

Locale? _matchLocale(String? tag, List<Locale> supported) {
  if (tag == null || tag.isEmpty) return null;
  final normalized = tag.toLowerCase().replaceAll('_', '-');
  final parts = normalized.split('-');
  final language = parts.first;
  final country = parts.length > 1 ? parts[1].toUpperCase() : null;

  return supported.firstWhereOrNull((locale) {
        if (locale.languageCode.toLowerCase() != language) return false;
        if (country == null) return true;
        final localeCountry = locale.countryCode?.toUpperCase();
        if (localeCountry == null) return false;
        return localeCountry == country;
      }) ??
      supported.firstWhereOrNull(
        (locale) => locale.languageCode.toLowerCase() == language,
      );
}

/// Widget tests can override the resolved locale with:
/// `ProviderScope(overrides: [appLocaleScope.overrideWithValue(const Locale('ja'))])`.

const _localePreferenceKey = 'app_locale_preference';
