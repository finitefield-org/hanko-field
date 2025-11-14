import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/features/profile/application/profile_linked_accounts_controller.dart';
import 'package:app/features/profile/domain/linked_account.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProfileLinkedAccountsScreen extends ConsumerStatefulWidget {
  const ProfileLinkedAccountsScreen({super.key});

  @override
  ConsumerState<ProfileLinkedAccountsScreen> createState() =>
      _ProfileLinkedAccountsScreenState();
}

class _ProfileLinkedAccountsScreenState
    extends ConsumerState<ProfileLinkedAccountsScreen> {
  ProfileLinkedAccountsController get _controller =>
      ref.read(profileLinkedAccountsControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(profileLinkedAccountsControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.profileLinkedAccountsTitle),
        actions: [
          asyncState.maybeWhen(
            data: (state) {
              final disabled =
                  state.snapshot.availableProviders.isEmpty ||
                  state.linkingProviders.isNotEmpty;
              return IconButton(
                tooltip: l10n.profileLinkedAccountsAddTooltip,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                onPressed: disabled ? null : () => _handleAddAccount(state),
              );
            },
            orElse: () => IconButton(
              tooltip: l10n.profileLinkedAccountsAddTooltip,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _LinkedAccountsErrorView(
            message: error.toString(),
            onRetry: _controller.reload,
            l10n: l10n,
          ),
          data: (state) => RefreshIndicator(
            onRefresh: _controller.reload,
            edgeOffset: AppTokens.spaceL,
            displacement: AppTokens.spaceXL,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.spaceL,
                      AppTokens.spaceL,
                      AppTokens.spaceL,
                      AppTokens.spaceS,
                    ),
                    child: _SecurityBanner(
                      l10n: l10n,
                      onAction: () => _showSecurityTips(l10n),
                    ),
                  ),
                ),
                if (!state.hasAccounts)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyLinkedAccountsView(
                      l10n: l10n,
                      onAdd: state.snapshot.availableProviders.isEmpty
                          ? null
                          : () => _handleAddAccount(state),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.spaceL,
                      AppTokens.spaceM,
                      AppTokens.spaceL,
                      AppTokens.spaceXL,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final account = state.snapshot.accounts[index];
                        final isSaving = state.savingAccountIds.contains(
                          account.id,
                        );
                        final isUnlinking = state.unlinkingAccountIds.contains(
                          account.id,
                        );
                        final hasDraft = state.autoSignInDrafts[account.id];
                        final autoSignInValue =
                            hasDraft ?? account.autoSignInEnabled;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == state.snapshot.accounts.length - 1
                                ? 0
                                : AppTokens.spaceM,
                          ),
                          child: _LinkedAccountCard(
                            account: account,
                            l10n: l10n,
                            autoSignInValue: autoSignInValue,
                            hasPendingChange: hasDraft != null,
                            isSaving: isSaving,
                            isUnlinking: isUnlinking,
                            onToggleAutoSignIn: (value) =>
                                _controller.updateAutoSignIn(account.id, value),
                            onSave: () => _handleSave(account),
                            onUnlink: () => _handleUnlink(account),
                          ),
                        );
                      }, childCount: state.snapshot.accounts.length),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave(LinkedAccount account) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await _controller.saveAutoSignIn(account.id);
      if (!mounted || !saved) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.profileLinkedAccountsSaveSuccess)),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.profileLinkedAccountsSaveError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  Future<void> _handleUnlink(LinkedAccount account) async {
    final confirmed = await _confirmUnlink(account);
    if (!confirmed || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final providerName = _providerLabel(account.provider, l10n);
    try {
      final removed = await _controller.unlinkAccount(account.id);
      if (!mounted || !removed) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.profileLinkedAccountsUnlinkSuccess(providerName),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.profileLinkedAccountsUnlinkError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  Future<bool> _confirmUnlink(LinkedAccount account) async {
    final l10n = AppLocalizations.of(context);
    final providerName = _providerLabel(account.provider, l10n);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileLinkedAccountsUnlinkConfirmTitle),
        content: Text(
          l10n.profileLinkedAccountsUnlinkConfirmBody(providerName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.profileLinkedAccountsUnlinkCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.profileLinkedAccountsUnlinkConfirmAction),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  Future<void> _handleAddAccount(ProfileLinkedAccountsState state) async {
    final l10n = AppLocalizations.of(context);
    final provider = await showModalBottomSheet<LinkedAccountProvider>(
      context: context,
      builder: (context) => _LinkProviderSheet(
        providers: state.snapshot.availableProviders,
        l10n: l10n,
      ),
    );
    if (!mounted || provider == null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final providerName = _providerLabel(provider, l10n);
    try {
      final linked = await _controller.linkProvider(provider);
      if (!mounted || linked == null) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.profileLinkedAccountsLinkSuccess(providerName)),
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.profileLinkedAccountsLinkError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  void _showSecurityTips(AppLocalizations l10n) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.profileLinkedAccountsSecurityBody)),
      );
  }
}

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner({required this.l10n, required this.onAction});

  final AppLocalizations l10n;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MaterialBanner(
      backgroundColor: scheme.secondaryContainer,
      leading: CircleAvatar(
        backgroundColor: scheme.onSecondaryContainer.withValues(alpha: 0.1),
        child: Icon(
          Icons.security_outlined,
          color: scheme.onSecondaryContainer,
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.profileLinkedAccountsSecurityTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            l10n.profileLinkedAccountsSecurityBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onAction,
          child: Text(l10n.profileLinkedAccountsSecurityAction),
        ),
      ],
    );
  }
}

class _LinkedAccountCard extends StatelessWidget {
  const _LinkedAccountCard({
    required this.account,
    required this.l10n,
    required this.autoSignInValue,
    required this.hasPendingChange,
    required this.isSaving,
    required this.isUnlinking,
    required this.onToggleAutoSignIn,
    required this.onSave,
    required this.onUnlink,
  });

  final LinkedAccount account;
  final AppLocalizations l10n;
  final bool autoSignInValue;
  final bool hasPendingChange;
  final bool isSaving;
  final bool isUnlinking;
  final ValueChanged<bool> onToggleAutoSignIn;
  final VoidCallback onSave;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _statusLabel(account.status, l10n);
    final statusColor = _statusColor(account.status, scheme);
    final formatter = DateFormat.yMMMd(l10n.localeName);
    final linkedAtLabel = l10n.profileLinkedAccountsLinkedAt(
      formatter.format(account.linkedAt),
    );
    final lastUsedLabel = account.lastUsedAt == null
        ? null
        : l10n.profileLinkedAccountsLastUsed(
            formatter.format(account.lastUsedAt!),
          );
    final providerLabel = _providerLabel(account.provider, l10n);
    final detail = account.detail;
    final disabled = isSaving || isUnlinking;

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Icon(
                  _providerIcon(account.provider),
                  color: scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppTokens.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                        child: Text(
                          detail,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                      child: Chip(
                        label: Text(status),
                        avatar: Icon(
                          _statusIcon(account.status),
                          size: 18,
                          color: statusColor,
                        ),
                        backgroundColor: statusColor.withValues(alpha: 0.1),
                        labelStyle: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: statusColor),
                        side: BorderSide(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceM),
          Text(
            linkedAtLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (lastUsedLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceXS),
              child: Text(
                lastUsedLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceM),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.profileLinkedAccountsAutoSignInLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppTokens.spaceXS),
                      Text(
                        l10n.profileLinkedAccountsAutoSignInDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (hasPendingChange)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTokens.spaceS),
                          child: Text(
                            l10n.profileLinkedAccountsPendingChangesLabel,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: scheme.secondary),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: autoSignInValue,
                  onChanged: disabled ? null : onToggleAutoSignIn,
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: disabled ? null : onUnlink,
                child: Text(l10n.profileLinkedAccountsUnlinkAction),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: disabled || !hasPendingChange ? null : onSave,
                child: isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.profileLinkedAccountsSaveAction),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(LinkedAccountStatus status, AppLocalizations l10n) {
    return switch (status) {
      LinkedAccountStatus.active => l10n.profileLinkedAccountsStatusActive,
      LinkedAccountStatus.pending => l10n.profileLinkedAccountsStatusPending,
      LinkedAccountStatus.revoked => l10n.profileLinkedAccountsStatusRevoked,
      LinkedAccountStatus.actionRequired =>
        l10n.profileLinkedAccountsStatusActionRequired,
    };
  }

  IconData _statusIcon(LinkedAccountStatus status) {
    return switch (status) {
      LinkedAccountStatus.active => Icons.check_circle_outline,
      LinkedAccountStatus.pending => Icons.hourglass_bottom,
      LinkedAccountStatus.revoked => Icons.block,
      LinkedAccountStatus.actionRequired => Icons.warning_amber_outlined,
    };
  }

  Color _statusColor(LinkedAccountStatus status, ColorScheme scheme) {
    return switch (status) {
      LinkedAccountStatus.active => scheme.primary,
      LinkedAccountStatus.pending => scheme.tertiary,
      LinkedAccountStatus.revoked => scheme.outline,
      LinkedAccountStatus.actionRequired => scheme.error,
    };
  }

  IconData _providerIcon(LinkedAccountProvider provider) {
    return switch (provider) {
      LinkedAccountProvider.apple => Icons.apple,
      LinkedAccountProvider.google => Icons.android,
      LinkedAccountProvider.email => Icons.mail_outline,
      LinkedAccountProvider.line => Icons.chat_bubble_outline,
    };
  }
}

class _EmptyLinkedAccountsView extends StatelessWidget {
  const _EmptyLinkedAccountsView({required this.l10n, required this.onAdd});

  final AppLocalizations l10n;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.key_outlined,
            size: 48,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(height: AppTokens.spaceM),
          Text(
            l10n.profileLinkedAccountsEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            l10n.profileLinkedAccountsEmptyBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceM),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: Text(l10n.profileLinkedAccountsEmptyAction),
          ),
        ],
      ),
    );
  }
}

class _LinkedAccountsErrorView extends StatelessWidget {
  const _LinkedAccountsErrorView({
    required this.message,
    required this.onRetry,
    required this.l10n,
  });

  final String message;
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.profileLinkedAccountsLoadError,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceL),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.profileLinkedAccountsRetryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkProviderSheet extends StatelessWidget {
  const _LinkProviderSheet({required this.providers, required this.l10n});

  final List<LinkedAccountProvider> providers;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileLinkedAccountsAddSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceXS),
            Text(
              l10n.profileLinkedAccountsAddSheetSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTokens.spaceM),
            for (final provider in providers)
              ListTile(
                leading: Icon(_providerIcon(provider)),
                title: Text(_providerLabel(provider, l10n)),
                onTap: () => Navigator.of(context).pop(provider),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _providerIcon(LinkedAccountProvider provider) {
    return switch (provider) {
      LinkedAccountProvider.apple => Icons.apple,
      LinkedAccountProvider.google => Icons.android,
      LinkedAccountProvider.email => Icons.mail_outline,
      LinkedAccountProvider.line => Icons.chat_bubble_outline,
    };
  }
}

String _providerLabel(LinkedAccountProvider provider, AppLocalizations l10n) {
  return switch (provider) {
    LinkedAccountProvider.apple => l10n.profileLinkedAccountsProviderApple,
    LinkedAccountProvider.google => l10n.profileLinkedAccountsProviderGoogle,
    LinkedAccountProvider.email => l10n.profileLinkedAccountsProviderEmail,
    LinkedAccountProvider.line => l10n.profileLinkedAccountsProviderLine,
  };
}
