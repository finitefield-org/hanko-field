// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:math';

import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  try {
    return ref.scope(AuthRepository.fallback);
  } on StateError {
    return FirebaseAuthRepository(ref);
  }
});

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._ref) : _logger = authLogger();

  final Ref _ref;
  final Logger _logger;

  FirebaseAuth get _auth => _ref.watch(firebaseAuthProvider);

  @override
  Future<AuthResult> signInWithApple({bool linkWithCurrent = true}) async {
    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        throw const AuthException(AuthErrorCode.appleUnavailable);
      }

      final nonce = _generateNonce();
      final hashed = _sha256ofString(nonce);

      final appleIdCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashed,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleIdCredential.identityToken,
        accessToken: appleIdCredential.authorizationCode,
        rawNonce: nonce,
      );

      return _signInWithCredential(
        oauthCredential,
        linkWithCurrent: linkWithCurrent,
      );
    } on SignInWithAppleAuthorizationException catch (e, stack) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthException(AuthErrorCode.cancelled);
      }
      _logger.warning('Apple sign-in failed: $e', e, stack);
      throw AuthException(AuthErrorCode.unknown, message: e.message, cause: e);
    } on FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(e);
    } catch (e, stack) {
      _logger.severe('Unexpected Apple sign-in error', e, stack);
      throw AuthException(AuthErrorCode.unknown, cause: e);
    }
  }

  @override
  Future<AuthResult> signInWithGoogle({bool linkWithCurrent = true}) async {
    try {
      final google = GoogleSignIn(scopes: const ['email']);
      final account = await google.signIn();
      if (account == null) {
        throw const AuthException(AuthErrorCode.cancelled);
      }

      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      return _signInWithCredential(
        credential,
        linkWithCurrent: linkWithCurrent,
      );
    } on FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(e);
    } catch (e, stack) {
      _logger.severe('Unexpected Google sign-in error', e, stack);
      throw AuthException(AuthErrorCode.unknown, cause: e);
    }
  }

  @override
  Future<AuthResult> signInWithEmailAndPassword(
    String email,
    String password, {
    bool linkWithCurrent = true,
  }) async {
    final auth = _auth;
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    // Upgrade anonymous users by linking credentials.
    if (linkWithCurrent && auth.currentUser?.isAnonymous == true) {
      try {
        final linked = await auth.currentUser!.linkWithCredential(credential);
        return _toResult(linked, linked: true);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'provider-already-linked') {
          throw await _mapFirebaseException(e);
        }
      }
    }

    try {
      final existing = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _toResult(existing, linked: false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        final created = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _toResult(created, linked: false);
      }
      throw await _mapFirebaseException(e);
    }
  }

  @override
  Future<AuthResult> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    return _toResult(result, linked: false);
  }

  @override
  Future<void> linkWithCredential(AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current == null) {
      throw const AuthException(
        AuthErrorCode.unknown,
        message: 'No active user to link credentials with.',
      );
    }

    try {
      await current.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        _logger.fine('Credential already linked; continuing');
        return;
      }
      throw await _mapFirebaseException(e);
    }
  }

  Future<AuthResult> _signInWithCredential(
    AuthCredential credential, {
    required bool linkWithCurrent,
  }) async {
    try {
      UserCredential userCredential;

      if (linkWithCurrent && _auth.currentUser?.isAnonymous == true) {
        userCredential = await _auth.currentUser!.linkWithCredential(
          credential,
        );
        return _toResult(userCredential, linked: true);
      }

      userCredential = await _auth.signInWithCredential(credential);
      return _toResult(userCredential, linked: false);
    } on FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(e);
    }
  }

  AuthResult _toResult(UserCredential credential, {required bool linked}) {
    final user = credential.user;
    if (user == null) {
      throw const AuthException(AuthErrorCode.unknown, message: 'Missing user');
    }
    return AuthResult(
      user: user,
      isLink: linked,
      isNewUser: credential.additionalUserInfo?.isNewUser ?? false,
    );
  }

  Future<AuthException> _mapFirebaseException(
    FirebaseAuthException exception,
  ) async {
    _logger.warning(
      'FirebaseAuth error: ${exception.code} ${exception.message}',
      exception,
    );

    if (exception.code == 'account-exists-with-different-credential') {
      final email = exception.email;
      final pendingCredential = exception.credential;
      final methods = email != null
          // ignore: deprecated_member_use
          ? await _auth.fetchSignInMethodsForEmail(email)
          : <String>[];

      if (email != null && pendingCredential != null) {
        return AuthException(
          AuthErrorCode.accountExistsWithDifferentCredential,
          message: exception.message,
          linkContext: AuthLinkContext(
            email: email,
            pendingCredential: pendingCredential,
            existingProviders: methods,
          ),
          cause: exception,
        );
      }
    }

    final code = switch (exception.code) {
      'wrong-password' => AuthErrorCode.wrongPassword,
      'invalid-credential' => AuthErrorCode.invalidCredential,
      'invalid-email' => AuthErrorCode.invalidCredential,
      'user-disabled' => AuthErrorCode.invalidCredential,
      'weak-password' => AuthErrorCode.weakPassword,
      'network-request-failed' => AuthErrorCode.network,
      _ => AuthErrorCode.unknown,
    };

    return AuthException(code, message: exception.message, cause: exception);
  }
}

String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
