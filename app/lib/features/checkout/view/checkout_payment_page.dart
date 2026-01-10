// ignore_for_file: public_member_api_docs, deprecated_member_use

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/checkout/view_model/checkout_payment_view_model.dart';
import 'package:app/features/payments/payment_method_form.dart';
import 'package:app/features/payments/view/payment_method_form_sheet.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class CheckoutPaymentPage extends ConsumerStatefulWidget {
  const CheckoutPaymentPage({super.key});

  @override
  ConsumerState<CheckoutPaymentPage> createState() =>
      _CheckoutPaymentPageState();
}

class _CheckoutPaymentPageState extends ConsumerState<CheckoutPaymentPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(checkoutPaymentViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: const BackButton(),
        title: Text(l10n.checkoutPaymentTitle),
        actions: [
          if (state.valueOrNull?.canAddMethods == true)
            IconButton(
              tooltip: l10n.checkoutPaymentAddTooltip,
              icon: const Icon(Icons.add_card_outlined),
              onPressed: () => _openAddForm(l10n),
            ),
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
          child: _buildBody(context: context, l10n: l10n, state: state),
        ),
      ),
      bottomNavigationBar: _buildFooter(
        context: context,
        l10n: l10n,
        state: state,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AppLocalizations l10n,
    required AsyncValue<CheckoutPaymentState> state,
  }) {
    final tokens = DesignTokensTheme.of(context);

    if (state is AsyncLoading<CheckoutPaymentState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 2, itemHeight: 92),
      );
    }

    if (state is AsyncError<CheckoutPaymentState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: l10n.checkoutPaymentLoadFailedTitle,
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: l10n.commonRetry,
          onAction: () =>
              ref.refreshValue(checkoutPaymentViewModel, keepPrevious: false),
        ),
      );
    }

    final data = state.valueOrNull ?? const CheckoutPaymentState(methods: []);
    if (data.methods.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.checkoutPaymentEmptyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.sm),
                Text(
                  l10n.checkoutPaymentEmptyBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                if (!data.canAddMethods) ...[
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    l10n.checkoutPaymentSignInHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                if (data.canAddMethods) ...[
                  SizedBox(height: tokens.spacing.md),
                  AppButton(
                    label: l10n.checkoutPaymentAddMethod,
                    expand: true,
                    onPressed: () => _openAddForm(l10n),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final selectedId = data.selectedMethod?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.checkoutPaymentChooseSaved,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.75),
          ),
        ),
        if (data.lastError != null) ...[
          SizedBox(height: tokens.spacing.sm),
          Text(
            data.lastError!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.colors.error),
          ),
        ],
        SizedBox(height: tokens.spacing.md),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () =>
                ref.refreshValue(checkoutPaymentViewModel, keepPrevious: true),
            edgeOffset: tokens.spacing.sm,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: data.methods.length,
              separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.sm),
              itemBuilder: (context, index) {
                final method = data.methods[index];
                return _PaymentTile(
                  method: method,
                  l10n: l10n,
                  groupValue: selectedId,
                  onSelect: () => ref.invoke(
                    checkoutPaymentViewModel.selectPayment(method.id),
                  ),
                );
              },
            ),
          ),
        ),
        if (data.canAddMethods) ...[
          SizedBox(height: tokens.spacing.md),
          AppButton(
            label: l10n.checkoutPaymentAddAnother,
            variant: AppButtonVariant.ghost,
            leading: const Icon(Icons.add),
            expand: true,
            onPressed: () => _openAddForm(l10n),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter({
    required BuildContext context,
    required AppLocalizations l10n,
    required AsyncValue<CheckoutPaymentState> state,
  }) {
    final tokens = DesignTokensTheme.of(context);
    final data = state.valueOrNull;
    final selected = data?.selectedMethod;
    final addState = ref.watch(checkoutPaymentViewModel.addPaymentMut);
    final isSaving = addState is PendingMutationState;

    return SafeArea(
      minimum: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.sm,
        tokens.spacing.lg,
        tokens.spacing.md,
      ),
      child: AppButton(
        label: l10n.checkoutPaymentContinueReview,
        expand: true,
        isLoading: isSaving,
        onPressed: selected == null || isSaving
            ? null
            : () => context.go(AppRoutePaths.checkoutReview),
      ),
    );
  }

  Future<void> _openAddForm(AppLocalizations l10n) async {
    final result = await showModalBottomSheet<PaymentMethodDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const PaymentMethodFormSheet(),
    );
    if (result == null) return;
    final save = await ref.invoke(
      checkoutPaymentViewModel.addPaymentMethod(result),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!save.isSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            save.validation.message ?? l10n.checkoutPaymentAddFailed,
          ),
        ),
      );
    }
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.method,
    required this.l10n,
    required this.groupValue,
    required this.onSelect,
  });

  final PaymentMethod method;
  final AppLocalizations l10n;
  final String? groupValue;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final title = _title();
    final subtitle = _subtitle();

    return AppCard(
      onTap: onSelect,
      child: Row(
        children: [
          Icon(_leadingIcon(), size: 28),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Radio<String?>(
            value: method.id,
            groupValue: groupValue,
            onChanged: (_) => onSelect(),
          ),
        ],
      ),
    );
  }

  IconData _leadingIcon() {
    if (method.methodType == PaymentMethodType.wallet) {
      return Icons.account_balance_wallet_outlined;
    }
    if (method.methodType == PaymentMethodType.bank) {
      return Icons.account_balance_outlined;
    }
    return Icons.credit_card_outlined;
  }

  String _title() {
    if (method.methodType == PaymentMethodType.card) {
      final brand = method.brand?.toUpperCase();
      final last4 = method.last4;
      if (brand != null && last4 != null) {
        return '$brand •••• $last4';
      }
      if (last4 != null) {
        return '•••• $last4';
      }
      return l10n.checkoutPaymentMethodCard;
    }
    return switch (method.methodType) {
      PaymentMethodType.wallet => l10n.checkoutPaymentMethodWallet,
      PaymentMethodType.bank => l10n.checkoutPaymentMethodBank,
      _ => l10n.checkoutPaymentMethodFallback,
    };
  }

  String? _subtitle() {
    if (method.methodType == PaymentMethodType.card &&
        method.expMonth != null &&
        method.expYear != null) {
      return l10n.checkoutPaymentExpires(method.expMonth!, method.expYear!);
    }
    return method.billingName;
  }
}
