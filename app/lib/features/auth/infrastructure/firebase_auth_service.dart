import 'dart:convert';
import 'dart:math';

import 'package:app/core/firebase/firebase_providers.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

@immutable
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code, this.isCancelled = false});

  final String message;
  final String? code;
  final bool isCancelled;
}

class FirebaseAuthService {
  FirebaseAuthService({required FirebaseAuth auth, GoogleSignIn? googleSignIn})
    : _auth = auth,
      _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        await _signInOrLinkWithProvider(
          provider,
          providerId: GoogleAuthProvider.PROVIDER_ID,
        );
        return;
      }
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthFailure(
          'Googleサインインをキャンセルしました。',
          code: 'sign_in_canceled',
          isCancelled: true,
        );
      }
      final tokens = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      );
      await _signInOrLink(
        credential,
        providerId: GoogleAuthProvider.PROVIDER_ID,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Googleでのサインインに失敗しました。通信状況を確認して再度お試しください。');
    }
  }

  Future<void> signInWithApple() async {
    if (kIsWeb) {
      throw const AuthFailure('Appleでのサインインはウェブでは未対応です。');
    }
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw const AuthFailure('このデバイスではAppleでのサインインを利用できません。');
    }
    final rawNonce = _createNonce();
    final nonce = _sha256(rawNonce);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      if (credential.identityToken == null) {
        throw const AuthFailure('Apple ID トークンの取得に失敗しました。');
      }
      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: credential.identityToken, rawNonce: rawNonce);
      await _signInOrLink(oauthCredential, providerId: 'apple.com');
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthFailure(
          'Appleサインインをキャンセルしました。',
          code: 'authorization_canceled',
          isCancelled: true,
        );
      }
      final reason = error.message.trim().isEmpty
          ? error.code.name
          : error.message.trim();
      throw AuthFailure('Appleでのサインインに失敗しました: $reason', code: error.code.name);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Appleでのサインインに失敗しました。時間をおいて再度お試しください。');
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      try {
        await _auth.signInWithEmailAndPassword(
          email: trimmedEmail,
          password: password,
        );
        return;
      } on FirebaseAuthException catch (error) {
        if (error.code == 'user-not-found') {
          await _auth.createUserWithEmailAndPassword(
            email: trimmedEmail,
            password: password,
          );
          return;
        }
        throw _mapFirebaseAuthException(error);
      }
    }

    final credential = EmailAuthProvider.credential(
      email: trimmedEmail,
      password: password,
    );

    try {
      final alreadyLinked = currentUser.providerData.any(
        (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
      );
      if (alreadyLinked) {
        await currentUser.reauthenticateWithCredential(credential);
        return;
      }
      await currentUser.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'provider-already-linked') {
        await currentUser.reauthenticateWithCredential(credential);
        return;
      }
      if (error.code == 'credential-already-in-use' ||
          error.code == 'email-already-in-use') {
        await _auth.signInWithEmailAndPassword(
          email: trimmedEmail,
          password: password,
        );
        return;
      }
      throw _mapFirebaseAuthException(error);
    }
  }

  Future<void> continueAsGuest() async {
    final current = _auth.currentUser;
    if (current != null) {
      if (current.isAnonymous) {
        return;
      }
      await current.reload();
      return;
    }
    await _auth.signInAnonymously();
  }

  Future<void> _signInOrLink(
    AuthCredential credential, {
    required String providerId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      await _auth.signInWithCredential(credential);
      return;
    }
    try {
      final alreadyLinked = currentUser.providerData.any(
        (info) => info.providerId == providerId,
      );
      if (alreadyLinked) {
        await currentUser.reauthenticateWithCredential(credential);
        return;
      }
      await currentUser.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'provider-already-linked') {
        await currentUser.reauthenticateWithCredential(credential);
        return;
      }
      if (error.code == 'credential-already-in-use' ||
          error.code == 'email-already-in-use' ||
          error.code == 'account-exists-with-different-credential') {
        await _auth.signInWithCredential(credential);
        return;
      }
      throw _mapFirebaseAuthException(error);
    }
  }

  Future<void> _signInOrLinkWithProvider(
    AuthProvider provider, {
    required String providerId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      await _auth.signInWithPopup(provider);
      return;
    }
    try {
      final alreadyLinked = currentUser.providerData.any(
        (info) => info.providerId == providerId,
      );
      if (alreadyLinked) {
        await currentUser.reauthenticateWithPopup(provider);
        return;
      }
      await currentUser.linkWithPopup(provider);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'provider-already-linked') {
        await currentUser.reauthenticateWithPopup(provider);
        return;
      }
      if (error.code == 'credential-already-in-use' ||
          error.code == 'email-already-in-use' ||
          error.code == 'account-exists-with-different-credential') {
        await _auth.signInWithPopup(provider);
        return;
      }
      throw _mapFirebaseAuthException(error);
    }
  }

  AuthFailure _mapFirebaseAuthException(FirebaseAuthException error) {
    final message = switch (error.code) {
      'account-exists-with-different-credential' =>
        '同じメールアドレスで別のログイン方法が既に設定されています。別の方法をお試しください。',
      'credential-already-in-use' => 'この認証情報は既に使用されています。別のアカウントを選択してください。',
      'email-already-in-use' => 'このメールアドレスは既に登録されています。サインインをお試しください。',
      'invalid-credential' => '認証情報が無効です。再度お試しください。',
      'invalid-email' => 'メールアドレスの形式が正しくありません。',
      'invalid-password' => 'パスワードが正しくありません。再入力してください。',
      'operation-not-allowed' => 'このサインイン方法は現在利用できません。サポートにお問い合わせください。',
      'user-disabled' => 'このアカウントは無効化されています。サポートにお問い合わせください。',
      'user-not-found' || 'wrong-password' => 'メールアドレスまたはパスワードが一致しません。',
      'weak-password' => '安全性の高いパスワードを設定してください。',
      _ => 'サインインに失敗しました (${error.code}).',
    };
    return AuthFailure(message, code: error.code);
  }

  String _createNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(scopes: const ['email']);
});

final authServiceProvider = Provider<FirebaseAuthService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final googleSignIn = ref.watch(googleSignInProvider);
  return FirebaseAuthService(auth: auth, googleSignIn: googleSignIn);
});
