// ignore_for_file: public_member_api_docs

import 'dart:ui';

import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/shared/providers/app_persona_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum RegionSource { profile, locale, device, fallback }

class AppExperienceGates {
  const AppExperienceGates({
    required this.locale,
    required this.regionCode,
    required this.regionSource,
    required this.persona,
    required this.isAuthenticated,
    required this.isGuest,
  });

  final Locale locale;
  final String regionCode;
  final RegionSource regionSource;
  final UserPersona persona;
  final bool isAuthenticated;
  final bool isGuest;

  bool get prefersJapanese =>
      locale.languageCode.toLowerCase() == 'ja' || regionCode == 'JP';

  bool get prefersEnglish => locale.languageCode.toLowerCase() == 'en';

  bool get isJapanRegion => regionCode == 'JP';

  bool get enableKanjiAssist => persona == UserPersona.foreigner;

  bool get enableRegistrabilityCheck =>
      persona == UserPersona.japanese && isJapanRegion;

  bool get emphasizeInternationalFlows =>
      persona == UserPersona.foreigner || !isJapanRegion;

  String get localeTag => locale.toLanguageTag();

  String get personaKey => persona.toJson();
}

final appExperienceGatesProvider = Provider<AppExperienceGates>((ref) {
  final locale = ref.watch(appLocaleProvider);
  final persona = ref.watch(appPersonaProvider);
  final session = ref.watch(userSessionProvider).valueOrNull;
  final resolvedRegion = _resolveRegion(locale, session);

  return AppExperienceGates(
    locale: locale,
    regionCode: resolvedRegion.code,
    regionSource: resolvedRegion.source,
    persona: persona,
    isAuthenticated: session?.isAuthenticated == true,
    isGuest: session?.user?.isAnonymous == true,
  );
});

_ResolvedRegion _resolveRegion(Locale locale, UserSession? session) {
  final profileCountry = _normalizeCountry(session?.profile?.country);
  if (profileCountry != null) {
    return _ResolvedRegion(profileCountry, RegionSource.profile);
  }

  final localeCountry = _normalizeCountry(locale.countryCode);
  if (localeCountry != null) {
    return _ResolvedRegion(localeCountry, RegionSource.locale);
  }

  final deviceCountry = _normalizeCountry(
    PlatformDispatcher.instance.locale.countryCode,
  );
  if (deviceCountry != null) {
    return _ResolvedRegion(deviceCountry, RegionSource.device);
  }

  return const _ResolvedRegion('INTL', RegionSource.fallback);
}

String? _normalizeCountry(String? code) {
  final trimmed = code?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.toUpperCase();
}

class _ResolvedRegion {
  const _ResolvedRegion(this.code, this.source);

  final String code;
  final RegionSource source;
}
