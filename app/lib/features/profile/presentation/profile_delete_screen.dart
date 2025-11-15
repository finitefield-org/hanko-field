import 'dart:async';

import 'package:app/core/domain/entities/account_deletion.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/features/profile/application/profile_delete_controller.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProfileDeleteScreen extends ConsumerStatefulWidget {
  const ProfileDeleteScreen({super.key});

  @override
  ConsumerState<ProfileDeleteScreen> createState() =>
      _ProfileDeleteScreenState();
}

class _ProfileDeleteScreenState extends ConsumerState<ProfileDeleteScreen> {
  late final TextEditingController _feedbackController;

  @override
  void initState() {
    super.initState();
    _feedbackController = TextEditingController();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(profileDeleteControllerProvider);
    final controller = ref.read(profileDeleteControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProfileDeleteError(
          l10n: l10n,
          onRetry: () {
            ref.invalidate(profileDeleteControllerProvider);
          },
        ),
        data: (state) => _ProfileDeleteBody(
          state: state,
          l10n: l10n,
          feedbackController: _feedbackController,
          onToggleAcknowledgement: controller.toggleAcknowledgement,
        ),
      ),
      bottomNavigationBar: asyncState.whenOrNull(
        data: (state) => _ProfileDeleteActions(
          state: state,
          l10n: l10n,
          onSubmit: () => _handleSubmit(context, controller, state, l10n),
          onCancel: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }

  Future<void> _handleSubmit(
    BuildContext context,
    ProfileDeleteController controller,
    ProfileDeleteState state,
    AppLocalizations l10n,
  ) async {
    if (!state.isChecklistComplete || state.isSubmitting) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return _DeleteConfirmDialog(l10n: l10n, isBusy: state.isSubmitting);
          },
        ) ??
        false;
    if (!mounted) {
      return;
    }
    if (!confirmed) {
      return;
    }

    try {
      await controller.submitDeletion(feedback: _feedbackController.text);
      if (mounted) {
        _feedbackController.clear();
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.profileDeleteSubmitSuccess)),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.profileDeleteSubmitError),
            backgroundColor: errorColor,
          ),
        );
    }
  }
}

class _ProfileDeleteBody extends StatelessWidget {
  const _ProfileDeleteBody({
    required this.state,
    required this.l10n,
    required this.feedbackController,
    required this.onToggleAcknowledgement,
  });

  final ProfileDeleteState state;
  final AppLocalizations l10n;
  final TextEditingController feedbackController;
  final void Function(AccountDeletionAcknowledgement, bool)
  onToggleAcknowledgement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar.medium(
          pinned: true,
          centerTitle: true,
          backgroundColor: scheme.errorContainer,
          foregroundColor: scheme.onErrorContainer,
          title: Text(l10n.profileDeleteTitle),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceXXL,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileDeleteSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceL),
                _WarningCard(l10n: l10n),
                if (state.lastSubmittedAt != null) ...[
                  const SizedBox(height: AppTokens.spaceM),
                  _PreviousRequestCard(
                    timestamp: state.lastSubmittedAt!,
                    l10n: l10n,
                  ),
                ],
                const SizedBox(height: AppTokens.spaceL),
                Text(
                  l10n.profileDeleteChecklistTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                for (final acknowledgement in _acknowledgements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
                    child: _AcknowledgementTile(
                      definition: acknowledgement,
                      isSelected: state.acknowledgements.contains(
                        acknowledgement.type,
                      ),
                      onChanged: (value) =>
                          onToggleAcknowledgement(acknowledgement.type, value),
                      enabled: !state.isSubmitting,
                    ),
                  ),
                const SizedBox(height: AppTokens.spaceL),
                Text(
                  l10n.profileDeleteFeedbackLabel,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                TextField(
                  controller: feedbackController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: l10n.profileDeleteFeedbackHint,
                    helperText: l10n.profileDeleteFeedbackHelper,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.newline,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileDeleteActions extends StatelessWidget {
  const _ProfileDeleteActions({
    required this.state,
    required this.l10n,
    required this.onSubmit,
    required this.onCancel,
  });

  final ProfileDeleteState state;
  final AppLocalizations l10n;
  final Future<void> Function() onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSubmit = state.isChecklistComplete && !state.isSubmitting;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceL,
          AppTokens.spaceS,
          AppTokens.spaceL,
          AppTokens.spaceL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: canSubmit
                  ? () {
                      unawaited(onSubmit());
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: state.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.profileDeleteSubmitCta),
            ),
            TextButton(
              onPressed: state.isSubmitting ? null : onCancel,
              child: Text(l10n.profileDeleteCancelLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      variant: AppCardVariant.outlined,
      borderColor: scheme.error,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error, size: 32),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileDeleteWarningTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  l10n.profileDeleteWarningBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviousRequestCard extends StatelessWidget {
  const _PreviousRequestCard({required this.timestamp, required this.l10n});

  final DateTime timestamp;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatter = DateFormat.yMMMMd(l10n.localeName).add_Hm();
    final label = l10n.profileDeleteLastRequestedLabel(
      formatter.format(timestamp),
    );
    return AppCard(
      variant: AppCardVariant.filled,
      backgroundColor: scheme.surfaceContainerHigh,
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom_outlined, color: scheme.primary),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _AcknowledgementTile extends StatelessWidget {
  const _AcknowledgementTile({
    required this.definition,
    required this.isSelected,
    required this.onChanged,
    required this.enabled,
  });

  final _AcknowledgementDefinition definition;
  final bool isSelected;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: EdgeInsets.zero,
      child: CheckboxListTile(
        value: isSelected,
        onChanged: enabled ? (value) => onChanged(value ?? false) : null,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          definition.titleBuilder(AppLocalizations.of(context)),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          definition.subtitleBuilder(AppLocalizations.of(context)),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceL,
          vertical: AppTokens.spaceM,
        ),
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.l10n, required this.isBusy});

  final AppLocalizations l10n;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.profileDeleteConfirmDialogTitle),
      content: Text(l10n.profileDeleteConfirmDialogBody),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.profileDeleteConfirmSecondary),
        ),
        FilledButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: Text(l10n.profileDeleteConfirmPrimary),
        ),
      ],
    );
  }
}

class _ProfileDeleteError extends StatelessWidget {
  const _ProfileDeleteError({required this.l10n, required this.onRetry});

  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.profileDeleteSubmitError,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.profileDeleteRetryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcknowledgementDefinition {
  _AcknowledgementDefinition({
    required this.type,
    required this.titleBuilder,
    required this.subtitleBuilder,
  });

  final AccountDeletionAcknowledgement type;
  final String Function(AppLocalizations) titleBuilder;
  final String Function(AppLocalizations) subtitleBuilder;
}

final List<_AcknowledgementDefinition> _acknowledgements = [
  _AcknowledgementDefinition(
    type: AccountDeletionAcknowledgement.dataErasure,
    titleBuilder: (l10n) => l10n.profileDeleteAckDataTitle,
    subtitleBuilder: (l10n) => l10n.profileDeleteAckDataSubtitle,
  ),
  _AcknowledgementDefinition(
    type: AccountDeletionAcknowledgement.outstandingOrders,
    titleBuilder: (l10n) => l10n.profileDeleteAckOrdersTitle,
    subtitleBuilder: (l10n) => l10n.profileDeleteAckOrdersSubtitle,
  ),
  _AcknowledgementDefinition(
    type: AccountDeletionAcknowledgement.exportConfirmed,
    titleBuilder: (l10n) => l10n.profileDeleteAckExportTitle,
    subtitleBuilder: (l10n) => l10n.profileDeleteAckExportSubtitle,
  ),
];
