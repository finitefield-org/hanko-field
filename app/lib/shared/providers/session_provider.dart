// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/features/users/data/repositories/local_user_repository.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/security/secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:miniriverpod/miniriverpod.dart';

const userSessionScope = Scope<UserSession>.required('app.session');

class SessionUser {
  const SessionUser({
    required this.uid,
    required this.isAnonymous,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
  });

  factory SessionUser.fromFirebaseUser(User user) {
    return SessionUser(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      email: user.email,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
    );
  }

  final String uid;
  final bool isAnonymous;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SessionUser &&
            other.uid == uid &&
            other.isAnonymous == isAnonymous &&
            other.email == email &&
            other.displayName == displayName &&
            other.phoneNumber == phoneNumber &&
            other.photoUrl == photoUrl);
  }

  @override
  int get hashCode =>
      Object.hash(uid, isAnonymous, email, displayName, phoneNumber, photoUrl);
}

class UserSession {
  const UserSession._({required this.user, required this.profile});

  const UserSession.signedOut() : this._(user: null, profile: null);

  const UserSession.authenticated({
    required SessionUser user,
    required UserProfile profile,
  }) : this._(user: user, profile: profile);

  final SessionUser? user;
  final UserProfile? profile;

  bool get isAuthenticated => user != null && profile != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UserSession &&
            other.user == user &&
            other.profile == profile);
  }

  @override
  int get hashCode => Object.hash(user, profile);
}

class UserSessionProvider extends AsyncProvider<UserSession> {
  UserSessionProvider() : super.args(null, autoDispose: false);

  late final refreshMut = mutation<UserSession>(#refresh);
  late final signOutMut = mutation<void>(#signOut);

  @override
  Future<UserSession> build(Ref ref) async {
    try {
      return ref.scope(userSessionScope);
    } on StateError {
      // Fall back to Firebase + backend profile.
    }

    final auth = ref.watch(firebaseAuthProvider);
    final tokenStorage = ref.watch(tokenStorageProvider);

    // Keep the session updated as Firebase auth state changes.
    ref.emit(
      auth
          .authStateChanges()
          .skip(1)
          .asyncMap((user) => _buildSession(ref, user, tokenStorage)),
    );

    final currentUser = auth.currentUser;
    return _buildSession(ref, currentUser, tokenStorage);
  }

  Call<UserSession> refresh() => mutate(refreshMut, (ref) async {
    final auth = ref.watch(firebaseAuthProvider);
    final tokenStorage = ref.watch(tokenStorageProvider);
    final av = ref.watch(this);
    ref.state = switch (av) {
      AsyncData(:final value) => AsyncData(value, isRefreshing: true),
      AsyncError(:final error, :final stack, :final previous) => AsyncError(
        error,
        stack,
        previous: previous,
      ),
      _ => const AsyncLoading<UserSession>(),
    };

    final session = await _buildSession(ref, auth.currentUser, tokenStorage);
    ref.state = AsyncData(session);
    return session;
  }, concurrency: Concurrency.restart);

  Call<void> signOut() => mutate(signOutMut, (ref) async {
    final auth = ref.watch(firebaseAuthProvider);
    final tokenStorage = ref.watch(tokenStorageProvider);
    await Future.wait([auth.signOut(), tokenStorage.clear()]);
    ref.state = const AsyncData(UserSession.signedOut());
  }, concurrency: Concurrency.dropLatest);

  Future<UserSession> _buildSession(
    Ref ref,
    User? user,
    TokenStorage tokenStorage,
  ) async {
    if (user == null) {
      await tokenStorage.clear();
      return const UserSession.signedOut();
    }

    final repository = ref.watch(userRepositoryProvider);
    final profile = await repository.fetchProfile();

    return UserSession.authenticated(
      user: SessionUser.fromFirebaseUser(user),
      profile: profile,
    );
  }
}

final userSessionProvider = UserSessionProvider();

/// Widget tests can override the entire session value:
/// `ProviderScope(overrides: [userSessionScope.overrideWithValue(fakeSession)])`.
