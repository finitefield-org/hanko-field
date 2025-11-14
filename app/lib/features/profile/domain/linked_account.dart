import 'package:flutter/foundation.dart';

/// 利用可能な連携サービス
enum LinkedAccountProvider { apple, google, email, line }

extension LinkedAccountProviderX on LinkedAccountProvider {
  /// Firebase Auth provider ID 互換の識別子
  String get providerId => switch (this) {
    LinkedAccountProvider.apple => 'apple.com',
    LinkedAccountProvider.google => 'google.com',
    LinkedAccountProvider.email => 'password',
    LinkedAccountProvider.line => 'line.me',
  };
}

/// 連携状態
enum LinkedAccountStatus { active, pending, revoked, actionRequired }

@immutable
class LinkedAccount {
  const LinkedAccount({
    required this.id,
    required this.provider,
    required this.status,
    required this.linkedAt,
    this.detail,
    this.lastUsedAt,
    this.autoSignInEnabled = true,
    this.isPrimary = false,
  });

  final String id;
  final LinkedAccountProvider provider;
  final LinkedAccountStatus status;
  final DateTime linkedAt;
  final String? detail;
  final DateTime? lastUsedAt;
  final bool autoSignInEnabled;
  final bool isPrimary;

  LinkedAccount copyWith({
    LinkedAccountProvider? provider,
    LinkedAccountStatus? status,
    DateTime? linkedAt,
    String? detail,
    DateTime? lastUsedAt,
    bool? autoSignInEnabled,
    bool? isPrimary,
  }) {
    return LinkedAccount(
      id: id,
      provider: provider ?? this.provider,
      status: status ?? this.status,
      linkedAt: linkedAt ?? this.linkedAt,
      detail: detail ?? this.detail,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      autoSignInEnabled: autoSignInEnabled ?? this.autoSignInEnabled,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LinkedAccount &&
        other.id == id &&
        other.provider == provider &&
        other.status == status &&
        other.linkedAt == linkedAt &&
        other.detail == detail &&
        other.lastUsedAt == lastUsedAt &&
        other.autoSignInEnabled == autoSignInEnabled &&
        other.isPrimary == isPrimary;
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    status,
    linkedAt,
    detail,
    lastUsedAt,
    autoSignInEnabled,
    isPrimary,
  );
}

@immutable
class LinkedAccountsSnapshot {
  LinkedAccountsSnapshot({
    required List<LinkedAccount> accounts,
    required this.updatedAt,
  }) : accounts = List.unmodifiable(accounts);

  final List<LinkedAccount> accounts;
  final DateTime updatedAt;

  bool get hasAccounts => accounts.isNotEmpty;

  LinkedAccountsSnapshot copyWith({
    List<LinkedAccount>? accounts,
    DateTime? updatedAt,
  }) {
    return LinkedAccountsSnapshot(
      accounts: accounts ?? this.accounts,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  List<LinkedAccountProvider> get availableProviders {
    final used = {for (final account in accounts) account.provider};
    return [
      for (final provider in LinkedAccountProvider.values)
        if (!used.contains(provider)) provider,
    ];
  }
}
