import 'dart:async';

import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/user_repository.dart';
import 'package:app/features/profile/application/profile_home_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  late _MockUserRepository repository;

  setUpAll(() {
    registerFallbackValue(_buildProfile());
  });

  setUp(() {
    repository = _MockUserRepository();
  });

  test('changePersona updates state optimistically and persists', () async {
    final container = _buildContainer(
      profile: _buildProfile(),
      repository: repository,
    );
    addTearDown(container.dispose);

    when(() => repository.updateProfile(any())).thenAnswer((invocation) async {
      return invocation.positionalArguments.first as UserProfile;
    });

    final controller = container.read(profileHomeControllerProvider.notifier);
    await container.read(profileHomeControllerProvider.future);

    await controller.changePersona(UserPersona.foreigner);

    final state = container.read(profileHomeControllerProvider).value!;
    expect(state.profile.persona, UserPersona.foreigner);
    expect(state.isSavingPersona, isFalse);
    verify(
      () => repository.updateProfile(
        any(that: _hasPersona(UserPersona.foreigner)),
      ),
    ).called(1);
  });

  test('changePersona reverts when repository throws', () async {
    final container = _buildContainer(
      profile: _buildProfile(),
      repository: repository,
    );
    addTearDown(container.dispose);

    when(() => repository.updateProfile(any())).thenThrow(Exception('network'));

    final controller = container.read(profileHomeControllerProvider.notifier);
    await container.read(profileHomeControllerProvider.future);

    await expectLater(
      controller.changePersona(UserPersona.foreigner),
      throwsA(isA<Exception>()),
    );

    final state = container.read(profileHomeControllerProvider).value!;
    expect(state.profile.persona, UserPersona.japanese);
    expect(state.isSavingPersona, isFalse);
  });

  test('changePersona preserves concurrent updates', () async {
    final container = _buildContainer(
      profile: _buildProfile(),
      repository: repository,
    );
    addTearDown(container.dispose);

    final completer = Completer<UserProfile>();
    when(
      () => repository.updateProfile(any()),
    ).thenAnswer((_) => completer.future);

    final controller = container.read(profileHomeControllerProvider.notifier);
    await container.read(profileHomeControllerProvider.future);

    final saveFuture = controller.changePersona(UserPersona.foreigner);
    final optimisticState = controller.state.asData!.value;
    final updatedIdentity = optimisticState.identity?.copyWith(
      email: 'refreshed@example.com',
    );

    controller.state = AsyncData(
      optimisticState.copyWith(identity: updatedIdentity),
    );

    completer.complete(
      optimisticState.profile.copyWith(persona: UserPersona.foreigner),
    );

    await saveFuture;

    final resolved = container.read(profileHomeControllerProvider).value!;
    expect(resolved.identity?.email, 'refreshed@example.com');
    expect(resolved.profile.persona, UserPersona.foreigner);
    expect(resolved.isSavingPersona, isFalse);
  });
}

ProviderContainer _buildContainer({
  required UserProfile profile,
  required UserRepository repository,
}) {
  final session = UserSessionState.authenticated(
    identity: SessionIdentity(
      uid: 'user-1',
      isAnonymous: false,
      providerIds: const ['password'],
      email: 'user@example.com',
      displayName: profile.displayName,
      phoneNumber: profile.phone,
      photoUrl: profile.avatarUrl,
    ),
    profile: profile,
    idToken: 'token',
    refreshToken: 'refresh',
  );

  return ProviderContainer(
    overrides: [
      userRepositoryProvider.overrideWithValue(repository),
      userSessionProvider.overrideWith(
        () => _StaticUserSessionNotifier(session),
      ),
    ],
  );
}

class _StaticUserSessionNotifier extends UserSessionNotifier {
  _StaticUserSessionNotifier(this._state);

  final UserSessionState _state;

  @override
  Future<UserSessionState> build() async => _state;
}

UserProfile _buildProfile() {
  final now = DateTime(2024, 1, 1);
  return UserProfile(
    id: 'profile-1',
    displayName: 'Hanko User',
    email: 'user@example.com',
    phone: '+81-90-0000-0000',
    avatarUrl: 'https://example.com/avatar.png',
    persona: UserPersona.japanese,
    preferredLanguage: UserLanguage.ja,
    country: 'JP',
    onboarding: const {},
    marketingOptIn: true,
    role: UserRole.user,
    isActive: true,
    piiMasked: false,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
  );
}

Matcher _hasPersona(UserPersona persona) {
  return predicate<UserProfile>((profile) => profile.persona == persona);
}
