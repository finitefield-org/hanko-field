// ignore_for_file: public_member_api_docs, deprecated_member_use

import 'package:app/features/payments/payment_method_form.dart';
import 'package:app/features/payments/view/payment_method_form_sheet.dart';
import 'package:app/features/profile/view_model/profile_payments_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:app/ui/feedback/app_skeleton.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfilePaymentsPage extends ConsumerStatefulWidget {
  const ProfilePaymentsPage({super.key});

  @override
  ConsumerState<ProfilePaymentsPage> createState() =>
      _ProfilePaymentsPageState();
}

class _ProfilePaymentsPageState extends ConsumerState<ProfilePaymentsPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(profilePaymentsViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: Text(prefersEnglish ? 'Payment methods' : '支払い方法'),
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
            state: state,
            canAdd: state.valueOrNull?.canAddMethods ?? false,
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required bool prefersEnglish,
    required AsyncValue<ProfilePaymentsState> state,
    required bool canAdd,
  }) {
    final tokens = DesignTokensTheme.of(context);

    if (state is AsyncLoading<ProfilePaymentsState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 2, itemHeight: 92),
      );
    }

    if (state is AsyncError<ProfilePaymentsState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish ? 'Could not load payments' : '支払い方法を読み込めません',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
          onAction: () =>
              ref.refreshValue(profilePaymentsViewModel, keepPrevious: false),
        ),
      );
    }

    final data = state.valueOrNull ?? const ProfilePaymentsState(methods: []);
    if (data.methods.isEmpty) {
      final message = prefersEnglish
          ? (canAdd
                ? 'Add a card or wallet to speed up checkout.'
                : 'Sign in to manage payment methods.')
          : (canAdd
                ? 'カードやウォレットを登録すると、チェックアウトがスムーズになります。'
                : '支払い方法の管理にはログインが必要です。');
      return AppEmptyState(
        title: prefersEnglish ? 'No payment methods' : '支払い方法がありません',
        message: message,
        icon: Icons.credit_card_outlined,
        actionLabel: canAdd
            ? (prefersEnglish ? 'Add method' : '支払い方法を追加')
            : null,
        onAction: canAdd
            ? () => _openAddForm(prefersEnglish: prefersEnglish)
            : null,
      );
    }

    final defaultId = data.defaultMethod?.id;

    return Column(
      children: [
        if (data.lastError != null) ...[
          Text(
            data.lastError!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.colors.error),
          ),
          SizedBox(height: tokens.spacing.sm),
        ],
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () =>
                ref.refreshValue(profilePaymentsViewModel, keepPrevious: true),
            edgeOffset: tokens.spacing.sm,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: data.methods.length,
              separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.sm),
              itemBuilder: (context, index) {
                final method = data.methods[index];
                return _PaymentMethodListItem(
                  method: method,
                  prefersEnglish: prefersEnglish,
                  groupValue: defaultId,
                  onSelect: method.id == null || method.id == defaultId
                      ? null
                      : () => ref.invoke(
                          profilePaymentsViewModel.setDefault(method.id!),
                        ),
                  onDelete: method.id == null
                      ? null
                      : () => _confirmDelete(method),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddForm({required bool prefersEnglish}) async {
    final result = await showModalBottomSheet<PaymentMethodDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const PaymentMethodFormSheet(),
    );
    if (result == null) return;
    final save = await ref.invoke(
      profilePaymentsViewModel.addPaymentMethod(result),
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

  Future<void> _confirmDelete(PaymentMethod method) async {
    final gates = ref.container.read(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final id = method.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          prefersEnglish ? 'Remove payment method?' : '支払い方法を削除しますか？',
        ),
        content: Text(
          prefersEnglish ? 'This cannot be undone.' : 'この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(prefersEnglish ? 'Cancel' : 'キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(prefersEnglish ? 'Remove' : '削除'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    await ref.invoke(profilePaymentsViewModel.deletePaymentMethod(id));
  }
}

class _PaymentMethodListItem extends StatelessWidget {
  const _PaymentMethodListItem({
    required this.method,
    required this.prefersEnglish,
    required this.groupValue,
    required this.onSelect,
    required this.onDelete,
  });

  final PaymentMethod method;
  final bool prefersEnglish;
  final String? groupValue;
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (method.isDefault)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacing.sm,
                          vertical: tokens.spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(tokens.radii.lg),
                        ),
                        child: Text(
                          prefersEnglish ? 'Default' : '既定',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<String?>(
                value: method.id,
                groupValue: groupValue,
                onChanged: onSelect == null ? null : (_) => onSelect!(),
              ),
              IconButton(
                tooltip: prefersEnglish ? 'Remove' : '削除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
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
