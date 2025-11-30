// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/storage/preferences.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  const OnboardingPreferences({
    required this.onboardingCompleted,
    required this.localeSelected,
    required this.personaSelected,
    required this.onboardingVersion,
    this.offlineCacheSeededAt,
  });

  final bool onboardingCompleted;
  final bool localeSelected;
  final bool personaSelected;
  final int onboardingVersion;
  final DateTime? offlineCacheSeededAt;

  static const currentVersion = 1;

  static const defaults = OnboardingPreferences(
    onboardingCompleted: false,
    localeSelected: false,
    personaSelected: false,
    onboardingVersion: currentVersion,
    offlineCacheSeededAt: null,
  );

  OnboardingPreferences copyWith({
    bool? onboardingCompleted,
    bool? localeSelected,
    bool? personaSelected,
    int? onboardingVersion,
    DateTime? offlineCacheSeededAt,
  }) {
    return OnboardingPreferences(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      localeSelected: localeSelected ?? this.localeSelected,
      personaSelected: personaSelected ?? this.personaSelected,
      onboardingVersion: onboardingVersion ?? this.onboardingVersion,
      offlineCacheSeededAt: offlineCacheSeededAt ?? this.offlineCacheSeededAt,
    );
  }

  static OnboardingPreferences fromPreferences(SharedPreferences prefs) {
    final savedVersion = prefs.getInt(_onboardingVersionKey);
    final staleVersion = savedVersion != null && savedVersion < currentVersion;

    if (staleVersion) {
      return defaults;
    }

    return OnboardingPreferences(
      onboardingCompleted:
          prefs.getBool(_completedKey) ?? defaults.onboardingCompleted,
      localeSelected:
          prefs.getBool(_localeSelectedKey) ?? defaults.localeSelected,
      personaSelected:
          prefs.getBool(_personaSelectedKey) ?? defaults.personaSelected,
      onboardingVersion: savedVersion ?? currentVersion,
      offlineCacheSeededAt: _parseDate(prefs.getString(_offlineCacheSeededKey)),
    );
  }

  Future<void> persist(SharedPreferences prefs) async {
    await Future.wait([
      prefs.setBool(_completedKey, onboardingCompleted),
      prefs.setBool(_localeSelectedKey, localeSelected),
      prefs.setBool(_personaSelectedKey, personaSelected),
      prefs.setInt(_onboardingVersionKey, onboardingVersion),
      if (offlineCacheSeededAt != null)
        prefs.setString(
          _offlineCacheSeededKey,
          offlineCacheSeededAt!.toIso8601String(),
        )
      else
        prefs.remove(_offlineCacheSeededKey),
    ]);
  }
}

final onboardingPreferencesProvider = AsyncProvider<OnboardingPreferences>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return OnboardingPreferences.fromPreferences(prefs);
});

final onboardingPreferencesServiceProvider =
    Provider<OnboardingPreferencesService>((ref) {
      final logger = Logger('OnboardingPreferencesService');
      return OnboardingPreferencesService(ref, logger);
    });

class OnboardingPreferencesService {
  OnboardingPreferencesService(this._ref, this._logger);

  final Ref _ref;
  final Logger _logger;

  Future<OnboardingPreferences> update({
    bool? onboardingCompleted,
    bool? localeSelected,
    bool? personaSelected,
    int? onboardingVersion,
    DateTime? offlineCacheSeededAt,
  }) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final current = OnboardingPreferences.fromPreferences(prefs);
    final next = current.copyWith(
      onboardingCompleted: onboardingCompleted,
      localeSelected: localeSelected,
      personaSelected: personaSelected,
      onboardingVersion: onboardingVersion,
      offlineCacheSeededAt: offlineCacheSeededAt,
    );

    await next.persist(prefs);
    _ref.invalidate(onboardingPreferencesProvider);

    _logger.info(
      'Onboarding preferences updated '
      '(completed=${next.onboardingCompleted}, '
      'locale=${next.localeSelected}, persona=${next.personaSelected}, '
      'version=${next.onboardingVersion})',
    );

    return next;
  }

  Future<OnboardingPreferences> markOnboardingComplete({
    int version = OnboardingPreferences.currentVersion,
  }) {
    return update(onboardingCompleted: true, onboardingVersion: version);
  }

  Future<OnboardingPreferences> recordOfflineCacheSeeded({DateTime? at}) {
    final timestamp = at ?? DateTime.now().toUtc();
    return update(offlineCacheSeededAt: timestamp);
  }
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  return DateTime.tryParse(value);
}

const _completedKey = 'onboarding_completed';
const _localeSelectedKey = 'onboarding_locale_selected';
const _personaSelectedKey = 'onboarding_persona_selected';
const _onboardingVersionKey = 'onboarding_version';
const _offlineCacheSeededKey = 'offline_cache_seeded_at';
