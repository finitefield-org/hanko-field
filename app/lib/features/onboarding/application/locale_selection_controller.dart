import 'dart:async';
import 'dart:ui';

import 'package:app/core/app_state/app_locale.dart';
import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class LocaleOption {
  const LocaleOption({
    required this.locale,
    required this.title,
    required this.subtitle,
    required this.sampleHeadline,
    required this.sampleBody,
  });

  final Locale locale;
  final String title;
  final String subtitle;
  final String sampleHeadline;
  final String sampleBody;

  String get languageTag => locale.toLanguageTag();
}

@immutable
class LocaleSelectionState {
  const LocaleSelectionState({
    required this.availableLocales,
    required this.initialLocale,
    required this.selectedLocale,
    required this.systemLocale,
    required this.initialSource,
    this.requiresPersistence = false,
    this.isSaving = false,
  });

  final List<LocaleOption> availableLocales;
  final Locale initialLocale;
  final Locale selectedLocale;
  final Locale systemLocale;
  final AppLocaleSource initialSource;
  final bool requiresPersistence;
  final bool isSaving;

  bool get hasPendingChanges =>
      requiresPersistence ||
      selectedLocale.toLanguageTag() != initialLocale.toLanguageTag();

  bool get isUsingSystemLocale =>
      !hasPendingChanges &&
      initialSource == AppLocaleSource.system &&
      initialLocale.toLanguageTag() == systemLocale.toLanguageTag();

  LocaleSelectionState copyWith({
    List<LocaleOption>? availableLocales,
    Locale? initialLocale,
    Locale? selectedLocale,
    Locale? systemLocale,
    AppLocaleSource? initialSource,
    bool? requiresPersistence,
    bool? isSaving,
  }) {
    return LocaleSelectionState(
      availableLocales: availableLocales ?? this.availableLocales,
      initialLocale: initialLocale ?? this.initialLocale,
      selectedLocale: selectedLocale ?? this.selectedLocale,
      systemLocale: systemLocale ?? this.systemLocale,
      initialSource: initialSource ?? this.initialSource,
      requiresPersistence: requiresPersistence ?? this.requiresPersistence,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class LocaleSelectionController extends AsyncNotifier<LocaleSelectionState> {
  static const List<LocaleOption> _supportedLocaleOptions = [
    LocaleOption(
      locale: Locale('ja', 'JP'),
      title: '日本語 (日本)',
      subtitle: '和文ガイド・円建て価格・国内配送を優先表示',
      sampleHeadline: 'こんにちは！',
      sampleBody: '日本語 UI で印鑑作りのステップを丁寧に案内します。',
    ),
    LocaleOption(
      locale: Locale('en', 'US'),
      title: 'English (Global)',
      subtitle: 'English guidance, romanization tips, USD-equivalent pricing',
      sampleHeadline: 'Welcome!',
      sampleBody: 'We’ll guide you through crafting your personal hanko.',
    ),
  ];

  @override
  Future<LocaleSelectionState> build() async {
    final localeState = await ref.watch(appLocaleProvider.future);
    final systemLocale = localeState.systemLocale;
    final initialLocale = _coerceToSupported(localeState.locale);
    final selectedLocale = initialLocale;
    final coercedFromSystem =
        localeState.source == AppLocaleSource.system &&
        initialLocale.toLanguageTag() != systemLocale.toLanguageTag();

    return LocaleSelectionState(
      availableLocales: _supportedLocaleOptions,
      initialLocale: initialLocale,
      selectedLocale: selectedLocale,
      systemLocale: systemLocale,
      initialSource: localeState.source,
      requiresPersistence: coercedFromSystem,
    );
  }

  void selectLocale(Locale locale) {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }
    final coerced = _coerceToSupported(locale);
    if (current.selectedLocale.toLanguageTag() == coerced.toLanguageTag()) {
      return;
    }
    state = AsyncData(
      current.copyWith(selectedLocale: coerced, requiresPersistence: false),
    );
  }

  Future<void> saveSelection({bool force = false}) async {
    final current = state.asData?.value ?? await future;
    if (current.isSaving) {
      return;
    }
    final shouldUpdateLocale = current.hasPendingChanges;
    if (!shouldUpdateLocale && !force) {
      return;
    }

    state = AsyncData(current.copyWith(isSaving: true));
    try {
      if (shouldUpdateLocale) {
        await ref
            .read(appLocaleProvider.notifier)
            .setLocale(current.selectedLocale);
      }
      await _syncRemoteLanguage(current.selectedLocale);
      await _markLocaleOnboardingComplete();

      if (!ref.mounted) {
        return;
      }
      final nextInitialLocale = shouldUpdateLocale
          ? current.selectedLocale
          : current.initialLocale;
      final nextSource = shouldUpdateLocale
          ? AppLocaleSource.user
          : current.initialSource;
      state = AsyncData(
        current.copyWith(
          initialLocale: nextInitialLocale,
          initialSource: nextSource,
          selectedLocale: current.selectedLocale,
          requiresPersistence: false,
          isSaving: false,
        ),
      );
    } catch (error) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isSaving: false));
      }
      rethrow;
    }
  }

  Future<void> saveUsingSystemLocale() async {
    final current = state.asData?.value ?? await future;
    if (current.isSaving) {
      return;
    }

    state = AsyncData(
      current.copyWith(isSaving: true, selectedLocale: current.systemLocale),
    );

    try {
      await ref.read(appLocaleProvider.notifier).useSystemLocale();
      await _syncRemoteLanguage(current.systemLocale);
      await _markLocaleOnboardingComplete();

      if (!ref.mounted) {
        return;
      }
      final normalizedSystem = _coerceToSupported(current.systemLocale);
      state = AsyncData(
        current.copyWith(
          initialLocale: normalizedSystem,
          selectedLocale: normalizedSystem,
          initialSource: AppLocaleSource.system,
          requiresPersistence: false,
          isSaving: false,
        ),
      );
    } catch (error) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isSaving: false));
      }
      rethrow;
    }
  }

  Locale _coerceToSupported(Locale locale) {
    return _supportedLocaleOptions
        .map((option) => option.locale)
        .firstWhere(
          (candidate) =>
              candidate.languageCode.toLowerCase() ==
              locale.languageCode.toLowerCase(),
          orElse: () => _supportedLocaleOptions.first.locale,
        );
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

  Future<void> _markLocaleOnboardingComplete() async {
    final dataSource = await ref.read(onboardingLocalDataSourceProvider.future);
    await dataSource.updateStep(OnboardingStep.locale);
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

final localeSelectionControllerProvider =
    AsyncNotifierProvider<LocaleSelectionController, LocaleSelectionState>(
      LocaleSelectionController.new,
    );
