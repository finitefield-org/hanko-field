import 'dart:async';

import 'package:app/core/app_state/user_session.dart';
import 'package:app/features/auth/application/auth_state.dart';
import 'package:app/features/auth/infrastructure/firebase_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void toggleEmailForm() {
    state = state.copyWith(
      emailFormExpanded: !state.emailFormExpanded,
      clearError: true,
    );
  }

  void updateEmail(String value) {
    state = state.copyWith(email: value, emailDirty: true, clearError: true);
  }

  void updatePassword(String value) {
    state = state.copyWith(
      password: value,
      passwordDirty: true,
      clearError: true,
    );
  }

  void togglePasswordVisibility() {
    state = state.copyWith(
      isPasswordVisible: !state.isPasswordVisible,
      clearError: true,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> signInWithGoogle() {
    return _execute(
      AuthAction.google,
      () => ref.read(authServiceProvider).signInWithGoogle(),
    );
  }

  Future<void> signInWithApple() {
    return _execute(
      AuthAction.apple,
      () => ref.read(authServiceProvider).signInWithApple(),
    );
  }

  Future<void> signInWithEmail() async {
    final nextState = state.copyWith(
      emailDirty: true,
      passwordDirty: true,
      clearError: true,
    );
    if (!nextState.canSubmitEmail) {
      state = nextState;
      return;
    }
    state = nextState;
    await _execute(
      AuthAction.email,
      () => ref
          .read(authServiceProvider)
          .signInWithEmail(
            email: nextState.email.trim(),
            password: nextState.password,
          ),
    );
  }

  Future<void> continueAsGuest() {
    return _execute(
      AuthAction.guest,
      () => ref.read(authServiceProvider).continueAsGuest(),
    );
  }

  Future<void> _execute(
    AuthAction action,
    Future<void> Function() operation,
  ) async {
    if (state.isProcessing) {
      return;
    }

    state = state.copyWith(activeAction: action, clearError: true);

    try {
      await operation();
    } on AuthFailure catch (failure) {
      if (!ref.mounted) {
        return;
      }
      if (failure.isCancelled) {
        state = state.copyWith(clearActiveAction: true);
        return;
      }
      state = state.copyWith(
        errorMessage: failure.message,
        clearActiveAction: true,
      );
      return;
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        errorMessage: 'サインインに失敗しました。時間をおいて再度お試しください。',
        clearActiveAction: true,
      );
      return;
    }

    if (!ref.mounted) {
      return;
    }

    try {
      await ref.read(userSessionProvider.notifier).refreshProfile();
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(clearActiveAction: true);
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        errorMessage: 'プロフィール情報の取得に失敗しました。接続状況を確認して再試行してください。',
        clearActiveAction: true,
      );
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
