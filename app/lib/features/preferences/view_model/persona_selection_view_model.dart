// ignore_for_file: public_member_api_docs

import 'package:app/core/storage/onboarding_preferences.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/features/users/data/repositories/user_repository.dart';
import 'package:app/shared/providers/app_persona_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class PersonaOption {
  const PersonaOption({
    required this.persona,
    required this.title,
    required this.subtitle,
    required this.assists,
  });

  final UserPersona persona;
  final String title;
  final String subtitle;
  final List<String> assists;
}

class PersonaSelectionState {
  const PersonaSelectionState({
    required this.selected,
    required this.options,
    required this.isAuthenticated,
  });

  final UserPersona selected;
  final List<PersonaOption> options;
  final bool isAuthenticated;
}

final _personaLogger = Logger('PersonaSelectionViewModel');

class PersonaSelectionViewModel extends AsyncProvider<PersonaSelectionState> {
  PersonaSelectionViewModel() : super.args(null, autoDispose: true);

  late final saveMut = mutation<UserPersona>(#save);

  @override
  Future<PersonaSelectionState> build(Ref ref) async {
    await ref.watch(personaPreferencesProvider.future);
    final selected = ref.watch(appPersonaProvider);
    final session = ref.watch(userSessionProvider).valueOrNull;

    return PersonaSelectionState(
      selected: selected,
      options: personaOptions(),
      isAuthenticated: session?.isAuthenticated == true,
    );
  }

  Call<UserPersona> save(UserPersona persona) => mutate(saveMut, (ref) async {
    final personaService = ref.watch(appPersonaServiceProvider);
    final onboarding = ref.watch(onboardingPreferencesServiceProvider);

    await personaService.update(persona);
    await onboarding.update(personaSelected: true);
    await _syncProfile(ref, persona);
    return persona;
  }, concurrency: Concurrency.dropLatest);

  Future<void> _syncProfile(Ref ref, UserPersona persona) async {
    UserRepository repository;
    try {
      repository = ref.scope(UserRepository.fallback);
    } on StateError {
      _personaLogger.fine(
        'UserRepository not available; skipping persona sync',
      );
      return;
    }

    final session = ref.watch(userSessionProvider).valueOrNull;
    final profile = session?.profile;
    if (profile == null) {
      _personaLogger.fine('User not authenticated; persona sync skipped');
      return;
    }

    try {
      await repository.updateProfile(profile.copyWith(persona: persona));
      ref.invalidate(userSessionProvider);
    } catch (e, stack) {
      _personaLogger.warning('Failed to sync persona preference', e, stack);
    }
  }
}

List<PersonaOption> personaOptions() {
  return const [
    PersonaOption(
      persona: UserPersona.japanese,
      title: '日本の実用派',
      subtitle: '実印・銀行印など国内利用を想定したレコメンドを行います。',
      assists: ['漢字・かな入力を優先表示', '実印登録チェック', '国内配送・支払いを最適化'],
    ),
    PersonaOption(
      persona: UserPersona.foreigner,
      title: '文化体験・ギフト派',
      subtitle: '英語UIで漢字変換やギフト包装を案内します。',
      assists: ['英語UIとガイダンス', '漢字の意味と候補を提案', '海外配送・関税情報'],
    ),
  ];
}

final personaSelectionViewModel = PersonaSelectionViewModel();
