// ignore_for_file: public_member_api_docs

import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/features/users/data/repositories/local_user_repository.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/shared/providers/app_persona_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileHomeState {
  const ProfileHomeState({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.isAnonymous,
    required this.isAuthenticated,
    required this.persona,
  });

  final String displayName;
  final String? email;
  final String? avatarUrl;
  final bool isAnonymous;
  final bool isAuthenticated;
  final UserPersona persona;

  ProfileHomeState copyWith({
    String? displayName,
    String? email,
    String? avatarUrl,
    bool? isAnonymous,
    bool? isAuthenticated,
    UserPersona? persona,
  }) {
    return ProfileHomeState(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      persona: persona ?? this.persona,
    );
  }
}

final _logger = Logger('ProfileHomeViewModel');

class ProfileHomeViewModel extends AsyncProvider<ProfileHomeState> {
  ProfileHomeViewModel() : super.args(null, autoDispose: true);

  late final updatePersonaMut = mutation<UserPersona>(#updatePersona);
  late final refreshMut = mutation<UserSession>(#refresh);

  @override
  Future<ProfileHomeState> build(Ref ref) async {
    final persona = ref.watch(appPersonaProvider);
    final locale = ref.watch(appLocaleProvider);

    final session = await ref.watch(userSessionProvider.future);
    final user = session.user;
    final profile = session.profile;
    final l10n = AppLocalizations(locale);

    final displayName = _displayNameFor(user, profile, l10n: l10n);
    final email = profile?.email ?? user?.email;
    final avatarUrl = profile?.avatarUrl ?? user?.photoUrl;

    return ProfileHomeState(
      displayName: displayName,
      email: email,
      avatarUrl: avatarUrl,
      isAnonymous: user?.isAnonymous ?? false,
      isAuthenticated: session.isAuthenticated,
      persona: persona,
    );
  }

  Call<UserPersona> updatePersona(UserPersona persona) =>
      mutate(updatePersonaMut, (ref) async {
        final previous = ref.watch(this).valueOrNull;
        if (previous != null) {
          ref.state = AsyncData(previous.copyWith(persona: persona));
        }

        final personaService = ref.watch(appPersonaServiceProvider);
        await personaService.update(persona);
        await _syncProfile(ref, persona);
        return persona;
      }, concurrency: Concurrency.dropLatest);

  Call<UserSession> refresh() => mutate(refreshMut, (ref) async {
    final session = await ref.invoke(userSessionProvider.refresh());
    ref.invalidate(this);
    return session;
  }, concurrency: Concurrency.restart);

  Future<void> _syncProfile(Ref ref, UserPersona persona) async {
    final repository = ref.watch(userRepositoryProvider);
    final session = ref.watch(userSessionProvider).valueOrNull;
    final profile = session?.profile;
    if (profile == null) {
      _logger.fine('User not authenticated; persona sync skipped');
      return;
    }

    try {
      await repository.updateProfile(profile.copyWith(persona: persona));
      ref.invalidate(userSessionProvider);
    } catch (e, stack) {
      _logger.warning('Failed to sync persona preference', e, stack);
    }
  }
}

String _displayNameFor(
  SessionUser? user,
  UserProfile? profile, {
  required AppLocalizations l10n,
}) {
  final profileName = profile?.displayName?.trim();
  if (profileName != null && profileName.isNotEmpty) return profileName;

  final userName = user?.displayName?.trim();
  if (userName != null && userName.isNotEmpty) return userName;

  final email = user?.email?.trim();
  if (email != null && email.isNotEmpty) return email;

  if (user?.isAnonymous == true) return l10n.profileFallbackGuestName;
  return l10n.profileFallbackProfileName;
}

final profileHomeViewModel = ProfileHomeViewModel();
