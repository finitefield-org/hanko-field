import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/application/design_name_input_state.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designNameInputControllerProvider =
    NotifierProvider<DesignNameInputController, DesignNameInputState>(
      DesignNameInputController.new,
      name: 'designNameInputControllerProvider',
    );

class DesignNameInputController extends Notifier<DesignNameInputState> {
  @override
  DesignNameInputState build() {
    // ユーザーセッションからペルソナと表示名候補を反映
    ref.listen<AsyncValue<UserSessionState>>(
      userSessionProvider,
      (previous, next) => next.whenData(_applyUserSession),
    );

    ref.listen<DesignCreationState>(
      designCreationControllerProvider,
      (previous, next) => _applyDraft(next.nameDraft),
    );

    Future.microtask(() {
      final session = ref.read(userSessionProvider);
      session.whenData(_applyUserSession);
      final draft = ref.read(designCreationControllerProvider).nameDraft;
      _applyDraft(draft);
    });

    return const DesignNameInputState();
  }

  void updateSurname(String value) {
    state = state.copyWith(surname: value, surnameDirty: true);
  }

  void updateGivenName(String value) {
    state = state.copyWith(givenName: value, givenNameDirty: true);
  }

  void updateSurnameReading(String value) {
    state = state.copyWith(surnameReading: value, surnameReadingDirty: true);
  }

  void updateGivenNameReading(String value) {
    state = state.copyWith(
      givenNameReading: value,
      givenNameReadingDirty: true,
    );
  }

  void applySuggestion(DesignNameSuggestion suggestion) {
    if (suggestion.isEmpty) {
      return;
    }
    state = state.copyWith(
      surname: suggestion.surname,
      givenName: suggestion.givenName,
      surnameDirty: false,
      givenNameDirty: false,
    );
  }

  Future<bool> submit() async {
    final requiresKana = state.requiresKana;
    state = state.copyWith(
      surnameDirty: true,
      givenNameDirty: true,
      surnameReadingDirty: requiresKana ? true : state.surnameReadingDirty,
      givenNameReadingDirty: requiresKana ? true : state.givenNameReadingDirty,
    );

    final current = state;
    if (!current.canSubmit) {
      return false;
    }

    final draft = DesignNameDraft(
      persona: current.persona,
      surname: current.surname.trim(),
      givenName: current.givenName.trim(),
      surnameReading: _normalizeOptional(current.surnameReading),
      givenNameReading: _normalizeOptional(current.givenNameReading),
    );

    ref.read(designCreationControllerProvider.notifier).setNameDraft(draft);

    return true;
  }

  void openKanjiMapper() {
    final notifier = ref.read(appStateProvider.notifier);
    notifier.push(CreationStageRoute(const ['input', 'kanji-map']));
  }

  void _applyUserSession(UserSessionState session) {
    final persona = session.profile?.persona ?? UserPersona.japanese;
    final suggestions = _buildSuggestions(session);

    DesignNameSuggestion? firstSuggestion;
    if (suggestions.isNotEmpty) {
      firstSuggestion = suggestions.first;
    }
    final shouldPrefill =
        state.isPristine && firstSuggestion != null && !firstSuggestion.isEmpty;

    state = state.copyWith(
      persona: persona,
      suggestions: suggestions,
      surname: shouldPrefill ? firstSuggestion.surname : state.surname,
      givenName: shouldPrefill ? firstSuggestion.givenName : state.givenName,
    );
  }

  void _applyDraft(DesignNameDraft? draft) {
    if (draft == null || !state.isPristine) {
      return;
    }
    state = state.copyWith(
      surname: draft.surname,
      givenName: draft.givenName,
      surnameReading: draft.surnameReading ?? '',
      givenNameReading: draft.givenNameReading ?? '',
      persona: draft.persona,
    );
  }

  List<DesignNameSuggestion> _buildSuggestions(UserSessionState session) {
    final result = <DesignNameSuggestion>[];
    final seen = <String>{};
    final profileName = session.profile?.displayName;
    if (profileName != null && profileName.trim().isNotEmpty) {
      final parsed = _splitName(profileName.trim());
      if (parsed != null) {
        final key = '${parsed.$1}|${parsed.$2}';
        if (seen.add(key)) {
          result.add(
            DesignNameSuggestion(
              labelKey: 'profile',
              surname: parsed.$1,
              givenName: parsed.$2,
              description: session.profile?.country,
            ),
          );
        }
      }
    }

    final identityName = session.identity?.displayName;
    if (identityName != null &&
        identityName.trim().isNotEmpty &&
        identityName.trim() != profileName?.trim()) {
      final parsed = _splitName(identityName.trim());
      if (parsed != null) {
        final key = '${parsed.$1}|${parsed.$2}';
        if (seen.add(key)) {
          result.add(
            DesignNameSuggestion(
              labelKey: 'identity',
              surname: parsed.$1,
              givenName: parsed.$2,
            ),
          );
        }
      }
    }

    return List.unmodifiable(result);
  }

  (String, String)? _splitName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts.first, parts.sublist(1).join(' '));
    }
    return (trimmed, '');
  }

  String? _normalizeOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
