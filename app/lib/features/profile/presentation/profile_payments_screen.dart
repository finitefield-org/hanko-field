import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/checkout_payment_controller.dart';
import 'package:app/features/cart/domain/checkout_payment_models.dart';
import 'package:app/features/payments/presentation/tokenized_payment_method_form.dart';
import 'package:app/features/payments/presentation/widgets/payment_method_tile.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentMethodTokenProvider = FutureProvider.family<String?, String>((
  ref,
  methodId,
) {
  final controller = ref.watch(checkoutPaymentControllerProvider.notifier);
  return controller.readToken(methodId);
});

class ProfilePaymentsScreen extends ConsumerStatefulWidget {
  const ProfilePaymentsScreen({super.key});

  @override
  ConsumerState<ProfilePaymentsScreen> createState() =>
      _ProfilePaymentsScreenState();
}

class _ProfilePaymentsScreenState extends ConsumerState<ProfilePaymentsScreen> {
  late final ScrollController _scrollController;

  CheckoutPaymentController get _controller =>
      ref.read(checkoutPaymentControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    ref.listen<AsyncValue<CheckoutPaymentState>>(
      checkoutPaymentControllerProvider,
      (previous, next) {
        final prevState = previous?.value;
        final nextState = next.value;
        if (!mounted || nextState == null) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        if (nextState.feedbackMessage != null &&
            nextState.feedbackMessage != prevState?.feedbackMessage) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(nextState.feedbackMessage!)));
          _controller.clearMessages();
        } else if (nextState.errorMessage != null &&
            nextState.errorMessage != prevState?.errorMessage) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(nextState.errorMessage!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          _controller.clearMessages();
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final experienceAsync = ref.watch(experienceGateProvider);
    final experience = experienceAsync.value;
    final isInternational = experience?.isInternational ?? false;
    final asyncState = ref.watch(checkoutPaymentControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profilePaymentsTitle),
        actions: [
          asyncState.maybeWhen(
            data: (state) {
              final disabled =
                  state.isProcessing ||
                  state.isAdding ||
                  !state.canAddNewMethod;
              return IconButton(
                tooltip: l10n.profilePaymentsAddTooltip,
                onPressed: disabled
                    ? null
                    : () => _openAddMethod(state, experience, l10n),
                icon: const Icon(Icons.add_card_outlined),
              );
            },
            orElse: () => IconButton(
              tooltip: l10n.profilePaymentsAddTooltip,
              onPressed: null,
              icon: const Icon(Icons.add_card_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ProfilePaymentsErrorView(
            message: error.toString(),
            onRetry: _controller.refresh,
            l10n: l10n,
          ),
          data: (state) => RefreshIndicator(
            onRefresh: _controller.refresh,
            child: CustomScrollView(
              controller: _scrollController,
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
                    child: _PaymentsSecurityCard(
                      l10n: l10n,
                      isInternational: isInternational,
                      onNavigate: _handleSecurityLink,
                    ),
                  ),
                ),
                if (state.isProcessing)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (!state.hasMethods)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyPaymentsView(
                      l10n: l10n,
                      onAdd: state.canAddNewMethod
                          ? () => _openAddMethod(state, experience, l10n)
                          : null,
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
                        final method = state.methods[index];
                        final isRemoving = state.removingMethodIds.contains(
                          method.id,
                        );
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == state.methods.length - 1
                                ? 0
                                : AppTokens.spaceM,
                          ),
                          child: _ProfilePaymentMethodTile(
                            method: method,
                            isInternational: isInternational,
                            selectedMethodId: state.selectedMethodId,
                            l10n: l10n,
                            isRemoving: isRemoving,
                            disabled: isRemoving,
                            defaultBadgeLabel: l10n.profilePaymentsDefaultBadge,
                            onSelect: _controller.selectMethod,
                            onRemove: () async {
                              final confirmed = await _confirmRemoval(
                                method,
                                l10n,
                              );
                              if (confirmed && mounted) {
                                await _controller.removeMethod(method.id);
                              }
                            },
                            removeDisabled: state.isProcessing || isRemoving,
                          ),
                        );
                      }, childCount: state.methods.length),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddMethod(
    CheckoutPaymentState state,
    ExperienceGate? experience,
    AppLocalizations l10n,
  ) async {
    if (!state.canAddNewMethod) {
      final message = (experience?.isInternational ?? false)
          ? l10n.profilePaymentsLimitReachedInternational
          : l10n.profilePaymentsLimitReachedDomestic;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final payload = await showDialog<TokenizedPaymentMethodPayload>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.profilePaymentsAddDialogTitle),
            actions: [
              IconButton(
                tooltip: l10n.profilePaymentsAddDialogClose,
                onPressed: () => Navigator.of(dialogContext).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceL,
              ),
              child: TokenizedPaymentMethodForm(
                experience: experience,
                existingMethodCount: state.methods.length,
              ),
            ),
          ),
        ),
      ),
    );
    if (payload == null || !mounted) {
      return;
    }
    await _controller.registerTokenizedMethod(payload);
  }

  Future<bool> _confirmRemoval(
    CheckoutPaymentMethodSummary method,
    AppLocalizations l10n,
  ) async {
    final title = l10n.profilePaymentsDeleteConfirmTitle;
    final body = l10n.profilePaymentsDeleteConfirmBody(
      method.brand ?? l10n.profilePaymentsDeleteUnknownBrand,
      method.last4 ?? '----',
    );
    final removeLabel = l10n.profilePaymentsDeleteConfirmAction;
    final cancelLabel = l10n.profilePaymentsDeleteConfirmCancel;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(removeLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _handleSecurityLink(String route) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.profilePaymentsSecurityLinkComingSoon(route)),
        ),
      );
  }
}

class _ProfilePaymentMethodTile extends ConsumerWidget {
  const _ProfilePaymentMethodTile({
    required this.method,
    required this.isInternational,
    required this.selectedMethodId,
    required this.l10n,
    required this.isRemoving,
    required this.disabled,
    required this.defaultBadgeLabel,
    required this.onSelect,
    required this.onRemove,
    required this.removeDisabled,
  });

  final CheckoutPaymentMethodSummary method;
  final bool isInternational;
  final String? selectedMethodId;
  final AppLocalizations l10n;
  final bool isRemoving;
  final bool disabled;
  final String defaultBadgeLabel;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onRemove;
  final bool removeDisabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenAsync = ref.watch(paymentMethodTokenProvider(method.id));
    final tokenLines = <String>[];
    tokenAsync.when(
      data: (token) {
        if (token == null || token.isEmpty) {
          tokenLines.add(l10n.profilePaymentsTokenUnavailable);
        } else {
          tokenLines.add(l10n.profilePaymentsTokenLabel(token));
        }
      },
      loading: () {
        tokenLines.add(l10n.profilePaymentsTokenLoading);
      },
      error: (error, stackTrace) {
        tokenLines.add(l10n.profilePaymentsTokenError);
      },
    );

    return PaymentMethodTile(
      method: method,
      isInternational: isInternational,
      selectedMethodId: selectedMethodId,
      onSelect: disabled ? null : onSelect,
      defaultBadgeLabel: defaultBadgeLabel,
      additionalDetails: tokenLines,
      trailingAccessory: IconButton(
        tooltip: l10n.profilePaymentsDeleteTooltip,
        onPressed: removeDisabled
            ? null
            : () {
                unawaited(onRemove());
              },
        icon: const Icon(Icons.delete_outline),
      ),
      showBusyIndicator: isRemoving,
      disabled: disabled,
    );
  }
}

class _PaymentsSecurityCard extends StatelessWidget {
  const _PaymentsSecurityCard({
    required this.l10n,
    required this.isInternational,
    required this.onNavigate,
  });

  final AppLocalizations l10n;
  final bool isInternational;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardTitle = isInternational
        ? l10n.profilePaymentsSecurityTitleIntl
        : l10n.profilePaymentsSecurityTitleDomestic;
    final cardBody = isInternational
        ? l10n.profilePaymentsSecurityBodyIntl
        : l10n.profilePaymentsSecurityBodyDomestic;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.radiusL,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_moon_outlined, color: scheme.primary),
                const SizedBox(width: AppTokens.spaceS),
                Expanded(
                  child: Text(
                    cardTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(cardBody, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppTokens.spaceM),
            Wrap(
              spacing: AppTokens.spaceS,
              runSpacing: AppTokens.spaceS,
              children: [
                ActionChip(
                  label: Text(l10n.profilePaymentsSecurityChipTokens),
                  onPressed: () => onNavigate('psp-tokens'),
                  avatar: const Icon(Icons.token_outlined, size: 18),
                ),
                ActionChip(
                  label: Text(l10n.profilePaymentsSecurityChipFaq),
                  onPressed: () => onNavigate('faq'),
                  avatar: const Icon(Icons.help_outline, size: 18),
                ),
                ActionChip(
                  label: Text(l10n.profilePaymentsSecurityChipSupport),
                  onPressed: () => onNavigate('support'),
                  avatar: const Icon(Icons.chat_bubble_outline, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPaymentsView extends StatelessWidget {
  const _EmptyPaymentsView({required this.l10n, required this.onAdd});

  final AppLocalizations l10n;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceXXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.credit_card_off_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            l10n.profilePaymentsEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.profilePaymentsEmptyMessage,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceL),
          FilledButton(
            onPressed: onAdd,
            child: Text(l10n.profilePaymentsEmptyCta),
          ),
        ],
      ),
    );
  }
}

class _ProfilePaymentsErrorView extends StatelessWidget {
  const _ProfilePaymentsErrorView({
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
        padding: const EdgeInsets.all(AppTokens.spaceXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTokens.spaceL),
            Text(
              l10n.profilePaymentsErrorMessage(message),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceL),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.profilePaymentsErrorRetry),
            ),
          ],
        ),
      ),
    );
  }
}
