// ignore_for_file: public_member_api_docs

import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum AuthErrorCode {
  cancelled,
  appleUnavailable,
  invalidCredential,
  wrongPassword,
  weakPassword,
  network,
  unknown,
  accountExistsWithDifferentCredential,
}

class AuthLinkContext {
  const AuthLinkContext({
    required this.email,
    required this.pendingCredential,
    required this.existingProviders,
  });

  final String email;
  final AuthCredential pendingCredential;
  final List<String> existingProviders;
}

class AuthException implements Exception {
  const AuthException(this.code, {this.message, this.linkContext, this.cause});

  final AuthErrorCode code;
  final String? message;
  final AuthLinkContext? linkContext;
  final Object? cause;
}

class AuthResult {
  const AuthResult({
    required this.user,
    required this.isLink,
    required this.isNewUser,
  });

  final User user;
  final bool isLink;
  final bool isNewUser;
}

abstract class AuthRepository {
  static const fallback = Scope<AuthRepository>.required('auth.repository');

  Future<AuthResult> signInWithApple({bool linkWithCurrent = true});

  Future<AuthResult> signInWithGoogle({bool linkWithCurrent = true});

  Future<AuthResult> signInWithEmailAndPassword(
    String email,
    String password, {
    bool linkWithCurrent = true,
  });

  Future<AuthResult> signInAnonymously();

  Future<void> linkWithCredential(AuthCredential credential);
}

Logger authLogger() => Logger('AuthRepository');
