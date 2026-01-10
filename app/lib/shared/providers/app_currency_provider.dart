// ignore_for_file: public_member_api_docs

import 'dart:ui';

import 'package:app/core/storage/preferences.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appCurrencyScope = Scope<String>.required('app.currency');

const supportedCurrencyCodes = ['JPY', 'USD'];

class CurrencyPreferences {
  const CurrencyPreferences({this.currencyCode});

  final String? currencyCode;

  static CurrencyPreferences fromPreferences(SharedPreferences prefs) {
    return CurrencyPreferences(
      currencyCode: prefs.getString(_currencyPreferenceKey),
    );
  }

  Future<void> persist(SharedPreferences prefs) async {
    if (currencyCode == null || currencyCode!.isEmpty) {
      await prefs.remove(_currencyPreferenceKey);
    } else {
      await prefs.setString(_currencyPreferenceKey, currencyCode!);
    }
  }
}

final currencyPreferencesProvider = AsyncProvider<CurrencyPreferences>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return CurrencyPreferences.fromPreferences(prefs);
});

final appCurrencyProvider = Provider<String>((ref) {
  try {
    return ref.scope(appCurrencyScope);
  } on StateError {
    // Fall through to derived currency resolution.
  }

  final locale = ref.watch(appLocaleProvider);
  final stored = ref
      .watch(currencyPreferencesProvider)
      .valueOrNull
      ?.currencyCode;
  return resolveCurrency(stored, locale);
});

final appCurrencyServiceProvider = Provider<AppCurrencyService>((ref) {
  final logger = Logger('AppCurrencyService');
  return AppCurrencyService(ref, logger);
});

class AppCurrencyService {
  AppCurrencyService(this._ref, this._logger);

  final Ref<AppCurrencyService> _ref;
  final Logger _logger;

  Future<String> update(String currencyCode) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final normalized = normalizeCurrency(currencyCode);
    if (normalized == null) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'Unsupported currency',
      );
    }
    await CurrencyPreferences(currencyCode: normalized).persist(prefs);
    _ref.invalidate(currencyPreferencesProvider);
    _logger.info('Currency updated to $normalized');
    return normalized;
  }

  Future<void> clearOverride() async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    await const CurrencyPreferences(currencyCode: null).persist(prefs);
    _ref.invalidate(currencyPreferencesProvider);
    _logger.info('Currency override cleared');
  }
}

String? normalizeCurrency(String? code) {
  if (code == null || code.isEmpty) return null;
  final upper = code.toUpperCase();
  return supportedCurrencyCodes.firstWhereOrNull((value) => value == upper);
}

String resolveCurrency(String? override, Locale locale) {
  final normalized = normalizeCurrency(override);
  if (normalized != null) return normalized;
  return _currencyForLocale(locale);
}

String _currencyForLocale(Locale locale) {
  final language = locale.languageCode.toLowerCase();
  final country = locale.countryCode?.toUpperCase();
  if (language == 'ja' || country == 'JP') return 'JPY';
  return 'USD';
}

const _currencyPreferenceKey = 'app_currency_preference';
