import 'package:app/core/app_state/user_session.dart';
import 'package:app/features/auth/application/auth_controller.dart';
import 'package:app/features/auth/infrastructure/firebase_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements FirebaseAuthService {}

class _TrackingUserSessionNotifier extends UserSessionNotifier {
  _TrackingUserSessionNotifier(this._onRefresh);

  final void Function() _onRefresh;

  @override
  Future<UserSessionState> build() async {
    return UserSessionState.unauthenticated();
  }

  @override
  Future<void> refreshProfile() async {
    _onRefresh();
  }
}

void main() {
  group('AuthController', () {
    late _MockAuthService mockService;
    late int refreshCount;
    late ProviderContainer container;

    setUp(() {
      mockService = _MockAuthService();
      refreshCount = 0;
      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockService),
          userSessionProvider.overrideWith(
            () => _TrackingUserSessionNotifier(() {
              refreshCount++;
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('does not call email sign-in when form is invalid', () async {
      final controller = container.read(authControllerProvider.notifier);

      await controller.signInWithEmail();

      verifyNever(
        () => mockService.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
      expect(
        container.read(authControllerProvider).emailValidationMessage,
        'メールアドレスを入力してください',
      );
    });

    test('google sign-in delegates to service and refreshes session', () async {
      when(() => mockService.signInWithGoogle()).thenAnswer((_) async {});

      final controller = container.read(authControllerProvider.notifier);
      await controller.signInWithGoogle();

      verify(() => mockService.signInWithGoogle()).called(1);
      expect(refreshCount, 1);
      expect(container.read(authControllerProvider).activeAction, isNull);
    });
  });
}
