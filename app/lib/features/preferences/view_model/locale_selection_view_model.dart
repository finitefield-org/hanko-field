// ignore_for_file: public_member_api_docs

import 'dart:ui';

import 'package:app/core/storage/onboarding_preferences.dart';
import 'package:app/features/users/data/repositories/local_user_repository.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class LocaleOption {
  const LocaleOption({
    required this.locale,
    required this.title,
    required this.subtitle,
    required this.sample,
  });

  final Locale locale;
  final String title;
  final String subtitle;
  final String sample;
}

class LocaleSelectionState {
  const LocaleSelectionState({
    required this.selected,
    required this.deviceLocale,
    required this.options,
    required this.isAuthenticated,
  });

  final Locale selected;
  final Locale deviceLocale;
  final List<LocaleOption> options;
  final bool isAuthenticated;
}

final _localeLogger = Logger('LocaleSelectionViewModel');

class LocaleSelectionViewModel extends AsyncProvider<LocaleSelectionState> {
  LocaleSelectionViewModel() : super.args(null, autoDispose: true);

  late final saveMut = mutation<Locale>(#save);
  late final useDeviceMut = mutation<Locale>(#useDevice);

  @override
  Future<LocaleSelectionState> build(Ref ref) async {
    await ref.watch(localePreferencesProvider.future);
    final selected = ref.watch(appLocaleProvider);
    final deviceLocale = PlatformDispatcher.instance.locale;
    final session = ref.watch(userSessionProvider).valueOrNull;

    return LocaleSelectionState(
      selected: selected,
      deviceLocale: deviceLocale,
      options: localeOptionsFor(selected),
      isAuthenticated: session?.isAuthenticated == true,
    );
  }

  Call<Locale> save(Locale locale) => mutate(saveMut, (ref) async {
    final localeService = ref.watch(appLocaleServiceProvider);
    final onboarding = ref.watch(onboardingPreferencesServiceProvider);
    final resolved = await localeService.update(locale);
    await onboarding.update(localeSelected: true);
    await _syncProfile(ref, resolved);
    return resolved;
  }, concurrency: Concurrency.dropLatest);

  Call<Locale> useDeviceLocale() => mutate(useDeviceMut, (ref) async {
    final onboarding = ref.watch(onboardingPreferencesServiceProvider);
    final supported = AppLocalizations.supportedLocales;
    final deviceLocale = PlatformDispatcher.instance.locale;
    final resolved = AppLocalizations.resolveLocale(deviceLocale, supported);

    final localeService = ref.watch(appLocaleServiceProvider);
    await localeService.clearOverride();
    await onboarding.update(localeSelected: true);
    await _syncProfile(ref, resolved);
    return resolved;
  }, concurrency: Concurrency.dropLatest);

  Future<void> _syncProfile(Ref ref, Locale locale) async {
    final repository = ref.watch(userRepositoryProvider);
    final session = ref.watch(userSessionProvider).valueOrNull;
    final profile = session?.profile;
    if (profile == null) {
      _localeLogger.fine('User not authenticated; locale sync skipped');
      return;
    }

    try {
      await repository.updateProfile(
        profile.copyWith(preferredLang: locale.toLanguageTag()),
      );
      ref.invalidate(userSessionProvider);
    } catch (e, stack) {
      _localeLogger.warning('Failed to sync locale preference', e, stack);
    }
  }
}

List<LocaleOption> localeOptionsFor(Locale selected) {
  final preferJapanese = selected.languageCode == 'ja';
  final options = [
    const LocaleOption(
      locale: Locale('ja'),
      title: '日本語 (日本)',
      subtitle: '国内向けの表記・配送案内、実印チェックを日本語で表示します。',
      sample: '例: 漢字/かな入力補助、材質別のおすすめ、国内配送の案内。',
    ),
    const LocaleOption(
      locale: Locale('zh'),
      title: '简体中文 (中国)',
      subtitle: '提供简体中文界面、国际配送说明与汉字辅助功能。',
      sample: '示例：制作印章、预览汉字、支持海外配送。',
    ),
    const LocaleOption(
      locale: Locale('en'),
      title: 'English (International)',
      subtitle: 'Ordering guidance, international shipping, and kanji helpers.',
      sample: 'Sample: Make a seal, preview kanji, and ship worldwide.',
    ),
  ];

  if (preferJapanese) return options;
  return options.sorted((a, b) {
    if (a.locale == selected) return -1;
    if (b.locale == selected) return 1;
    return a.title.compareTo(b.title);
  });
}

final localeSelectionViewModel = LocaleSelectionViewModel();
