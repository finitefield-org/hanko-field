// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/routes.dart';
import 'package:app/features/profile/view_model/profile_linked_accounts_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:app/ui/feedback/app_skeleton.dart';
import 'package:app/ui/overlays/app_modal.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileLinkedAccountsPage extends ConsumerStatefulWidget {
  const ProfileLinkedAccountsPage({super.key});

  @override
  ConsumerState<ProfileLinkedAccountsPage> createState() =>
      _ProfileLinkedAccountsPageState();
}

class _ProfileLinkedAccountsPageState
    extends ConsumerState<ProfileLinkedAccountsPage> {
  List<LinkedAccountConnection>? _draft;
  bool _isDirty = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final router = GoRouter.of(context);

    final state = ref.watch(profileLinkedAccountsViewModel);
    final saveState = ref.watch(profileLinkedAccountsViewModel.saveMut);
    final linkState = ref.watch(profileLinkedAccountsViewModel.linkMut);
    final unlinkState = ref.watch(profileLinkedAccountsViewModel.unlinkMut);
    final refreshState = ref.watch(profileLinkedAccountsViewModel.refreshMut);
    final isBusy =
        saveState is PendingMutationState ||
        linkState is PendingMutationState ||
        unlinkState is PendingMutationState ||
        refreshState is PendingMutationState;

    final loaded = state.valueOrNull;
    if (loaded != null) {
      if (_draft == null || !_isDirty) {
        _draft = loaded.accounts;
        _isDirty = false;
      } else {
        final merged = _mergeLinkedStatus(_draft!, loaded.accounts);
        if (merged != _draft) {
          _draft = merged;
          _isDirty = _isDraftDirty(merged, loaded.accounts);
        }
      }
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: Text(l10n.profileLinkedAccountsTitle),
        actions: [
          IconButton(
            tooltip: l10n.profileLinkedAccountsAddTooltip,
            onPressed: isBusy || loaded?.isAuthenticated != true
                ? null
                : () => unawaited(_showLinkSheet(context, loaded!)),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
          SizedBox(width: tokens.spacing.sm),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.lg,
          ),
          child: _buildBody(
            context: context,
            theme: theme,
            tokens: tokens,
            l10n: l10n,
            state: state,
            loaded: loaded,
            isBusy: isBusy,
            canSave: _isDirty && !isBusy,
            onNavigateToAuth: () => router.go(AppRoutePaths.auth),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ThemeData theme,
    required DesignTokens tokens,
    required AppLocalizations l10n,
    required AsyncValue<LinkedAccountsState> state,
    required LinkedAccountsState? loaded,
    required bool isBusy,
    required bool canSave,
    required VoidCallback onNavigateToAuth,
  }) {
    if (state is AsyncLoading<LinkedAccountsState> && loaded == null) {
      return const AppListSkeleton(items: 3, itemHeight: 96);
    }

    if (state is AsyncError<LinkedAccountsState> && loaded == null) {
      return AppEmptyState(
        title: l10n.profileLinkedAccountsLoadFailedTitle,
        message: state.error.toString(),
        icon: Icons.link_off_outlined,
        actionLabel: l10n.profileRetry,
        onAction: () => ref.invalidate(profileLinkedAccountsViewModel),
      );
    }

    if (loaded == null) {
      return const SizedBox.shrink();
    }

    if (!loaded.isAuthenticated) {
      return AppEmptyState(
        title: l10n.profileLinkedAccountsSignedOutTitle,
        message: l10n.profileLinkedAccountsSignedOutBody,
        icon: Icons.person_off_outlined,
        actionLabel: l10n.profileLinkedAccountsSignIn,
        onAction: onNavigateToAuth,
      );
    }

    final accounts = _draft ?? loaded.accounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () async {
              try {
                await ref.invoke(profileLinkedAccountsViewModel.refresh());
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  l10n.profileLinkedAccountsHeader,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: tokens.spacing.md),
                _SecurityBanner(
                  l10n: l10n,
                  tokens: tokens,
                  onAction: () => unawaited(_showSecurityTips(context)),
                ),
                SizedBox(height: tokens.spacing.lg),
                for (final account in accounts) ...[
                  _LinkedAccountCard(
                    l10n: l10n,
                    tokens: tokens,
                    theme: theme,
                    account: account,
                    linkedCount: loaded.linkedCount,
                    isBusy: isBusy,
                    onAutoSignInChanged: (value) =>
                        _updateAutoSignIn(account.provider.type, value),
                    onUnlink: account.isLinked
                        ? () => unawaited(
                            _confirmUnlink(
                              context,
                              account.provider.type,
                              loaded,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: tokens.spacing.md),
                ],
                SizedBox(height: tokens.spacing.sm),
                Text(
                  l10n.profileLinkedAccountsFooter,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: tokens.spacing.lg),
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: canSave ? () => unawaited(_save(accounts)) : null,
            child: saveStateContent(
              context,
              tokens: tokens,
              isSaving:
                  ref.watch(profileLinkedAccountsViewModel.saveMut)
                      is PendingMutationState,
              label: l10n.profileLinkedAccountsSave,
            ),
          ),
        ),
      ],
    );
  }

  Widget saveStateContent(
    BuildContext context, {
    required DesignTokens tokens,
    required bool isSaving,
    required String label,
  }) {
    final theme = Theme.of(context);
    if (!isSaving) {
      return Text(label);
    }
    return SizedBox(
      width: tokens.spacing.md,
      height: tokens.spacing.md,
      child: CircularProgressIndicator.adaptive(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation(
          theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  void _updateAutoSignIn(LinkedAccountProviderType provider, bool enabled) {
    final current = _draft;
    if (current == null) return;
    final next = current
        .map(
          (item) => item.provider.type == provider
              ? item.copyWith(autoSignInEnabled: enabled)
              : item,
        )
        .toList();
    final loaded = ref.container
        .read(profileLinkedAccountsViewModel)
        .valueOrNull;
    setState(() {
      _draft = next;
      _isDirty = loaded == null ? true : _isDraftDirty(next, loaded.accounts);
    });
  }

  bool _isDraftDirty(
    List<LinkedAccountConnection> draft,
    List<LinkedAccountConnection> original,
  ) {
    if (draft.length != original.length) return true;
    final map = {for (final item in original) item.provider.type: item};
    for (final item in draft) {
      final base = map[item.provider.type];
      if (base == null) return true;
      if (base.autoSignInEnabled != item.autoSignInEnabled) return true;
    }
    return false;
  }

  List<LinkedAccountConnection> _mergeLinkedStatus(
    List<LinkedAccountConnection> draft,
    List<LinkedAccountConnection> loaded,
  ) {
    final next = [
      for (final account in loaded)
        _mergeEntry(account, draft, preferDraftAutoSignIn: true),
    ];
    final draftByProvider = {
      for (final account in draft) account.provider.type: account,
    };
    for (final updated in next) {
      final existing = draftByProvider[updated.provider.type];
      if (existing == null) return next;
      if (existing.isLinked != updated.isLinked ||
          existing.email != updated.email ||
          existing.displayName != updated.displayName) {
        return next;
      }
    }
    return draft;
  }

  LinkedAccountConnection _mergeEntry(
    LinkedAccountConnection loaded,
    List<LinkedAccountConnection> draft, {
    required bool preferDraftAutoSignIn,
  }) {
    final existing = draft.firstWhere(
      (item) => item.provider.type == loaded.provider.type,
      orElse: () => loaded,
    );
    return loaded.copyWith(
      autoSignInEnabled: preferDraftAutoSignIn
          ? existing.autoSignInEnabled
          : loaded.autoSignInEnabled,
    );
  }

  Future<void> _save(List<LinkedAccountConnection> accounts) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.invoke(profileLinkedAccountsViewModel.save(accounts));
      if (!mounted) return;
      setState(() => _isDirty = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileLinkedAccountsSaved)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileLinkedAccountsSaveFailed)),
      );
    }
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    LinkedAccountProviderType providerType,
    LinkedAccountsState state,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (state.linkedCount <= 1) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileLinkedAccountsUnlinkDisabled)),
      );
      return;
    }

    final confirmed = await showAppModal<bool>(
      context: context,
      title: l10n.profileLinkedAccountsUnlinkTitle,
      body: Text(l10n.profileLinkedAccountsUnlinkBody),
      primaryAction: l10n.profileLinkedAccountsUnlinkConfirm,
      secondaryAction: l10n.profileLinkedAccountsCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (!mounted || confirmed != true) return;
    try {
      await ref.invoke(profileLinkedAccountsViewModel.unlink(providerType));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileLinkedAccountsUnlinked)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileLinkedAccountsUnlinkFailed)),
      );
    }
  }

  Future<void> _showLinkSheet(
    BuildContext context,
    LinkedAccountsState state,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileLinkedAccountsLinkTitle,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            SizedBox(height: DesignTokensTheme.of(ctx).spacing.md),
            for (final account in state.accounts) ...[
              AppListTile(
                title: Text(_providerLabel(l10n, account.provider.type)),
                subtitle: Text(
                  account.isLinked
                      ? l10n.profileLinkedAccountsAlreadyLinked
                      : l10n.profileLinkedAccountsLinkSubtitle,
                ),
                leading: Icon(_providerIcon(account.provider.type)),
                trailing: account.isLinked
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                onTap: account.isLinked
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        unawaited(_linkProvider(account.provider.type));
                      },
              ),
              SizedBox(height: DesignTokensTheme.of(ctx).spacing.sm),
            ],
          ],
        );
      },
    );
  }

  Future<void> _linkProvider(LinkedAccountProviderType providerType) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.invoke(profileLinkedAccountsViewModel.link(providerType));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileLinkedAccountsLinked)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileLinkedAccountsLinkFailed)),
      );
    }
  }
}

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner({
    required this.l10n,
    required this.tokens,
    required this.onAction,
  });

  final AppLocalizations l10n;
  final DesignTokens tokens;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      padding: EdgeInsets.all(tokens.spacing.md),
      leading: const Icon(Icons.shield_outlined),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      content: Text(l10n.profileLinkedAccountsBannerBody),
      actions: [
        TextButton(
          onPressed: onAction,
          child: Text(l10n.profileLinkedAccountsBannerAction),
        ),
      ],
    );
  }
}

class _LinkedAccountCard extends StatelessWidget {
  const _LinkedAccountCard({
    required this.l10n,
    required this.tokens,
    required this.theme,
    required this.account,
    required this.linkedCount,
    required this.isBusy,
    required this.onAutoSignInChanged,
    required this.onUnlink,
  });

  final AppLocalizations l10n;
  final DesignTokens tokens;
  final ThemeData theme;
  final LinkedAccountConnection account;
  final int linkedCount;
  final bool isBusy;
  final ValueChanged<bool> onAutoSignInChanged;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    final canUnlink = account.isLinked && linkedCount > 1 && !isBusy;
    final statusText = account.isLinked
        ? l10n.profileLinkedAccountsConnected
        : l10n.profileLinkedAccountsNotConnected;
    final statusColor = account.isLinked
        ? theme.colorScheme.tertiary
        : theme.colorScheme.surfaceContainerHighest;
    final statusTextColor = account.isLinked
        ? theme.colorScheme.onTertiary
        : theme.colorScheme.onSurfaceVariant;

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  _providerIcon(account.provider.type),
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _providerLabel(l10n, account.provider.type),
                      style: theme.textTheme.titleMedium,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      account.displayName ??
                          account.email ??
                          l10n.profileLinkedAccountsProviderFallback,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(statusText),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: statusTextColor,
                ),
                backgroundColor: statusColor,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.profileLinkedAccountsAutoSignIn,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Switch.adaptive(
                value: account.autoSignInEnabled,
                onChanged: account.isLinked && !isBusy
                    ? onAutoSignInChanged
                    : null,
              ),
            ],
          ),
          if (!account.isLinked) ...[
            Text(
              l10n.profileLinkedAccountsNotConnectedHelper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (account.isLinked && linkedCount <= 1) ...[
            SizedBox(height: tokens.spacing.xs),
            Text(
              l10n.profileLinkedAccountsUnlinkDisabled,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: canUnlink ? onUnlink : null,
              child: Text(l10n.profileLinkedAccountsUnlink),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showSecurityTips(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppModal<void>(
    context: context,
    title: l10n.profileLinkedAccountsBannerTitle,
    body: Text(l10n.profileLinkedAccountsBannerBodyLong),
    primaryAction: l10n.profileLinkedAccountsOk,
    onPrimaryPressed: () => Navigator.of(context).maybePop(),
  );
}

String _providerLabel(AppLocalizations l10n, LinkedAccountProviderType type) {
  switch (type) {
    case LinkedAccountProviderType.apple:
      return l10n.authProviderApple;
    case LinkedAccountProviderType.google:
      return l10n.authProviderGoogle;
  }
}

IconData _providerIcon(LinkedAccountProviderType type) {
  switch (type) {
    case LinkedAccountProviderType.apple:
      return Icons.apple;
    case LinkedAccountProviderType.google:
      return Icons.g_mobiledata;
  }
}
