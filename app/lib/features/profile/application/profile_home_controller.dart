import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ProfileMembershipStatus { active, suspended, staff, admin }

@immutable
class ProfileHomeState {
  const ProfileHomeState({
    required this.profile,
    required this.identity,
    required this.membershipStatus,
    this.isSavingPersona = false,
  });

  final UserProfile profile;
  final SessionIdentity? identity;
  final ProfileMembershipStatus membershipStatus;
  final bool isSavingPersona;

  ProfileHomeState copyWith({
    UserProfile? profile,
    SessionIdentity? identity,
    ProfileMembershipStatus? membershipStatus,
    bool? isSavingPersona,
  }) {
    return ProfileHomeState(
      profile: profile ?? this.profile,
      identity: identity ?? this.identity,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      isSavingPersona: isSavingPersona ?? this.isSavingPersona,
    );
  }
}

class ProfileHomeController extends AsyncNotifier<ProfileHomeState> {
  @override
  Future<ProfileHomeState> build() => _loadState(watchSession: true);

  Future<void> reload() async {
    state = const AsyncLoading();
    try {
      ref.invalidate(userSessionProvider);
      final next = await _loadState();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(next);
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> changePersona(UserPersona persona) async {
    final current = state.asData?.value ?? await future;
    if (current.isSavingPersona || current.profile.persona == persona) {
      return;
    }

    final previousProfile = current.profile;
    final optimisticProfile = previousProfile.copyWith(persona: persona);
    final optimisticState = current.copyWith(
      profile: optimisticProfile,
      membershipStatus: _membershipFromProfile(optimisticProfile),
      isSavingPersona: true,
    );
    state = AsyncData(optimisticState);

    try {
      final repository = ref.read(userRepositoryProvider);
      final savedProfile = await repository.updateProfile(optimisticProfile);
      if (!ref.mounted) {
        return;
      }
      final latestState = state.asData?.value ?? optimisticState;
      state = AsyncData(
        latestState.copyWith(
          profile: savedProfile,
          membershipStatus: _membershipFromProfile(savedProfile),
          isSavingPersona: false,
        ),
      );
      ref.invalidate(userSessionProvider);
      ref.invalidate(experienceGateProvider);
    } catch (error, stackTrace) {
      if (ref.mounted) {
        final latestState = state.asData?.value ?? optimisticState;
        final shouldRestorePrevious =
            latestState.profile.id == previousProfile.id &&
            latestState.profile.persona == persona;
        final resolvedProfile = shouldRestorePrevious
            ? previousProfile
            : latestState.profile;
        state = AsyncData(
          latestState.copyWith(
            profile: resolvedProfile,
            membershipStatus: _membershipFromProfile(resolvedProfile),
            isSavingPersona: false,
          ),
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<ProfileHomeState> _loadState({bool watchSession = false}) async {
    final session = watchSession
        ? await ref.watch(userSessionProvider.future)
        : await ref.read(userSessionProvider.future);
    final profile = _resolveProfile(session);
    return ProfileHomeState(
      profile: profile,
      identity: session.identity,
      membershipStatus: _membershipFromProfile(profile),
    );
  }

  UserProfile _resolveProfile(UserSessionState session) {
    final profile = session.profile;
    if (profile != null) {
      return profile;
    }

    final identity = session.identity;
    final now = DateTime.now();
    return UserProfile(
      id: identity?.uid ?? 'guest',
      displayName: identity?.displayName ?? 'Guest user',
      email: identity?.email,
      phone: identity?.phoneNumber,
      avatarUrl: identity?.photoUrl,
      persona: UserPersona.japanese,
      preferredLanguage: UserLanguage.ja,
      country: null,
      onboarding: const <String, dynamic>{},
      marketingOptIn: null,
      role: UserRole.user,
      isActive: true,
      piiMasked: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  ProfileMembershipStatus _membershipFromProfile(UserProfile profile) {
    if (!profile.isActive || profile.deletedAt != null) {
      return ProfileMembershipStatus.suspended;
    }
    if (profile.role == UserRole.admin) {
      return ProfileMembershipStatus.admin;
    }
    if (profile.role == UserRole.staff) {
      return ProfileMembershipStatus.staff;
    }
    return ProfileMembershipStatus.active;
  }
}

final profileHomeControllerProvider =
    AsyncNotifierProvider<ProfileHomeController, ProfileHomeState>(
      ProfileHomeController.new,
    );
