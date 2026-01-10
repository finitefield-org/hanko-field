// ignore_for_file: public_member_api_docs

import 'dart:ui';

import 'package:app/features/preferences/view_model/locale_selection_view_model.dart';
import 'package:app/features/users/data/repositories/local_user_repository.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_currency_provider.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileLocaleState {
  const ProfileLocaleState({
    required this.selectedLocale,
    required this.deviceLocale,
    required this.localeOptions,
    required this.currencyOverride,
    required this.resolvedCurrency,
    required this.isAuthenticated,
  });

  final Locale selectedLocale;
  final Locale deviceLocale;
  final List<LocaleOption> localeOptions;
  final String? currencyOverride;
  final String resolvedCurrency;
  final bool isAuthenticated;
}

class ProfileLocaleDraft {
  const ProfileLocaleDraft({
    required this.locale,
    required this.currencyOverride,
  });

  final Locale locale;
  final String? currencyOverride;
}

final _logger = Logger('ProfileLocaleViewModel');

class ProfileLocaleViewModel extends AsyncProvider<ProfileLocaleState> {
  ProfileLocaleViewModel() : super.args(null, autoDispose: true);

  late final saveMut = mutation<void>(#save);
  late final useDeviceMut = mutation<Locale>(#useDevice);

  @override
  Future<ProfileLocaleState> build(
    Ref<AsyncValue<ProfileLocaleState>> ref,
  ) async {
    await ref.watch(localePreferencesProvider.future);
    await ref.watch(currencyPreferencesProvider.future);
    final selectedLocale = ref.watch(appLocaleProvider);
    final deviceLocale = PlatformDispatcher.instance.locale;
    final currencyOverride = ref
        .watch(currencyPreferencesProvider)
        .valueOrNull
        ?.currencyCode;
    final session = ref.watch(userSessionProvider).valueOrNull;

    return ProfileLocaleState(
      selectedLocale: selectedLocale,
      deviceLocale: deviceLocale,
      localeOptions: localeOptionsFor(selectedLocale),
      currencyOverride: normalizeCurrency(currencyOverride),
      resolvedCurrency: resolveCurrency(currencyOverride, selectedLocale),
      isAuthenticated: session?.isAuthenticated == true,
    );
  }

  Call<void, AsyncValue<ProfileLocaleState>> save(ProfileLocaleDraft draft) =>
      mutate(saveMut, (ref) async {
        final localeService = ref.watch(appLocaleServiceProvider);
        final currencyService = ref.watch(appCurrencyServiceProvider);
        final resolvedLocale = await localeService.update(draft.locale);
        if (draft.currencyOverride == null) {
          await currencyService.clearOverride();
        } else {
          await currencyService.update(draft.currencyOverride!);
        }
        await _syncProfile(ref, resolvedLocale);
      }, concurrency: Concurrency.dropLatest);

  Call<Locale, AsyncValue<ProfileLocaleState>> useDeviceLocale() => mutate(
    useDeviceMut,
    (ref) async {
      final supported = AppLocalizations.supportedLocales;
      final deviceLocale = PlatformDispatcher.instance.locale;
      final resolved = AppLocalizations.resolveLocale(deviceLocale, supported);
      final localeService = ref.watch(appLocaleServiceProvider);
      await localeService.clearOverride();
      await _syncProfile(ref, resolved);
      return resolved;
    },
    concurrency: Concurrency.dropLatest,
  );

  Future<void> _syncProfile(
    Ref<AsyncValue<ProfileLocaleState>> ref,
    Locale locale,
  ) async {
    final repository = ref.watch(userRepositoryProvider);
    final session = ref.watch(userSessionProvider).valueOrNull;
    final profile = session?.profile;
    if (profile == null) {
      _logger.fine('User not authenticated; locale sync skipped');
      return;
    }

    try {
      await repository.updateProfile(
        profile.copyWith(preferredLang: locale.toLanguageTag()),
      );
      ref.invalidate(userSessionProvider);
    } catch (e, stack) {
      _logger.warning('Failed to sync locale preference', e, stack);
    }
  }
}

final profileLocaleViewModel = ProfileLocaleViewModel();
