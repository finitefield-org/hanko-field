// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/features/checkout/view_model/checkout_review_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class CheckoutReviewPage extends ConsumerStatefulWidget {
  const CheckoutReviewPage({super.key});

  @override
  ConsumerState<CheckoutReviewPage> createState() => _CheckoutReviewPageState();
}

class _CheckoutReviewPageState extends ConsumerState<CheckoutReviewPage> {
  final TextEditingController _notesController = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(checkoutReviewViewModel);
    final placeState = ref.watch(checkoutReviewViewModel.placeOrderMut);
    final isPlacing = placeState is PendingMutationState;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: const BackButton(),
        title: Text(prefersEnglish ? 'Review order' : '注文確認'),
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
            isPlacing: isPlacing,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.sm,
          tokens.spacing.lg,
          tokens.spacing.md,
        ),
        child: AppButton(
          label: prefersEnglish ? 'Place order' : '注文を確定する',
          expand: true,
          isLoading: isPlacing,
          onPressed:
              (!isPlacing &&
                  _acceptedTerms &&
                  (state.valueOrNull?.isReadyForPlacement ?? false))
              ? () => _placeOrder(prefersEnglish: prefersEnglish)
              : null,
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required bool prefersEnglish,
    required AsyncValue<CheckoutReviewState> state,
    required bool isPlacing,
  }) {
    final tokens = DesignTokensTheme.of(context);

    if (state is AsyncLoading<CheckoutReviewState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 4, itemHeight: 120),
      );
    }

    if (state is AsyncError<CheckoutReviewState> && state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish ? 'Could not load review' : '注文確認を表示できません',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
          onAction: () =>
              ref.refreshValue(checkoutReviewViewModel, keepPrevious: false),
        ),
      );
    }

    final data =
        state.valueOrNull ??
        (throw StateError('Missing checkout review state'));

    if (!data.hasItems) {
      return AppEmptyState(
        title: prefersEnglish ? 'Cart is empty' : 'カートは空です',
        message: prefersEnglish
            ? 'Add items before checking out.'
            : '商品を追加してから購入手続きを行ってください。',
        icon: Icons.shopping_bag_outlined,
        actionLabel: prefersEnglish ? 'Back to cart' : 'カートへ戻る',
        onAction: () => GoRouter.of(context).go(AppRoutePaths.cart),
      );
    }

    final address = data.address;
    final shipping = data.shipping;
    final payment = data.payment;

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _EditChips(prefersEnglish: prefersEnglish),
        SizedBox(height: tokens.spacing.md),
        Text(
          prefersEnglish ? 'Order summary' : '注文内容',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.sm),
        ...data.cart.lines.map(
          (line) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.sm),
            child: _LineItemCard(item: line, prefersEnglish: prefersEnglish),
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _DesignSnapshotCard(
          items: data.cart.lines,
          prefersEnglish: prefersEnglish,
        ),
        SizedBox(height: tokens.spacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefersEnglish ? 'Shipping' : '配送先・配送方法',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: tokens.spacing.xs),
              if (address == null || shipping == null)
                Text(
                  prefersEnglish
                      ? 'Select address and shipping method.'
                      : '配送先と配送方法を設定してください。',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.label ??
                          (prefersEnglish ? 'Shipping address' : '配送先住所'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      '${address.recipient} • ${address.line1} ${address.line2 ?? ''}'
                          .trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      prefersEnglish
                          ? '${shipping.carrier} ${shipping.label} (${_formatMoney(data.shippingCost)})'
                          : '${shipping.carrier} ${shipping.label}（${_formatMoney(data.shippingCost)}）',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: tokens.spacing.sm),
              AppButton(
                label: prefersEnglish ? 'Edit shipping' : '配送情報を編集',
                variant: AppButtonVariant.ghost,
                expand: true,
                onPressed: isPlacing
                    ? null
                    : () => GoRouter.of(
                        context,
                      ).go(AppRoutePaths.checkoutShipping),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefersEnglish ? 'Payment' : '支払い方法',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: tokens.spacing.xs),
              if (payment == null)
                Text(
                  prefersEnglish
                      ? 'Select a payment method.'
                      : '支払い方法を設定してください。',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                Text(
                  _paymentSummary(payment, prefersEnglish: prefersEnglish),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              SizedBox(height: tokens.spacing.sm),
              AppButton(
                label: prefersEnglish ? 'Edit payment' : '支払い方法を編集',
                variant: AppButtonVariant.ghost,
                expand: true,
                onPressed: isPlacing
                    ? null
                    : () => GoRouter.of(
                        context,
                      ).go(AppRoutePaths.checkoutPayment),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefersEnglish ? 'Totals' : '合計',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: tokens.spacing.sm),
              _TotalRow(
                label: prefersEnglish ? 'Subtotal' : '小計',
                value: _formatMoney(data.cart.subtotal),
              ),
              if (data.cart.discount.amount > 0) ...[
                SizedBox(height: tokens.spacing.xs),
                _TotalRow(
                  label: prefersEnglish ? 'Discount' : '割引',
                  value: '-${_formatMoney(data.cart.discount)}',
                ),
              ],
              SizedBox(height: tokens.spacing.xs),
              _TotalRow(
                label: prefersEnglish ? 'Shipping' : '送料',
                value: _formatMoney(data.shippingCost),
              ),
              SizedBox(height: tokens.spacing.xs),
              _TotalRow(
                label: prefersEnglish ? 'Tax' : '消費税',
                value: _formatMoney(data.tax),
              ),
              const Divider(),
              _TotalRow(
                label: prefersEnglish ? 'Total' : '合計金額',
                value: _formatMoney(data.total),
                emphasize: true,
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: isPlacing
                    ? null
                    : (value) =>
                          setState(() => _acceptedTerms = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  prefersEnglish
                      ? 'I agree to the terms and conditions.'
                      : '利用規約に同意します。',
                ),
              ),
              SizedBox(height: tokens.spacing.sm),
              AppTextField(
                label: prefersEnglish ? 'Special instructions' : '特別なご要望',
                controller: _notesController,
                hintText: prefersEnglish
                    ? 'Anything we should know?'
                    : '配送や作成についてのご要望があればご記入ください。',
                maxLines: 3,
                enabled: !isPlacing,
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.xl),
      ],
    );
  }

  Future<void> _placeOrder({required bool prefersEnglish}) async {
    final result = await ref.invoke(
      checkoutReviewViewModel.placeOrder(notes: _notesController.text.trim()),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (result.isSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(prefersEnglish ? 'Order placed!' : '注文を受け付けました。'),
        ),
      );
      final query = <String, String>{};
      if (result.orderId != null && result.orderId!.isNotEmpty) {
        query['orderId'] = result.orderId!;
      }
      if (result.orderNumber != null && result.orderNumber!.isNotEmpty) {
        query['orderNumber'] = result.orderNumber!;
      }
      final uri = Uri(
        path: AppRoutePaths.checkoutComplete,
        queryParameters: query,
      );
      GoRouter.of(context).go(uri.toString());
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                (prefersEnglish ? 'Failed to place order.' : '注文を確定できませんでした。'),
          ),
        ),
      );
    }
  }
}

class _EditChips extends StatelessWidget {
  const _EditChips({required this.prefersEnglish});

  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final router = GoRouter.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(
            label: Text(prefersEnglish ? 'Edit address' : '住所を編集'),
            avatar: const Icon(Icons.location_on_outlined),
            onPressed: () => router.go(AppRoutePaths.checkoutAddress),
          ),
          SizedBox(width: tokens.spacing.sm),
          ActionChip(
            label: Text(prefersEnglish ? 'Edit shipping' : '配送を編集'),
            avatar: const Icon(Icons.local_shipping_outlined),
            onPressed: () => router.go(AppRoutePaths.checkoutShipping),
          ),
          SizedBox(width: tokens.spacing.sm),
          ActionChip(
            label: Text(prefersEnglish ? 'Edit payment' : '支払いを編集'),
            avatar: const Icon(Icons.credit_card_outlined),
            onPressed: () => router.go(AppRoutePaths.checkoutPayment),
          ),
        ],
      ),
    );
  }
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({required this.item, required this.prefersEnglish});

  final CartLineItem item;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.sm),
            child: Image.network(
              item.thumbnailUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 72,
                height: 72,
                color: tokens.colors.surface,
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: textTheme.titleSmall),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  item.variantLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (item.designLabel != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    item.designLabel!,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (item.selectedAddons.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    item.selectedAddons
                        .map((CartAddonOption addon) => addon.label)
                        .join(', '),
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.sm),
                Text(
                  prefersEnglish
                      ? 'Qty ${item.quantity}'
                      : '数量 ${item.quantity}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.md),
          Text(_formatMoney(item.lineTotal), style: textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _DesignSnapshotCard extends StatelessWidget {
  const _DesignSnapshotCard({
    required this.items,
    required this.prefersEnglish,
  });

  final List<CartLineItem> items;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Design snapshot' : 'デザインプレビュー',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: items.map((item) {
              return SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(tokens.radii.sm),
                        child: Image.network(
                          item.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: tokens.colors.surface,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      item.designLabel ?? item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = emphasize ? textTheme.titleMedium : textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

String _formatMoney(Money money) {
  final digits = money.amount.abs().toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  final prefix = money.currency.toUpperCase() == 'JPY'
      ? '¥'
      : '${money.currency} ';
  return '$prefix$formatted';
}

String _paymentSummary(dynamic method, {required bool prefersEnglish}) {
  if (method is! PaymentMethod) return '';
  final title = _paymentTitle(method, prefersEnglish: prefersEnglish);
  final subtitle = _paymentSubtitle(method, prefersEnglish: prefersEnglish);
  return subtitle == null ? title : '$title • $subtitle';
}

String _paymentTitle(PaymentMethod method, {required bool prefersEnglish}) {
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

String? _paymentSubtitle(PaymentMethod method, {required bool prefersEnglish}) {
  if (method.methodType == PaymentMethodType.card &&
      method.expMonth != null &&
      method.expYear != null) {
    return prefersEnglish
        ? 'Expires ${method.expMonth}/${method.expYear}'
        : '有効期限 ${method.expMonth}/${method.expYear}';
  }
  return method.billingName;
}
