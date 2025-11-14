import 'dart:async';
import 'dart:ui';

import 'package:app/core/app_state/app_locale.dart';
import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/preferences/pref_keys.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:app/shared/locale/locale_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfileLocaleState {
  const ProfileLocaleState({
    required this.availableLocales,
    required this.availableCurrencies,
    required this.savedLocale,
    required this.selectedLocale,
    required this.systemLocale,
    required this.localeSource,
    required this.savedCurrencyOverride,
    required this.selectedCurrencyCode,
    this.isSaving = false,
    this.lastSavedAt,
  });

  final List<LocaleOption> availableLocales;
  final List<String> availableCurrencies;
  final Locale savedLocale;
  final Locale selectedLocale;
  final Locale systemLocale;
  final AppLocaleSource localeSource;
  final String? savedCurrencyOverride;
  final String selectedCurrencyCode;
  final bool isSaving;
  final DateTime? lastSavedAt;

  String get savedLocaleTag => savedLocale.toLanguageTag();
  String get selectedLocaleTag => selectedLocale.toLanguageTag();
  String get recommendedCurrencyForSelection =>
      _recommendedCurrencyForLocale(selectedLocale);

  String get recommendedCurrencyForSaved =>
      _recommendedCurrencyForLocale(savedLocale);

  String get effectiveSavedCurrency =>
      savedCurrencyOverride ?? recommendedCurrencyForSaved;

  bool get hasLocaleChanges => savedLocaleTag != selectedLocaleTag;

  bool get hasCurrencyChanges =>
      selectedCurrencyCode.toUpperCase() !=
      effectiveSavedCurrency.toUpperCase();

  bool get hasChanges => hasLocaleChanges || hasCurrencyChanges;

  bool get isUsingSystemLocale =>
      localeSource == AppLocaleSource.system &&
      savedLocaleTag == systemLocale.toLanguageTag();

  ProfileLocaleState copyWith({
    List<LocaleOption>? availableLocales,
    List<String>? availableCurrencies,
    Locale? savedLocale,
    Locale? selectedLocale,
    Locale? systemLocale,
    AppLocaleSource? localeSource,
    String? savedCurrencyOverride,
    String? selectedCurrencyCode,
    bool? isSaving,
    DateTime? lastSavedAt,
  }) {
    return ProfileLocaleState(
      availableLocales: availableLocales ?? this.availableLocales,
      availableCurrencies: availableCurrencies ?? this.availableCurrencies,
      savedLocale: savedLocale ?? this.savedLocale,
      selectedLocale: selectedLocale ?? this.selectedLocale,
      systemLocale: systemLocale ?? this.systemLocale,
      localeSource: localeSource ?? this.localeSource,
      savedCurrencyOverride:
          savedCurrencyOverride ?? this.savedCurrencyOverride,
      selectedCurrencyCode: selectedCurrencyCode ?? this.selectedCurrencyCode,
      isSaving: isSaving ?? this.isSaving,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }
}

class ProfileLocaleController extends AsyncNotifier<ProfileLocaleState> {
  static const List<String> _supportedCurrencyCodes = ['JPY', 'USD'];

  @override
  Future<ProfileLocaleState> build() async {
    final localeState = await ref.watch(appLocaleProvider.future);
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final savedLocale = _coerceToSupported(localeState.locale);
    final selectedLocale = savedLocale;
    final savedOverride = _normalizeCurrencyCode(
      prefs.getString(prefKeyCurrencyOverride),
    );
    final initialCurrency =
        savedOverride ?? _recommendedCurrencyForLocale(savedLocale);

    return ProfileLocaleState(
      availableLocales: kSupportedLocaleOptions,
      availableCurrencies: _supportedCurrencyCodes,
      savedLocale: savedLocale,
      selectedLocale: selectedLocale,
      systemLocale: localeState.systemLocale,
      localeSource: localeState.source,
      savedCurrencyOverride: savedOverride,
      selectedCurrencyCode: initialCurrency,
    );
  }

  void selectLocale(Locale locale) {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }
    final coerced = _coerceToSupported(locale);
    if (coerced.toLanguageTag() == current.selectedLocaleTag) {
      return;
    }
    state = AsyncData(current.copyWith(selectedLocale: coerced));
  }

  void selectCurrency(String code) {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }
    final normalized = _normalizeCurrencyCode(code);
    if (normalized == null || normalized == current.selectedCurrencyCode) {
      return;
    }
    state = AsyncData(current.copyWith(selectedCurrencyCode: normalized));
  }

  Future<void> saveChanges() async {
    final current = state.asData?.value ?? await future;
    if (current.isSaving || !current.hasChanges) {
      return;
    }
    final localeChanged = current.hasLocaleChanges;
    final currencyChanged = current.hasCurrencyChanges;
    final shouldUpdateCurrency = currencyChanged || localeChanged;

    state = AsyncData(current.copyWith(isSaving: true));
    try {
      if (localeChanged) {
        await ref
            .read(appLocaleProvider.notifier)
            .setLocale(current.selectedLocale);
        await _syncRemoteLanguage(current.selectedLocale);
      }
      if (shouldUpdateCurrency) {
        await _persistCurrencyOverride(
          selected: current.selectedCurrencyCode,
          recommended: current.recommendedCurrencyForSelection,
        );
      }
      if (!ref.mounted) {
        return;
      }
      final nextOverride =
          _shouldPersistOverride(
            desired: current.selectedCurrencyCode,
            recommended: current.recommendedCurrencyForSelection,
          )
          ? current.selectedCurrencyCode
          : null;
      final nextSelectedCurrency =
          nextOverride ?? _recommendedCurrencyForLocale(current.selectedLocale);
      state = AsyncData(
        current.copyWith(
          savedLocale: current.selectedLocale,
          localeSource: AppLocaleSource.user,
          savedCurrencyOverride: nextOverride,
          selectedCurrencyCode: nextSelectedCurrency,
          isSaving: false,
          lastSavedAt: DateTime.now(),
        ),
      );
      ref.invalidate(experienceGateProvider);
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isSaving: false));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> saveUsingSystemLocale() async {
    final current = state.asData?.value ?? await future;
    if (current.isSaving) {
      return;
    }
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      await ref.read(appLocaleProvider.notifier).useSystemLocale();
      await _syncRemoteLanguage(current.systemLocale);
      if (!ref.mounted) {
        return;
      }
      final normalizedSystem = _coerceToSupported(current.systemLocale);
      final effectiveCurrency =
          current.savedCurrencyOverride ??
          _recommendedCurrencyForLocale(normalizedSystem);
      state = AsyncData(
        current.copyWith(
          savedLocale: normalizedSystem,
          selectedLocale: normalizedSystem,
          localeSource: AppLocaleSource.system,
          selectedCurrencyCode: effectiveCurrency,
          isSaving: false,
          lastSavedAt: DateTime.now(),
        ),
      );
      ref.invalidate(experienceGateProvider);
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isSaving: false));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Locale _coerceToSupported(Locale locale) {
    return kSupportedLocaleOptions
        .map((option) => option.locale)
        .firstWhere(
          (candidate) =>
              candidate.languageCode.toLowerCase() ==
              locale.languageCode.toLowerCase(),
          orElse: () => kSupportedLocaleOptions.first.locale,
        );
  }

  Future<void> _persistCurrencyOverride({
    required String selected,
    required String recommended,
  }) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final normalizedSelected = _normalizeCurrencyCode(selected) ?? recommended;
    final normalizedRecommended = recommended.toUpperCase();
    if (normalizedSelected == normalizedRecommended) {
      await prefs.remove(prefKeyCurrencyOverride);
    } else {
      await prefs.setString(prefKeyCurrencyOverride, normalizedSelected);
    }
  }

  bool _shouldPersistOverride({
    required String desired,
    required String recommended,
  }) {
    final normalizedDesired = desired.toUpperCase();
    final normalizedRecommended = recommended.toUpperCase();
    return normalizedDesired != normalizedRecommended;
  }

  Future<void> _syncRemoteLanguage(Locale locale) async {
    final session = await ref.read(userSessionProvider.future);
    if (session.status != UserSessionStatus.authenticated) {
      return;
    }
    final profile = session.profile;
    if (profile == null) {
      return;
    }
    final language = _mapLocaleToUserLanguage(locale);
    if (profile.preferredLanguage == language) {
      return;
    }
    final repository = ref.read(userRepositoryProvider);
    final updatedProfile = profile.copyWith(preferredLanguage: language);
    await repository.updateProfile(updatedProfile);
    if (ref.mounted) {
      unawaited(ref.read(userSessionProvider.notifier).refreshProfile());
    }
  }

  UserLanguage _mapLocaleToUserLanguage(Locale locale) {
    switch (locale.languageCode.toLowerCase()) {
      case 'ja':
        return UserLanguage.ja;
      case 'en':
      default:
        return UserLanguage.en;
    }
  }
}

final profileLocaleControllerProvider =
    AsyncNotifierProvider<ProfileLocaleController, ProfileLocaleState>(
      ProfileLocaleController.new,
    );

String _recommendedCurrencyForLocale(Locale locale) {
  if (locale.countryCode?.toUpperCase() == 'JP') {
    return 'JPY';
  }
  return 'USD';
}

String? _normalizeCurrencyCode(String? code) {
  if (code == null) {
    return null;
  }
  final normalized = code.toUpperCase();
  return ProfileLocaleController._supportedCurrencyCodes.contains(normalized)
      ? normalized
      : null;
}
