import 'package:flutter/foundation.dart';

/// 認証アクションの種別
enum AuthAction { apple, google, email, guest }

@immutable
class AuthState {
  const AuthState({
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.emailFormExpanded = false,
    this.emailDirty = false,
    this.passwordDirty = false,
    this.activeAction,
    this.errorMessage,
  });

  final String email;
  final String password;
  final bool isPasswordVisible;
  final bool emailFormExpanded;
  final bool emailDirty;
  final bool passwordDirty;
  final AuthAction? activeAction;
  final String? errorMessage;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get isProcessing => activeAction != null;

  String? get emailValidationMessage {
    if (!emailDirty) {
      return null;
    }
    return _validateEmail(email);
  }

  String? get passwordValidationMessage {
    if (!passwordDirty) {
      return null;
    }
    return _validatePassword(password);
  }

  bool get canSubmitEmail {
    return _validateEmail(email) == null && _validatePassword(password) == null;
  }

  AuthState copyWith({
    String? email,
    String? password,
    bool? isPasswordVisible,
    bool? emailFormExpanded,
    bool? emailDirty,
    bool? passwordDirty,
    AuthAction? activeAction,
    bool clearActiveAction = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      emailFormExpanded: emailFormExpanded ?? this.emailFormExpanded,
      emailDirty: emailDirty ?? this.emailDirty,
      passwordDirty: passwordDirty ?? this.passwordDirty,
      activeAction: clearActiveAction
          ? null
          : activeAction ?? this.activeAction,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static String? _validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'メールアドレスの形式が正しくありません';
    }
    return null;
  }

  static String? _validatePassword(String value) {
    if (value.isEmpty) {
      return 'パスワードを入力してください';
    }
    if (value.length < 8) {
      return '8文字以上のパスワードを入力してください';
    }
    return null;
  }
}
