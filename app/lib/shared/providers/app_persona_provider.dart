// ignore_for_file: public_member_api_docs

import 'package:app/core/storage/preferences.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appPersonaScope = Scope<UserPersona>.required('app.persona');

class PersonaPreferences {
  const PersonaPreferences({this.persona});

  final UserPersona? persona;

  static PersonaPreferences fromPreferences(SharedPreferences prefs) {
    final value = prefs.getString(_personaPreferenceKey);
    final persona = value != null ? UserPersonaX.fromJson(value) : null;
    return PersonaPreferences(persona: persona);
  }

  Future<void> persist(SharedPreferences prefs) async {
    if (persona == null) {
      await prefs.remove(_personaPreferenceKey);
    } else {
      await prefs.setString(_personaPreferenceKey, persona!.toJson());
    }
  }
}

final personaPreferencesProvider = AsyncProvider<PersonaPreferences>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return PersonaPreferences.fromPreferences(prefs);
});

final appPersonaProvider = Provider<UserPersona>((ref) {
  try {
    return ref.scope(appPersonaScope);
  } on StateError {
    // Fall through to derived persona resolution.
  }

  ref.watch(personaPreferencesProvider);
  final locale = ref.watch(appLocaleProvider);
  final stored = ref.watch(personaPreferencesProvider).valueOrNull?.persona;
  final session = ref.watch(userSessionProvider).valueOrNull;
  final profilePersona = session?.profile?.persona;

  return stored ?? profilePersona ?? _personaForLocale(locale.languageCode);
});

final appPersonaServiceProvider = Provider<AppPersonaService>(
  (ref) => AppPersonaService(ref),
);

class AppPersonaService {
  AppPersonaService(this._ref) : _logger = Logger('AppPersonaService');

  final Ref _ref;
  final Logger _logger;

  Future<UserPersona> update(UserPersona persona) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    await PersonaPreferences(persona: persona).persist(prefs);
    _ref.invalidate(personaPreferencesProvider);
    _logger.info('Persona updated to ${persona.toJson()}');
    return persona;
  }

  Future<void> clearOverride() async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    await const PersonaPreferences(persona: null).persist(prefs);
    _ref.invalidate(personaPreferencesProvider);
    _logger.info('Persona override cleared');
  }
}

UserPersona _personaForLocale(String languageCode) {
  final normalized = languageCode.toLowerCase();
  const jpCodes = {'ja', 'ja-jp'};
  if (jpCodes.contains(normalized)) return UserPersona.japanese;
  return UserPersona.foreigner;
}

const _personaPreferenceKey = 'app_persona_preference';
