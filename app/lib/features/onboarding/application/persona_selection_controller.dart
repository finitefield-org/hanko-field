import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/preferences/pref_keys.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class PersonaOption {
  const PersonaOption({
    required this.persona,
    required this.label,
    required this.caption,
    required this.highlight,
  });

  final UserPersona persona;
  final String label;
  final String caption;
  final String highlight;
}

@immutable
class PersonaSelectionState {
  const PersonaSelectionState({
    required this.availablePersonas,
    required this.initialPersona,
    required this.selectedPersona,
    this.isSaving = false,
  });

  final List<PersonaOption> availablePersonas;
  final UserPersona initialPersona;
  final UserPersona selectedPersona;
  final bool isSaving;

  bool get hasPendingChanges => selectedPersona != initialPersona;

  PersonaSelectionState copyWith({
    List<PersonaOption>? availablePersonas,
    UserPersona? initialPersona,
    UserPersona? selectedPersona,
    bool? isSaving,
  }) {
    return PersonaSelectionState(
      availablePersonas: availablePersonas ?? this.availablePersonas,
      initialPersona: initialPersona ?? this.initialPersona,
      selectedPersona: selectedPersona ?? this.selectedPersona,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class PersonaSelectionController extends AsyncNotifier<PersonaSelectionState> {
  static const List<PersonaOption> _personaOptions = [
    PersonaOption(
      persona: UserPersona.japanese,
      label: '日本のお客様',
      caption: '国内向けのチェックリスト・実印ガイドを優先表示',
      highlight: '戸籍ベースの漢字入力、銀行印チェック、円建て決済',
    ),
    PersonaOption(
      persona: UserPersona.foreigner,
      label: '海外のお客様',
      caption: '英語 UI・ローマ字 → 漢字マッピングを中心に案内',
      highlight: 'パスポート綴り変換、カスタム翻訳、国際配送オプション',
    ),
  ];

  SharedPreferences? _preferences;

  @override
  Future<PersonaSelectionState> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    _preferences = prefs;

    final session = await ref.watch(userSessionProvider.future);
    final stored = prefs.getString(prefKeyUserPersonaSelection);

    UserPersona? resolved;
    if (session.status == UserSessionStatus.authenticated &&
        session.profile != null) {
      resolved = session.profile!.persona;
      await _persistLocal(resolved);
    } else if (stored != null) {
      resolved = _decodePersona(stored);
    }

    resolved ??= UserPersona.japanese;

    return PersonaSelectionState(
      availablePersonas: _personaOptions,
      initialPersona: resolved,
      selectedPersona: resolved,
    );
  }

  void selectPersona(UserPersona persona) {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }
    if (current.selectedPersona == persona) {
      return;
    }
    state = AsyncData(current.copyWith(selectedPersona: persona));
  }

  Future<void> saveSelection({bool force = false}) async {
    final current = state.asData?.value ?? await future;
    if (current.isSaving) {
      return;
    }
    if (!current.hasPendingChanges && !force) {
      return;
    }

    state = AsyncData(current.copyWith(isSaving: true));
    try {
      await _persistLocal(current.selectedPersona);
      await _syncRemotePersona(current.selectedPersona);
      await _markPersonaOnboardingComplete();

      if (!ref.mounted) {
        return;
      }
      state = AsyncData(
        current.copyWith(
          initialPersona: current.selectedPersona,
          isSaving: false,
        ),
      );
      ref.invalidate(experienceGateProvider);
    } catch (error) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isSaving: false));
      }
      rethrow;
    }
  }

  Future<void> _persistLocal(UserPersona persona) async {
    final prefs = await _ensurePreferences();
    final success = await prefs.setString(
      prefKeyUserPersonaSelection,
      persona.name,
    );
    if (!success) {
      throw StateError('Failed to persist persona preference locally.');
    }
  }

  Future<void> _syncRemotePersona(UserPersona persona) async {
    final session = await ref.read(userSessionProvider.future);
    if (session.status != UserSessionStatus.authenticated) {
      return;
    }
    final profile = session.profile;
    if (profile == null || profile.persona == persona) {
      return;
    }

    final repository = ref.read(userRepositoryProvider);
    final updatedProfile = profile.copyWith(persona: persona);
    await repository.updateProfile(updatedProfile);

    if (ref.mounted) {
      unawaited(ref.read(userSessionProvider.notifier).refreshProfile());
    }
  }

  Future<void> _markPersonaOnboardingComplete() async {
    final dataSource = await ref.read(onboardingLocalDataSourceProvider.future);
    await dataSource.updateStep(OnboardingStep.persona);
  }

  Future<SharedPreferences> _ensurePreferences() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }
    final prefs = await ref.read(sharedPreferencesProvider.future);
    _preferences = prefs;
    return prefs;
  }

  UserPersona _decodePersona(String raw) {
    return UserPersona.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => UserPersona.japanese,
    );
  }
}

final personaSelectionControllerProvider =
    AsyncNotifierProvider<PersonaSelectionController, PersonaSelectionState>(
      PersonaSelectionController.new,
    );
