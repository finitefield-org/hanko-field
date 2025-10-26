import 'dart:async';

import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/user_repository.dart';
import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockAuthTokenStorage extends Mock implements AuthTokenStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockFirebaseAuth auth;
  late _MockFirebaseUser firebaseUser;
  late _MockUserInfo userInfo;
  late _MockUserRepository repository;
  late _MockAuthTokenStorage tokenStorage;
  late StreamController<User?> authController;
  late StreamController<User?> tokenController;

  final profile = UserProfile(
    id: 'user-123',
    displayName: 'Test User',
    email: 'user@example.com',
    phone: '+810000000',
    persona: UserPersona.japanese,
    preferredLanguage: UserLanguage.ja,
    country: 'JP',
    marketingOptIn: true,
    isActive: true,
    piiMasked: false,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024, 1, 2),
  );

  setUp(() {
    auth = _MockFirebaseAuth();
    firebaseUser = _MockFirebaseUser();
    userInfo = _MockUserInfo();
    repository = _MockUserRepository();
    tokenStorage = _MockAuthTokenStorage();
    authController = StreamController<User?>.broadcast();
    tokenController = StreamController<User?>.broadcast();

    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => authController.stream);
    when(() => auth.idTokenChanges()).thenAnswer((_) => tokenController.stream);
    when(() => repository.fetchCurrentUser()).thenAnswer((_) async => profile);
    when(() => tokenStorage.clearTokens()).thenAnswer((_) async {});
    when(
      () => tokenStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});

    when(() => firebaseUser.uid).thenReturn('user-123');
    when(() => firebaseUser.email).thenReturn('user@example.com');
    when(() => firebaseUser.displayName).thenReturn('Test User');
    when(() => firebaseUser.phoneNumber).thenReturn('+810000000');
    when(() => firebaseUser.photoURL).thenReturn(null);
    when(() => firebaseUser.isAnonymous).thenReturn(false);
    when(() => firebaseUser.providerData).thenReturn([userInfo]);
    when(() => firebaseUser.getIdToken()).thenAnswer((_) async => 'token-1');
    when(() => firebaseUser.refreshToken).thenReturn('refresh-1');
    when(() => userInfo.providerId).thenReturn('password');
    when(() => auth.currentUser).thenReturn(null);
  });

  tearDown(() async {
    await authController.close();
    await tokenController.close();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        firebaseInitializedProvider.overrideWith((ref) async {}),
        userRepositoryProvider.overrideWith((ref) => repository),
        authTokenStorageProvider.overrideWithValue(tokenStorage),
      ],
    );
  }

  test(
    'returns unauthenticated state when there is no Firebase session',
    () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final state = await container.read(userSessionProvider.future);
      expect(state.status, UserSessionStatus.unauthenticated);
      verify(() => tokenStorage.clearTokens()).called(1);
    },
  );

  test('loads profile and stores tokens when user signs in', () async {
    when(() => auth.currentUser).thenReturn(firebaseUser);

    final container = createContainer();
    addTearDown(container.dispose);

    final state = await container.read(userSessionProvider.future);

    expect(state.status, UserSessionStatus.authenticated);
    expect(state.profile, profile);
    expect(state.identity?.uid, 'user-123');
    expect(state.idToken, 'token-1');
    verifyInOrder([
      () => tokenStorage.saveTokens(
        accessToken: 'token-1',
        refreshToken: 'refresh-1',
      ),
      () => repository.fetchCurrentUser(),
    ]);
  });
}
