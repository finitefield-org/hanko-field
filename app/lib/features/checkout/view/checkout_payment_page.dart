// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/checkout/view_model/checkout_payment_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(checkoutPaymentViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: const BackButton(),
        title: Text(prefersEnglish ? 'Payment method' : '支払い方法'),
        actions: [
          if (state.valueOrNull?.canAddMethods == true)
            IconButton(
              tooltip: prefersEnglish ? 'Add payment method' : '支払い方法を追加',
              icon: const Icon(Icons.add_card_outlined),
              onPressed: () => _openAddForm(prefersEnglish: prefersEnglish),
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
          child: _buildBody(
            context: context,
            prefersEnglish: prefersEnglish,
            gates: gates,
            state: state,
          ),
        ),
      ),
      bottomNavigationBar: _buildFooter(
        context: context,
        prefersEnglish: prefersEnglish,
        state: state,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required bool prefersEnglish,
    required AppExperienceGates gates,
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
          title: prefersEnglish ? 'Could not load payments' : '支払い方法を読み込めません',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
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
                  prefersEnglish ? 'Add a payment method' : '支払い方法を追加してください',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.sm),
                Text(
                  prefersEnglish
                      ? 'Save a card or wallet to continue checkout.'
                      : 'カードやウォレットを登録すると、次のステップに進めます。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                if (!data.canAddMethods) ...[
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    prefersEnglish
                        ? 'Sign in to add methods.'
                        : '支払い方法の追加にはログインが必要です。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                if (data.canAddMethods) ...[
                  SizedBox(height: tokens.spacing.md),
                  AppButton(
                    label: prefersEnglish ? 'Add method' : '支払い方法を追加',
                    expand: true,
                    onPressed: () =>
                        _openAddForm(prefersEnglish: prefersEnglish),
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
          prefersEnglish
              ? 'Choose a saved payment method.'
              : '保存済みの支払い方法を選択してください。',
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
            child: RadioGroup<String?>(
              groupValue: selectedId,
              onChanged: (value) =>
                  ref.invoke(checkoutPaymentViewModel.selectPayment(value)),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: data.methods.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: tokens.spacing.sm),
                itemBuilder: (context, index) {
                  final method = data.methods[index];
                  return _PaymentTile(
                    method: method,
                    prefersEnglish: prefersEnglish,
                    onSelect: () => ref.invoke(
                      checkoutPaymentViewModel.selectPayment(method.id),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (data.canAddMethods) ...[
          SizedBox(height: tokens.spacing.md),
          AppButton(
            label: prefersEnglish ? 'Add another method' : '支払い方法を追加',
            variant: AppButtonVariant.ghost,
            leading: const Icon(Icons.add),
            expand: true,
            onPressed: () => _openAddForm(prefersEnglish: prefersEnglish),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter({
    required BuildContext context,
    required bool prefersEnglish,
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
        label: prefersEnglish ? 'Continue to review' : '注文確認へ進む',
        expand: true,
        isLoading: isSaving,
        onPressed: selected == null || isSaving
            ? null
            : () => GoRouter.of(context).go(AppRoutePaths.checkoutReview),
      ),
    );
  }

  Future<void> _openAddForm({required bool prefersEnglish}) async {
    final result = await showModalBottomSheet<PaymentMethodDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddPaymentSheet(prefersEnglish: prefersEnglish),
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
            save.validation.message ??
                (prefersEnglish
                    ? 'Could not add payment method'
                    : '支払い方法を追加できません'),
          ),
        ),
      );
    }
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.method,
    required this.prefersEnglish,
    required this.onSelect,
  });

  final PaymentMethod method;
  final bool prefersEnglish;
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
          Radio<String?>(value: method.id),
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
      return prefersEnglish ? 'Card' : 'カード';
    }
    return switch (method.methodType) {
      PaymentMethodType.wallet => prefersEnglish ? 'Wallet' : 'ウォレット',
      PaymentMethodType.bank => prefersEnglish ? 'Bank transfer' : '銀行振込',
      _ => prefersEnglish ? 'Payment method' : '支払い方法',
    };
  }

  String? _subtitle() {
    if (method.methodType == PaymentMethodType.card &&
        method.expMonth != null &&
        method.expYear != null) {
      return prefersEnglish
          ? 'Expires ${method.expMonth}/${method.expYear}'
          : '有効期限 ${method.expMonth}/${method.expYear}';
    }
    return method.billingName;
  }
}

class _AddPaymentSheet extends StatefulWidget {
  const _AddPaymentSheet({required this.prefersEnglish});

  final bool prefersEnglish;

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _brandCtrl = TextEditingController();
  final _last4Ctrl = TextEditingController();
  final _expMonthCtrl = TextEditingController();
  final _expYearCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  PaymentMethodType _type = PaymentMethodType.card;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _last4Ctrl.dispose();
    _expMonthCtrl.dispose();
    _expYearCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final prefersEnglish = widget.prefersEnglish;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.lg,
        MediaQuery.of(context).viewInsets.bottom + tokens.spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prefersEnglish ? 'Add payment method' : '支払い方法を追加',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          SegmentedButton<PaymentMethodType>(
            segments: [
              ButtonSegment(
                value: PaymentMethodType.card,
                label: Text(prefersEnglish ? 'Card' : 'カード'),
                icon: const Icon(Icons.credit_card_outlined),
              ),
              ButtonSegment(
                value: PaymentMethodType.wallet,
                label: Text(prefersEnglish ? 'Wallet' : 'ウォレット'),
                icon: const Icon(Icons.account_balance_wallet_outlined),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          SizedBox(height: tokens.spacing.md),
          if (_type == PaymentMethodType.card) ...[
            AppTextField(
              controller: _brandCtrl,
              label: prefersEnglish ? 'Brand (e.g. Visa)' : 'ブランド (例: Visa)',
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: tokens.spacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _last4Ctrl,
                    label: prefersEnglish ? 'Last 4 digits' : 'カード下4桁',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _expMonthCtrl,
                    label: prefersEnglish ? 'Exp. month' : '有効期限(月)',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _expYearCtrl,
                    label: prefersEnglish ? 'Exp. year' : '有効期限(年)',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.sm),
          ],
          AppTextField(
            controller: _nameCtrl,
            label: prefersEnglish ? 'Billing name (optional)' : '請求先名 (任意)',
          ),
          SizedBox(height: tokens.spacing.lg),
          AppButton(
            label: prefersEnglish ? 'Save' : '保存',
            expand: true,
            onPressed: () {
              Navigator.of(context).pop(
                PaymentMethodDraft(
                  methodType: _type,
                  brand: _brandCtrl.text.trim().isEmpty
                      ? null
                      : _brandCtrl.text.trim(),
                  last4: _last4Ctrl.text.trim().isEmpty
                      ? null
                      : _last4Ctrl.text.trim(),
                  expMonth: int.tryParse(_expMonthCtrl.text.trim()),
                  expYear: int.tryParse(_expYearCtrl.text.trim()),
                  billingName: _nameCtrl.text.trim().isEmpty
                      ? null
                      : _nameCtrl.text.trim(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
