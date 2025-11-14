import 'package:app/features/profile/data/linked_accounts_repository.dart';
import 'package:app/features/profile/data/linked_accounts_repository_provider.dart';
import 'package:app/features/profile/domain/linked_account.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfileLinkedAccountsState {
  const ProfileLinkedAccountsState({
    required this.snapshot,
    this.autoSignInDrafts = const <String, bool>{},
    this.savingAccountIds = const <String>{},
    this.unlinkingAccountIds = const <String>{},
    this.linkingProviders = const <LinkedAccountProvider>{},
  });

  final LinkedAccountsSnapshot snapshot;
  final Map<String, bool> autoSignInDrafts;
  final Set<String> savingAccountIds;
  final Set<String> unlinkingAccountIds;
  final Set<LinkedAccountProvider> linkingProviders;

  bool get hasAccounts => snapshot.hasAccounts;

  bool hasDraft(String accountId) => autoSignInDrafts.containsKey(accountId);

  ProfileLinkedAccountsState copyWith({
    LinkedAccountsSnapshot? snapshot,
    Map<String, bool>? autoSignInDrafts,
    Set<String>? savingAccountIds,
    Set<String>? unlinkingAccountIds,
    Set<LinkedAccountProvider>? linkingProviders,
  }) {
    return ProfileLinkedAccountsState(
      snapshot: snapshot ?? this.snapshot,
      autoSignInDrafts: autoSignInDrafts ?? this.autoSignInDrafts,
      savingAccountIds: savingAccountIds ?? this.savingAccountIds,
      unlinkingAccountIds: unlinkingAccountIds ?? this.unlinkingAccountIds,
      linkingProviders: linkingProviders ?? this.linkingProviders,
    );
  }
}

class ProfileLinkedAccountsController
    extends AsyncNotifier<ProfileLinkedAccountsState> {
  LinkedAccountsRepository get _repository =>
      ref.read(linkedAccountsRepositoryProvider);

  @override
  Future<ProfileLinkedAccountsState> build() async {
    final snapshot = await _repository.fetch();
    return ProfileLinkedAccountsState(snapshot: snapshot);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    try {
      final snapshot = await _repository.fetch();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(ProfileLinkedAccountsState(snapshot: snapshot));
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  void updateAutoSignIn(String accountId, bool enabled) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final account = _findAccount(current, accountId);
    if (account == null) {
      return;
    }
    final drafts = Map<String, bool>.from(current.autoSignInDrafts);
    if (account.autoSignInEnabled == enabled) {
      drafts.remove(accountId);
    } else {
      drafts[accountId] = enabled;
    }
    state = AsyncData(current.copyWith(autoSignInDrafts: drafts));
  }

  Future<bool> saveAutoSignIn(String accountId) async {
    final current = state.asData?.value ?? await future;
    final pending = current.autoSignInDrafts[accountId];
    if (pending == null) {
      return false;
    }
    final saving = {...current.savingAccountIds, accountId};
    final savingState = current.copyWith(savingAccountIds: saving);
    state = AsyncData(savingState);
    try {
      final updated = await _repository.updateAutoSignIn(
        accountId: accountId,
        enabled: pending,
      );
      if (!ref.mounted) {
        return false;
      }
      final latest = state.asData?.value ?? savingState;
      final accounts = [
        for (final account in latest.snapshot.accounts)
          if (account.id == updated.id) updated else account,
      ];
      final snapshot = latest.snapshot.copyWith(
        accounts: accounts,
        updatedAt: DateTime.now(),
      );
      final drafts = Map<String, bool>.from(latest.autoSignInDrafts)
        ..remove(accountId);
      final remaining = {...latest.savingAccountIds}..remove(accountId);
      final resolved = latest.copyWith(
        snapshot: snapshot,
        autoSignInDrafts: drafts,
        savingAccountIds: remaining,
      );
      state = AsyncData(resolved);
      return true;
    } catch (error, stackTrace) {
      if (ref.mounted) {
        final remaining = {...saving}..remove(accountId);
        state = AsyncData(savingState.copyWith(savingAccountIds: remaining));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<bool> unlinkAccount(String accountId) async {
    final current = state.asData?.value ?? await future;
    if (_findAccount(current, accountId) == null) {
      return false;
    }
    final unlinking = {...current.unlinkingAccountIds, accountId};
    final pendingState = current.copyWith(unlinkingAccountIds: unlinking);
    state = AsyncData(pendingState);
    try {
      await _repository.unlink(accountId);
      if (!ref.mounted) {
        return false;
      }
      final latest = state.asData?.value ?? pendingState;
      final accounts = latest.snapshot.accounts
          .where((account) => account.id != accountId)
          .toList();
      final snapshot = latest.snapshot.copyWith(
        accounts: accounts,
        updatedAt: DateTime.now(),
      );
      final drafts = Map<String, bool>.from(latest.autoSignInDrafts)
        ..remove(accountId);
      final remaining = {...latest.unlinkingAccountIds}..remove(accountId);
      final resolved = latest.copyWith(
        snapshot: snapshot,
        autoSignInDrafts: drafts,
        unlinkingAccountIds: remaining,
      );
      state = AsyncData(resolved);
      return true;
    } catch (error, stackTrace) {
      if (ref.mounted) {
        final remaining = {...unlinking}..remove(accountId);
        state = AsyncData(
          pendingState.copyWith(unlinkingAccountIds: remaining),
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<LinkedAccount?> linkProvider(LinkedAccountProvider provider) async {
    final current = state.asData?.value ?? await future;
    if (!current.snapshot.availableProviders.contains(provider)) {
      return null;
    }
    final linking = {...current.linkingProviders, provider};
    final pendingState = current.copyWith(linkingProviders: linking);
    state = AsyncData(pendingState);
    try {
      final account = await _repository.link(provider);
      if (!ref.mounted) {
        return account;
      }
      final latest = state.asData?.value ?? pendingState;
      final accounts = [...latest.snapshot.accounts, account];
      final snapshot = latest.snapshot.copyWith(
        accounts: accounts,
        updatedAt: DateTime.now(),
      );
      final remaining = {...latest.linkingProviders}..remove(provider);
      final resolved = latest.copyWith(
        snapshot: snapshot,
        linkingProviders: remaining,
      );
      state = AsyncData(resolved);
      return account;
    } catch (error, stackTrace) {
      if (ref.mounted) {
        final remaining = {...linking}..remove(provider);
        state = AsyncData(pendingState.copyWith(linkingProviders: remaining));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  LinkedAccount? _findAccount(
    ProfileLinkedAccountsState state,
    String accountId,
  ) {
    for (final account in state.snapshot.accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }
}

final profileLinkedAccountsControllerProvider =
    AsyncNotifierProvider<
      ProfileLinkedAccountsController,
      ProfileLinkedAccountsState
    >(ProfileLinkedAccountsController.new);
