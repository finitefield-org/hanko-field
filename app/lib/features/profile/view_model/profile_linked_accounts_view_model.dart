// ignore_for_file: public_member_api_docs

import 'package:app/core/storage/preferences.dart';
import 'package:app/features/auth/data/firebase_auth_repository.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LinkedAccountProviderType { apple, google }

class LinkedAccountProvider {
  const LinkedAccountProvider({required this.type, required this.providerId});

  final LinkedAccountProviderType type;
  final String providerId;
}

const supportedLinkedAccountProviders = <LinkedAccountProvider>[
  LinkedAccountProvider(
    type: LinkedAccountProviderType.apple,
    providerId: 'apple.com',
  ),
  LinkedAccountProvider(
    type: LinkedAccountProviderType.google,
    providerId: 'google.com',
  ),
];

class LinkedAccountConnection {
  const LinkedAccountConnection({
    required this.provider,
    required this.isLinked,
    required this.autoSignInEnabled,
    this.email,
    this.displayName,
  });

  final LinkedAccountProvider provider;
  final bool isLinked;
  final bool autoSignInEnabled;
  final String? email;
  final String? displayName;

  LinkedAccountConnection copyWith({
    bool? isLinked,
    bool? autoSignInEnabled,
    String? email,
    String? displayName,
  }) {
    return LinkedAccountConnection(
      provider: provider,
      isLinked: isLinked ?? this.isLinked,
      autoSignInEnabled: autoSignInEnabled ?? this.autoSignInEnabled,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }
}

class LinkedAccountsState {
  const LinkedAccountsState({
    required this.accounts,
    required this.isAuthenticated,
    required this.isAnonymous,
    required this.linkedCount,
  });

  final List<LinkedAccountConnection> accounts;
  final bool isAuthenticated;
  final bool isAnonymous;
  final int linkedCount;

  LinkedAccountsState copyWith({List<LinkedAccountConnection>? accounts}) {
    final nextAccounts = accounts ?? this.accounts;
    return LinkedAccountsState(
      accounts: nextAccounts,
      isAuthenticated: isAuthenticated,
      isAnonymous: isAnonymous,
      linkedCount: nextAccounts.where((item) => item.isLinked).length,
    );
  }
}

final _logger = Logger('ProfileLinkedAccountsViewModel');

class ProfileLinkedAccountsViewModel
    extends AsyncProvider<LinkedAccountsState> {
  ProfileLinkedAccountsViewModel() : super.args(null, autoDispose: true);

  late final saveMut = mutation<void>(#save);
  late final unlinkMut = mutation<void>(#unlink);
  late final linkMut = mutation<void>(#link);
  late final refreshMut = mutation<void>(#refresh);

  @override
  Future<LinkedAccountsState> build(Ref ref) async {
    final auth = ref.watch(firebaseAuthProvider);
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return _buildState(auth.currentUser, prefs);
  }

  Call<void> refresh() => mutate(refreshMut, (ref) async {
    final auth = ref.watch(firebaseAuthProvider);
    await auth.currentUser?.reload();
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    ref.state = AsyncData(_buildState(auth.currentUser, prefs));
  }, concurrency: Concurrency.restart);

  Call<void> save(List<LinkedAccountConnection> accounts) =>
      mutate(saveMut, (ref) async {
        final prefs = await ref.watch(sharedPreferencesProvider.future);
        for (final account in accounts) {
          await prefs.setBool(
            _autoSignInKey(account.provider.providerId),
            account.autoSignInEnabled,
          );
        }
        final current = ref.watch(this).valueOrNull;
        if (current != null) {
          ref.state = AsyncData(current.copyWith(accounts: accounts));
        }
      }, concurrency: Concurrency.restart);

  Call<void> unlink(LinkedAccountProviderType providerType) =>
      mutate(unlinkMut, (ref) async {
        final auth = ref.watch(firebaseAuthProvider);
        final user = auth.currentUser;
        final providerId = _providerId(providerType);
        if (user == null) {
          throw StateError('No signed-in user to unlink.');
        }
        final current = ref.watch(this).valueOrNull;
        if (current != null && current.linkedCount <= 1) {
          throw StateError('Cannot unlink the last linked provider.');
        }

        try {
          await user.unlink(providerId);
          await user.reload();
        } on FirebaseAuthException catch (e, stack) {
          _logger.warning('Failed to unlink $providerId', e, stack);
          rethrow;
        }

        final prefs = await ref.watch(sharedPreferencesProvider.future);
        ref.state = AsyncData(_buildState(auth.currentUser, prefs));
      }, concurrency: Concurrency.queue);

  Call<void> link(LinkedAccountProviderType providerType) =>
      mutate(linkMut, (ref) async {
        final authRepo = ref.watch(authRepositoryProvider);
        switch (providerType) {
          case LinkedAccountProviderType.apple:
            await authRepo.signInWithApple(linkWithCurrent: true);
            break;
          case LinkedAccountProviderType.google:
            await authRepo.signInWithGoogle(linkWithCurrent: true);
            break;
        }

        final auth = ref.watch(firebaseAuthProvider);
        await auth.currentUser?.reload();
        final prefs = await ref.watch(sharedPreferencesProvider.future);
        ref.state = AsyncData(_buildState(auth.currentUser, prefs));
      }, concurrency: Concurrency.queue);
}

final profileLinkedAccountsViewModel = ProfileLinkedAccountsViewModel();

LinkedAccountsState _buildState(User? user, SharedPreferences prefs) {
  final providerData = user?.providerData ?? <UserInfo>[];
  final accounts = <LinkedAccountConnection>[];

  for (final provider in supportedLinkedAccountProviders) {
    UserInfo? info;
    for (final item in providerData) {
      if (item.providerId == provider.providerId) {
        info = item;
        break;
      }
    }

    final isLinked = info != null;
    final autoSignIn =
        prefs.getBool(_autoSignInKey(provider.providerId)) ??
        (isLinked ? true : false);
    final email = isLinked ? info.email : null;
    final displayName = isLinked ? info.displayName : null;
    accounts.add(
      LinkedAccountConnection(
        provider: provider,
        isLinked: isLinked,
        autoSignInEnabled: autoSignIn,
        email: email,
        displayName: displayName,
      ),
    );
  }

  return LinkedAccountsState(
    accounts: accounts,
    isAuthenticated: user != null,
    isAnonymous: user?.isAnonymous ?? false,
    linkedCount: accounts.where((item) => item.isLinked).length,
  );
}

String _autoSignInKey(String providerId) =>
    'profile.linked_accounts.autosignin.$providerId';

String _providerId(LinkedAccountProviderType providerType) {
  for (final provider in supportedLinkedAccountProviders) {
    if (provider.type == providerType) return provider.providerId;
  }
  throw StateError('Unsupported provider: $providerType');
}
