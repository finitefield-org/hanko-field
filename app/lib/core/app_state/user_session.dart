import 'dart:async';

import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/user_repository.dart';
import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserSessionStatus { unknown, unauthenticated, authenticated }

@immutable
class SessionIdentity {
  const SessionIdentity({
    required this.uid,
    required this.isAnonymous,
    required this.providerIds,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
  });

  factory SessionIdentity.fromFirebaseUser(User user) {
    return SessionIdentity(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
      isAnonymous: user.isAnonymous,
      providerIds: List.unmodifiable([
        for (final info in user.providerData) info.providerId,
      ]),
    );
  }

  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isAnonymous;
  final List<String> providerIds;

  SessionIdentity copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    bool? isAnonymous,
    List<String>? providerIds,
  }) {
    return SessionIdentity(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      providerIds: providerIds == null
          ? this.providerIds
          : List.unmodifiable(providerIds),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SessionIdentity &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.phoneNumber == phoneNumber &&
        other.photoUrl == photoUrl &&
        other.isAnonymous == isAnonymous &&
        listEquals(other.providerIds, providerIds);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      uid,
      email,
      displayName,
      phoneNumber,
      photoUrl,
      isAnonymous,
      Object.hashAll(providerIds),
    ]);
  }
}

class UserSessionState {
  UserSessionState._internal({
    required this.status,
    required this.lastUpdatedAt,
    required this.lastProfileSyncedAt,
    this.identity,
    this.profile,
    this.idToken,
    this.refreshToken,
    this.isGuest = false,
  });

  factory UserSessionState._({
    required UserSessionStatus status,
    SessionIdentity? identity,
    UserProfile? profile,
    String? idToken,
    String? refreshToken,
    bool isGuest = false,
    DateTime? lastUpdatedAt,
    DateTime? lastProfileSyncedAt,
  }) {
    final resolvedUpdatedAt = lastUpdatedAt ?? DateTime.now();
    final resolvedProfileSyncedAt = lastProfileSyncedAt ?? resolvedUpdatedAt;
    return UserSessionState._internal(
      status: status,
      identity: identity,
      profile: profile,
      idToken: idToken,
      refreshToken: refreshToken,
      isGuest: isGuest,
      lastUpdatedAt: resolvedUpdatedAt,
      lastProfileSyncedAt: resolvedProfileSyncedAt,
    );
  }

  factory UserSessionState.unauthenticated() {
    return UserSessionState._(status: UserSessionStatus.unauthenticated);
  }

  factory UserSessionState.authenticated({
    required SessionIdentity identity,
    required UserProfile profile,
    required String idToken,
    String? refreshToken,
    bool isGuest = false,
    DateTime? profileSyncedAt,
  }) {
    return UserSessionState._(
      status: UserSessionStatus.authenticated,
      identity: identity,
      profile: profile,
      idToken: idToken,
      refreshToken: refreshToken,
      isGuest: isGuest,
      lastProfileSyncedAt: profileSyncedAt,
    );
  }

  final UserSessionStatus status;
  final SessionIdentity? identity;
  final UserProfile? profile;
  final String? idToken;
  final String? refreshToken;
  final bool isGuest;
  final DateTime lastUpdatedAt;
  final DateTime lastProfileSyncedAt;

  bool get isAuthenticated => status == UserSessionStatus.authenticated;

  UserSessionState copyWith({
    UserSessionStatus? status,
    SessionIdentity? identity,
    UserProfile? profile,
    String? idToken,
    String? refreshToken,
    bool? isGuest,
    DateTime? lastUpdatedAt,
    DateTime? lastProfileSyncedAt,
  }) {
    return UserSessionState._(
      status: status ?? this.status,
      identity: identity ?? this.identity,
      profile: profile ?? this.profile,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isGuest: isGuest ?? this.isGuest,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
      lastProfileSyncedAt: lastProfileSyncedAt ?? this.lastProfileSyncedAt,
    );
  }
}

class UserSessionNotifier extends AsyncNotifier<UserSessionState> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<User?>? _tokenSubscription;

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);
  UserRepository get _repository => ref.read(userRepositoryProvider);
  AuthTokenStorage get _tokenStorage => ref.read(authTokenStorageProvider);

  @override
  Future<UserSessionState> build() async {
    await ref.read(firebaseInitializedProvider.future);

    _authSubscription ??= _auth.authStateChanges().listen(_handleAuthChanged);
    _tokenSubscription ??= _auth.idTokenChanges().listen(
      _handleIdTokenRefreshed,
    );
    ref.onDispose(_disposeListeners);

    final user = _auth.currentUser;
    if (user == null) {
      await _tokenStorage.clearTokens();
      return UserSessionState.unauthenticated();
    }

    return _buildAuthenticatedState(user);
  }

  Future<void> refreshProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _tokenStorage.clearTokens();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(UserSessionState.unauthenticated());
      return;
    }
    final current = state.asData?.value ?? await _buildAuthenticatedState(user);
    try {
      final profile = await _repository.fetchCurrentUser();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(
        current.copyWith(profile: profile, lastProfileSyncedAt: DateTime.now()),
      );
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<UserSessionState> _buildAuthenticatedState(User user) async {
    final identity = SessionIdentity.fromFirebaseUser(user);
    final idToken = await _requireIdToken(user);
    final refreshToken = user.refreshToken;

    await _tokenStorage.saveTokens(
      accessToken: idToken,
      refreshToken: refreshToken,
    );

    final profile = await _repository.fetchCurrentUser();

    return UserSessionState.authenticated(
      identity: identity,
      profile: profile,
      idToken: idToken,
      refreshToken: refreshToken,
      isGuest: identity.isAnonymous,
      profileSyncedAt: DateTime.now(),
    );
  }

  Future<void> _handleAuthChanged(User? user) async {
    if (user == null) {
      await _tokenStorage.clearTokens();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(UserSessionState.unauthenticated());
      return;
    }
    state = const AsyncLoading();
    try {
      final next = await _buildAuthenticatedState(user);
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

  Future<void> _handleIdTokenRefreshed(User? user) async {
    if (user == null) {
      await _tokenStorage.clearTokens();
      return;
    }

    final newToken = await _requireIdToken(user);
    await _tokenStorage.saveTokens(
      accessToken: newToken,
      refreshToken: user.refreshToken,
    );

    final current = state.asData?.value;
    if (!ref.mounted || current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(idToken: newToken, refreshToken: user.refreshToken),
    );
  }

  Future<void> _disposeListeners() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    _authSubscription = null;
    _tokenSubscription = null;
  }

  Future<String> _requireIdToken(User user) async {
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Failed to fetch Firebase ID token for ${user.uid}');
    }
    return token;
  }
}

final userSessionProvider =
    AsyncNotifierProvider<UserSessionNotifier, UserSessionState>(
      UserSessionNotifier.new,
    );
