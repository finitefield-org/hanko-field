import 'dart:async';

import 'package:app/features/profile/domain/linked_account.dart';

abstract class LinkedAccountsRepository {
  Future<LinkedAccountsSnapshot> fetch();
  Future<LinkedAccount> updateAutoSignIn({
    required String accountId,
    required bool enabled,
  });
  Future<void> unlink(String accountId);
  Future<LinkedAccount> link(LinkedAccountProvider provider);
}

class FakeLinkedAccountsRepository implements LinkedAccountsRepository {
  FakeLinkedAccountsRepository({
    Duration latency = const Duration(milliseconds: 300),
  }) : _latency = latency,
       _accounts = _seedAccounts;

  final Duration _latency;
  List<LinkedAccount> _accounts;

  static List<LinkedAccount> get _seedAccounts {
    final now = DateTime.now();
    return [
      LinkedAccount(
        id: 'apple-primary',
        provider: LinkedAccountProvider.apple,
        status: LinkedAccountStatus.active,
        linkedAt: now.subtract(const Duration(days: 180)),
        lastUsedAt: now.subtract(const Duration(hours: 8)),
        detail: 'ryoko@icloud.com',
        autoSignInEnabled: true,
        isPrimary: true,
      ),
      LinkedAccount(
        id: 'google-studio',
        provider: LinkedAccountProvider.google,
        status: LinkedAccountStatus.active,
        linkedAt: now.subtract(const Duration(days: 60)),
        lastUsedAt: now.subtract(const Duration(days: 1, hours: 2)),
        detail: 'studio@hanko.app',
        autoSignInEnabled: false,
      ),
      LinkedAccount(
        id: 'email-safety',
        provider: LinkedAccountProvider.email,
        status: LinkedAccountStatus.actionRequired,
        linkedAt: now.subtract(const Duration(days: 320)),
        lastUsedAt: now.subtract(const Duration(days: 40)),
        detail: 'support+03@hanko.app',
        autoSignInEnabled: true,
      ),
    ];
  }

  @override
  Future<LinkedAccountsSnapshot> fetch() async {
    await Future.delayed(_latency);
    return LinkedAccountsSnapshot(
      accounts: _accounts,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<LinkedAccount> updateAutoSignIn({
    required String accountId,
    required bool enabled,
  }) async {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      throw StateError('Account $accountId not found');
    }
    final updated = _accounts[index].copyWith(autoSignInEnabled: enabled);
    await Future.delayed(_latency * 4 ~/ 3);
    _accounts = [..._accounts]..[index] = updated;
    return updated;
  }

  @override
  Future<void> unlink(String accountId) async {
    final next = _accounts.where((account) => account.id != accountId).toList();
    await Future.delayed(_latency * 2);
    _accounts = next;
  }

  @override
  Future<LinkedAccount> link(LinkedAccountProvider provider) async {
    final now = DateTime.now();
    final account = LinkedAccount(
      id: '${provider.name}-${now.microsecondsSinceEpoch}',
      provider: provider,
      status: LinkedAccountStatus.pending,
      linkedAt: now,
      detail: _defaultDetail(provider, now),
      autoSignInEnabled: true,
    );
    await Future.delayed(_latency * 2);
    _accounts = [..._accounts, account];
    return account;
  }

  String _defaultDetail(LinkedAccountProvider provider, DateTime now) {
    final suffix = now.millisecondsSinceEpoch.remainder(1000).toString();
    return switch (provider) {
      LinkedAccountProvider.apple => 'id+$suffix@icloud.com',
      LinkedAccountProvider.google => 'studio+$suffix@hanko.app',
      LinkedAccountProvider.email => 'user+$suffix@hanko.app',
      LinkedAccountProvider.line => 'line:$suffix',
    };
  }
}
