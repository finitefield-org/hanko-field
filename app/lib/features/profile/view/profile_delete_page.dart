// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/profile/view_model/profile_delete_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:app/ui/overlays/app_modal.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileDeletePage extends ConsumerStatefulWidget {
  const ProfileDeletePage({super.key});

  @override
  ConsumerState<ProfileDeletePage> createState() => _ProfileDeletePageState();
}

class _ProfileDeletePageState extends ConsumerState<ProfileDeletePage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final deleteState = ref.watch(profileDeleteViewModel);

    Widget body;
    switch (deleteState) {
      case AsyncData(:final value):
        body = _DeleteBody(
          state: value,
          onToggle: (acknowledgement, value) => ref.invoke(
            profileDeleteViewModel.toggleAcknowledgement(
              acknowledgement,
              value ?? false,
            ),
          ),
        );
      case AsyncLoading():
        body = const Center(child: CircularProgressIndicator());
      case AsyncError():
        body = AppEmptyState(
          title: l10n.profileDeleteErrorTitle,
          message: l10n.profileDeleteErrorBody,
          icon: Icons.delete_outline,
          actionLabel: l10n.profileDeleteRetry,
          onAction: () => ref.invalidate(profileDeleteViewModel),
        );
    }

    Widget? bottomBar;
    if (deleteState case AsyncData(:final value)) {
      bottomBar = _DeleteActions(
        state: value,
        onDelete: () => _confirmAndDelete(value),
        onCancel: value.isDeleting ? null : () => context.pop(),
      );
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            leading: const BackButton(),
            backgroundColor: tokens.colors.error,
            foregroundColor: tokens.colors.onError,
            title: Text(l10n.profileDeleteTitle),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.sm,
              tokens.spacing.lg,
              tokens.spacing.xxl,
            ),
            sliver: SliverToBoxAdapter(child: body),
          ),
        ],
      ),
      bottomNavigationBar: bottomBar,
    );
  }

  Future<void> _confirmAndDelete(ProfileDeleteState state) async {
    final l10n = AppLocalizations.of(context);
    if (!state.canDelete || state.isDeleting) return;

    final confirmed = await showAppModal<bool>(
      context: context,
      title: l10n.profileDeleteConfirmTitle,
      body: Text(l10n.profileDeleteConfirmBody),
      primaryAction: l10n.profileDeleteConfirmAction,
      secondaryAction: l10n.profileDeleteConfirmCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
      barrierDismissible: false,
    );

    if (confirmed != true) return;

    try {
      await ref.invoke(profileDeleteViewModel.deleteAccount());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileDeleteSuccess)));
      context.go(AppRoutePaths.auth);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileDeleteError)));
    }
  }
}

class _DeleteBody extends StatelessWidget {
  const _DeleteBody({required this.state, required this.onToggle});

  final ProfileDeleteState state;
  final void Function(ProfileDeleteAcknowledgement, bool?) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);

    final acknowledgements = [
      _DeleteAcknowledgement(
        acknowledgement: ProfileDeleteAcknowledgement.dataLoss,
        title: l10n.profileDeleteAckDataLossTitle,
        body: l10n.profileDeleteAckDataLossBody,
      ),
      _DeleteAcknowledgement(
        acknowledgement: ProfileDeleteAcknowledgement.openOrders,
        title: l10n.profileDeleteAckOrdersTitle,
        body: l10n.profileDeleteAckOrdersBody,
      ),
      _DeleteAcknowledgement(
        acknowledgement: ProfileDeleteAcknowledgement.irreversible,
        title: l10n.profileDeleteAckIrreversibleTitle,
        body: l10n.profileDeleteAckIrreversibleBody,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WarningCard(
          title: l10n.profileDeleteWarningTitle,
          body: l10n.profileDeleteWarningBody,
        ),
        SizedBox(height: tokens.spacing.lg),
        Text(
          l10n.profileDeleteAcknowledgementTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.md),
        ...acknowledgements.map((ack) {
          return Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.sm),
            child: _AcknowledgementTile(
              acknowledgement: ack,
              value: _ackValue(state, ack.acknowledgement),
              onChanged: state.isDeleting
                  ? null
                  : (value) => onToggle(ack.acknowledgement, value),
            ),
          );
        }),
        SizedBox(height: tokens.spacing.md),
        Text(
          l10n.profileDeleteFooterNote,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

bool _ackValue(ProfileDeleteState state, ProfileDeleteAcknowledgement ack) {
  switch (ack) {
    case ProfileDeleteAcknowledgement.dataLoss:
      return state.confirmDataLoss;
    case ProfileDeleteAcknowledgement.openOrders:
      return state.confirmOpenOrders;
    case ProfileDeleteAcknowledgement.irreversible:
      return state.confirmIrreversible;
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final warningBg = tokens.colors.error.withValues(alpha: 0.08);

    return AppCard(
      backgroundColor: warningBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: tokens.colors.error),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcknowledgementTile extends StatelessWidget {
  const _AcknowledgementTile({
    required this.acknowledgement,
    required this.value,
    required this.onChanged,
  });

  final _DeleteAcknowledgement acknowledgement;
  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: tokens.colors.error,
          ),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acknowledgement.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  acknowledgement.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAcknowledgement {
  const _DeleteAcknowledgement({
    required this.acknowledgement,
    required this.title,
    required this.body,
  });

  final ProfileDeleteAcknowledgement acknowledgement;
  final String title;
  final String body;
}

class _DeleteActions extends StatelessWidget {
  const _DeleteActions({
    required this.state,
    required this.onDelete,
    required this.onCancel,
  });

  final ProfileDeleteState state;
  final VoidCallback onDelete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.sm,
          tokens.spacing.lg,
          tokens.spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: state.isDeleting || !state.canDelete ? null : onDelete,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.colors.error,
                foregroundColor: tokens.colors.onError,
                minimumSize: const Size.fromHeight(48),
              ),
              child: state.isDeleting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          tokens.colors.onError,
                        ),
                      ),
                    )
                  : Text(l10n.profileDeleteCta),
            ),
            SizedBox(height: tokens.spacing.sm),
            TextButton(
              onPressed: onCancel,
              child: Text(l10n.profileDeleteCancelCta),
            ),
          ],
        ),
      ),
    );
  }
}
