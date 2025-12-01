// ignore_for_file: public_member_api_docs

import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/data/firebase_auth_repository.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthState {
  const AuthState({required this.appleAvailable, this.pendingLink});

  final bool appleAvailable;
  final AuthLinkContext? pendingLink;

  bool get hasPendingLink => pendingLink != null;

  AuthState copyWith({
    bool? appleAvailable,
    AuthLinkContext? pendingLink,
    bool clearPendingLink = false,
  }) {
    return AuthState(
      appleAvailable: appleAvailable ?? this.appleAvailable,
      pendingLink: clearPendingLink ? null : pendingLink ?? this.pendingLink,
    );
  }
}

class AuthViewModel extends AsyncProvider<AuthState> {
  AuthViewModel() : super.args(null, autoDispose: true);

  late final appleMut = mutation<AuthResult>(#signInWithApple);
  late final googleMut = mutation<AuthResult>(#signInWithGoogle);
  late final emailMut = mutation<AuthResult>(#signInWithEmail);
  late final guestMut = mutation<AuthResult>(#continueAsGuest);
  late final clearLinkMut = mutation<void>(#clearPendingLink);

  final Logger _logger = Logger('AuthViewModel');

  @override
  Future<AuthState> build(Ref ref) async {
    final appleAvailable = await _isAppleAvailable();
    return AuthState(appleAvailable: appleAvailable);
  }

  Call<AuthResult> signInWithApple() => mutate(appleMut, (ref) async {
    return _authenticate(ref, (repo) => repo.signInWithApple());
  }, concurrency: Concurrency.restart);

  Call<AuthResult> signInWithGoogle() => mutate(googleMut, (ref) async {
    return _authenticate(ref, (repo) => repo.signInWithGoogle());
  }, concurrency: Concurrency.restart);

  Call<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) => mutate(emailMut, (ref) async {
    return _authenticate(
      ref,
      (repo) => repo.signInWithEmailAndPassword(email, password),
      consumePendingLink: true,
    );
  }, concurrency: Concurrency.restart);

  Call<AuthResult> continueAsGuest() => mutate(guestMut, (ref) async {
    return _authenticate(ref, (repo) => repo.signInAnonymously());
  }, concurrency: Concurrency.restart);

  Call<void> clearPendingLink() => mutate(clearLinkMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    ref.state = AsyncData(current.copyWith(clearPendingLink: true));
  }, concurrency: Concurrency.dropLatest);

  Future<AuthResult> _authenticate(
    Ref ref,
    Future<AuthResult> Function(AuthRepository repository) operation, {
    bool consumePendingLink = false,
  }) async {
    final repository = ref.watch(authRepositoryProvider);
    try {
      final result = await operation(repository);
      if (consumePendingLink) {
        await _linkPendingIfAny(ref, repository);
      } else {
        _clearPending(ref);
      }

      await ref.refreshValue(userSessionProvider, keepPrevious: true);
      return result;
    } on AuthException catch (e) {
      _updatePendingLink(ref, e.linkContext);
      rethrow;
    }
  }

  Future<void> _linkPendingIfAny(Ref ref, AuthRepository repository) async {
    final state = ref.watch(this).valueOrNull;
    final pending = state?.pendingLink;
    if (pending == null) return;

    try {
      await repository.linkWithCredential(pending.pendingCredential);
      _clearPending(ref);
    } on AuthException catch (e, stack) {
      _logger.warning('Failed to link pending credential', e, stack);
      rethrow;
    }
  }

  void _clearPending(Ref ref) {
    final state = ref.watch(this).valueOrNull;
    if (state == null) return;
    ref.state = AsyncData(state.copyWith(clearPendingLink: true));
  }

  void _updatePendingLink(Ref ref, AuthLinkContext? context) {
    if (context == null) return;
    final state = ref.watch(this).valueOrNull;
    if (state == null) return;
    ref.state = AsyncData(state.copyWith(pendingLink: context));
  }
}

Future<bool> _isAppleAvailable() async {
  try {
    return await SignInWithApple.isAvailable();
  } catch (_) {
    return false;
  }
}

final authViewModel = AuthViewModel();
