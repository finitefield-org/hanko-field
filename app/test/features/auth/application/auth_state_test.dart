import 'package:app/features/auth/application/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthState validation', () {
    test('requires both email and password to submit', () {
      const state = AuthState(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(state.canSubmitEmail, isTrue);
    });

    test('returns error message when email invalid after interaction', () {
      const state = AuthState(
        email: 'invalid-email',
        password: 'password123',
        emailDirty: true,
      );

      expect(state.emailValidationMessage, 'メールアドレスの形式が正しくありません');
    });

    test('returns error message when password too short', () {
      const state = AuthState(
        email: 'user@example.com',
        password: 'short',
        emailDirty: true,
        passwordDirty: true,
      );

      expect(state.passwordValidationMessage, '8文字以上のパスワードを入力してください');
    });
  });
}
