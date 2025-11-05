import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/cart_controller.dart';
import 'package:app/features/cart/application/checkout_review_controller.dart';
import 'package:app/features/cart/application/checkout_state_controller.dart';
import 'package:app/features/cart/domain/cart_models.dart';
import 'package:app/features/cart/domain/checkout_models.dart';
import 'package:app/features/cart/domain/checkout_payment_models.dart';
import 'package:app/features/cart/domain/checkout_shipping_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CheckoutReviewScreen extends ConsumerStatefulWidget {
  const CheckoutReviewScreen({super.key});

  @override
  ConsumerState<CheckoutReviewScreen> createState() =>
      _CheckoutReviewScreenState();
}

class _CheckoutReviewScreenState extends ConsumerState<CheckoutReviewScreen> {
  late final TextEditingController _instructionsController;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _instructionsController = TextEditingController();
    ref.listen<CheckoutReviewState>(checkoutReviewControllerProvider, (
      previous,
      next,
    ) {
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(checkoutReviewControllerProvider.notifier);
      final prevSuccess = previous?.successMessage;
      final nextSuccess = next.successMessage;
      if (nextSuccess != null && nextSuccess != prevSuccess) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(nextSuccess)));
        if (mounted) {
          setState(() {
            _termsAccepted = false;
            _instructionsController
              ..text = ''
              ..clear();
          });
        }
        notifier.clearMessages();
        return;
      }
      final prevError = previous?.errorMessage;
      final nextError = next.errorMessage;
      if (nextError != null && nextError != prevError) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(nextError),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        notifier.clearMessages();
      }
    });
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  CheckoutReviewController get _controller =>
      ref.read(checkoutReviewControllerProvider.notifier);

  CartController get _cartController =>
      ref.read(cartControllerProvider.notifier);

  void _openStep(String primary) {
    ref.read(appStateProvider.notifier).push(CheckoutRoute([primary]));
  }

  Future<void> _reloadCart() async {
    await _cartController.reload();
  }

  bool get _hasInstructions => _instructionsController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final experienceAsync = ref.watch(experienceGateProvider);
    final cartAsync = ref.watch(cartControllerProvider);
    final checkoutState = ref.watch(checkoutStateProvider);
    final reviewState = ref.watch(checkoutReviewControllerProvider);
    final isSubmitting = reviewState.isSubmitting;
    final experience = experienceAsync.value;
    final isIntl = experience?.isInternational ?? false;
    final formatter = _CurrencyFormatter(experience);

    final headTitle = isIntl ? 'Review & place order' : '注文内容を確認';
    final placeOrderLabel = isIntl ? 'Place order' : '注文を確定する';
    final editAddressLabel = isIntl ? 'Edit address' : '住所を編集';
    final editShippingLabel = isIntl ? 'Edit shipping' : '配送方法を編集';
    final editPaymentLabel = isIntl ? 'Edit payment' : '支払い方法を編集';
    final instructionsLabel = isIntl ? 'Special instructions' : '連絡事項・要望';
    final instructionsHint = isIntl
        ? 'Optional notes for engravers or delivery'
        : '刻印職人や配送への要望があればご記入ください（任意）';
    final termsLabel = isIntl
        ? 'I agree to the terms and cancellation policy.'
        : '利用規約およびキャンセルポリシーに同意します。';

    return Scaffold(
      body: cartAsync.when(
        loading: () =>
            const SafeArea(child: Center(child: CircularProgressIndicator())),
        error: (error, stackTrace) => SafeArea(
          child: _CheckoutErrorView(
            message: error.toString(),
            onRetry: _reloadCart,
            isInternational: isIntl,
          ),
        ),
        data: (cartState) {
          final hasLines = cartState.lines.isNotEmpty;
          final canSubmit =
              hasLines &&
              checkoutState.hasSelectedAddress &&
              checkoutState.hasSelectedShippingOption &&
              checkoutState.hasSelectedPaymentMethod &&
              _termsAccepted &&
              !isSubmitting;
          final assistChips = [
            ActionChip(
              avatar: const Icon(Icons.location_on_outlined, size: 18),
              label: Text(editAddressLabel),
              onPressed: () => _openStep('address'),
            ),
            ActionChip(
              avatar: const Icon(Icons.local_shipping_outlined, size: 18),
              label: Text(editShippingLabel),
              onPressed: () => _openStep('shipping'),
            ),
            ActionChip(
              avatar: const Icon(Icons.credit_card_outlined, size: 18),
              label: Text(editPaymentLabel),
              onPressed: () => _openStep('payment'),
            ),
          ];

          return SafeArea(
            child: Column(
              children: [
                if (isSubmitting) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar.medium(
                        centerTitle: true,
                        title: Text(headTitle),
                        pinned: true,
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(56),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppTokens.spaceL,
                                0,
                                AppTokens.spaceL,
                                AppTokens.spaceS,
                              ),
                              child: Wrap(
                                spacing: AppTokens.spaceS,
                                runSpacing: AppTokens.spaceS,
                                children: assistChips,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spaceL,
                          vertical: AppTokens.spaceL,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (reviewState.lastReceipt != null)
                              _OrderConfirmationCard(
                                receipt: reviewState.lastReceipt!,
                                isInternational: isIntl,
                                formatter: formatter,
                              ),
                            if (reviewState.lastReceipt != null)
                              const SizedBox(height: AppTokens.spaceL),
                            _DesignPreviewCard(
                              lines: cartState.lines,
                              isInternational: isIntl,
                            ),
                            const SizedBox(height: AppTokens.spaceL),
                            _OrderSummaryCard(
                              lines: cartState.lines,
                              estimate: cartState.estimate,
                              formatter: formatter,
                              isInternational: isIntl,
                            ),
                            const SizedBox(height: AppTokens.spaceL),
                            _AddressInfoCard(
                              address: checkoutState.selectedShippingAddress,
                              isInternational: isIntl,
                              onEdit: () => _openStep('address'),
                            ),
                            const SizedBox(height: AppTokens.spaceL),
                            _ShippingInfoCard(
                              option: checkoutState.selectedShippingOption,
                              isInternational: isIntl,
                              formatter: formatter,
                              onEdit: () => _openStep('shipping'),
                            ),
                            const SizedBox(height: AppTokens.spaceL),
                            _PaymentInfoCard(
                              method: checkoutState.selectedPaymentMethod,
                              isInternational: isIntl,
                              onEdit: () => _openStep('payment'),
                            ),
                            const SizedBox(height: AppTokens.spaceL),
                            _InstructionsCard(
                              controller: _instructionsController,
                              label: instructionsLabel,
                              hint: instructionsHint,
                              enabled: hasLines && !isSubmitting,
                            ),
                            const SizedBox(height: AppTokens.spaceM),
                            CheckboxListTile(
                              value: _termsAccepted,
                              onChanged: isSubmitting
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _termsAccepted = value ?? false,
                                      );
                                    },
                              title: Text(
                                termsLabel,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTokens.spaceS,
                              ),
                            ),
                            if (!hasLines)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppTokens.spaceM,
                                ),
                                child: _EmptyCartNotice(
                                  isInternational: isIntl,
                                ),
                              ),
                            const SizedBox(height: AppTokens.spaceXXL),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(
                    AppTokens.spaceL,
                    AppTokens.spaceS,
                    AppTokens.spaceL,
                    AppTokens.spaceL,
                  ),
                  child: FilledButton(
                    onPressed: canSubmit
                        ? () => _controller.placeOrder(
                            instructions: _hasInstructions
                                ? _instructionsController.text.trim()
                                : null,
                          )
                        : null,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(placeOrderLabel),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DesignPreviewCard extends StatelessWidget {
  const _DesignPreviewCard({
    required this.lines,
    required this.isInternational,
  });

  final List<CartLine> lines;
  final bool isInternational;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = lines.isNotEmpty ? lines.first : null;
    final title = isInternational ? 'Design snapshot' : 'デザインプレビュー';
    final emptyLabel = isInternational
        ? 'Add a product to view its design details.'
        : '商品を追加するとデザイン詳細を確認できます。';
    if (primary == null) {
      return Card(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppTokens.spaceS),
              Text(emptyLabel, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (primary.thumbnailUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                primary.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppTokens.spaceXS),
                Text(primary.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppTokens.spaceXS),
                Text(primary.subtitle, style: theme.textTheme.bodySmall),
                if (primary.optionChips.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.spaceS),
                  Wrap(
                    spacing: AppTokens.spaceS,
                    runSpacing: AppTokens.spaceXS,
                    children: primary.optionChips
                        .take(6)
                        .map(
                          (chip) => Chip(
                            label: Text(chip),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.lines,
    required this.estimate,
    required this.formatter,
    required this.isInternational,
  });

  final List<CartLine> lines;
  final CartEstimate estimate;
  final _CurrencyFormatter formatter;
  final bool isInternational;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryTitle = isInternational ? 'Order summary' : '注文サマリー';
    final qtyLabel = isInternational ? 'Qty' : '数量';
    final subtotalLabel = isInternational ? 'Subtotal' : '小計';
    final discountLabel = isInternational ? 'Discount' : '割引';
    final shippingLabel = isInternational ? 'Shipping' : '送料';
    final taxLabel = isInternational ? 'Tax' : '税額';
    final totalLabel = isInternational ? 'Total' : '合計';

    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: AppTokens.radiusL,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summaryTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.spaceM),
            if (lines.isEmpty)
              Text(
                isInternational ? 'Your cart is empty.' : 'カートに商品がありません。',
                style: theme.textTheme.bodyMedium,
              )
            else
              Column(
                children: [
                  for (final (index, line) in lines.indexed) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.title,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: AppTokens.spaceXS),
                              Text(
                                '$qtyLabel: ${line.quantity}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatter.format(line.lineTotal),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    if (index != lines.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTokens.spaceM,
                        ),
                        child: Divider(height: 1),
                      ),
                  ],
                ],
              ),
            const SizedBox(height: AppTokens.spaceM),
            const Divider(height: 1),
            const SizedBox(height: AppTokens.spaceM),
            _SummaryRow(
              label: subtotalLabel,
              value: formatter.format(estimate.subtotal),
            ),
            if (estimate.discount > 0)
              _SummaryRow(
                label: discountLabel,
                value: '-${formatter.format(estimate.discount)}',
                valueStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            _SummaryRow(
              label: shippingLabel,
              value: formatter.format(estimate.shipping),
            ),
            if (estimate.tax > 0)
              _SummaryRow(
                label: taxLabel,
                value: formatter.format(estimate.tax),
              ),
            const SizedBox(height: AppTokens.spaceS),
            _SummaryRow(
              label: totalLabel,
              value: formatter.format(estimate.total),
              valueStyle: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: valueStyle ?? theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _AddressInfoCard extends StatelessWidget {
  const _AddressInfoCard({
    required this.address,
    required this.isInternational,
    required this.onEdit,
  });

  final UserAddress? address;
  final bool isInternational;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isInternational ? 'Shipping address' : '配送先住所';
    final addPrompt = isInternational
        ? 'Add or select an address.'
        : '配送先住所を追加・選択してください。';

    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: AppTokens.radiusL,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: Text(isInternational ? 'Edit' : '編集'),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceS),
            if (address == null)
              Text(
                addPrompt,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              _AddressDetails(
                address: address!,
                isInternational: isInternational,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddressDetails extends StatelessWidget {
  const _AddressDetails({required this.address, required this.isInternational});

  final UserAddress address;
  final bool isInternational;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = _formatAddressLines(address, isInternational);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(address.recipient, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppTokens.spaceXS),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceXS),
            child: Text(line, style: theme.textTheme.bodyMedium),
          ),
        if (address.phone != null && address.phone!.isNotEmpty)
          Text(address.phone!, style: theme.textTheme.bodySmall),
      ],
    );
  }

  List<String> _formatAddressLines(UserAddress address, bool isInternational) {
    final result = <String>[];
    final state = address.state?.trim();
    final line2 = address.line2?.trim();
    if (isInternational) {
      result.add(address.line1.trim());
      if (line2 != null && line2.isNotEmpty) {
        result.add(line2);
      }
      final locality = (state == null || state.isEmpty)
          ? address.city
          : '${address.city}, $state';
      result.add(locality);
      if (address.postalCode.isNotEmpty) {
        result.add(address.postalCode);
      }
      result.add(address.country.toUpperCase());
    } else {
      if (state != null && state.isNotEmpty) {
        result.add(state + address.city);
      } else {
        result.add(address.city);
      }
      result.add(address.line1);
      if (line2 != null && line2.isNotEmpty) {
        result.add(line2);
      }
      result.add(address.postalCode);
    }
    return result;
  }
}

class _ShippingInfoCard extends StatelessWidget {
  const _ShippingInfoCard({
    required this.option,
    required this.isInternational,
    required this.formatter,
    required this.onEdit,
  });

  final CheckoutShippingOption? option;
  final bool isInternational;
  final _CurrencyFormatter formatter;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isInternational ? 'Shipping' : '配送方法';
    final missingLabel = isInternational
        ? 'Choose a shipping option.'
        : '配送方法を選択してください。';
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: AppTokens.radiusL,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: Text(isInternational ? 'Edit' : '編集'),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceS),
            if (option == null)
              Text(
                missingLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option!.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(option!.summary, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(
                    option!.estimatedDelivery,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(
                    formatter.format(option!.price),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentInfoCard extends StatelessWidget {
  const _PaymentInfoCard({
    required this.method,
    required this.isInternational,
    required this.onEdit,
  });

  final CheckoutPaymentMethodSummary? method;
  final bool isInternational;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isInternational ? 'Payment method' : 'お支払い方法';
    final missingLabel = isInternational
        ? 'Select a payment method.'
        : 'お支払い方法を選択してください。';
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: AppTokens.radiusL,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: Text(isInternational ? 'Edit' : '編集'),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceS),
            if (method == null)
              Text(
                missingLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _methodDisplay(method!, isInternational),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (method!.billingName != null &&
                      method!.billingName!.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.spaceXS),
                    Text(
                      method!.billingName!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _methodDisplay(
    CheckoutPaymentMethodSummary method,
    bool isInternational,
  ) {
    final brand = method.brand ?? 'Card';
    final last4 = method.last4 ?? '••••';
    final type = switch (method.methodType) {
      PaymentMethodType.card => isInternational ? 'Card' : 'クレジットカード',
      PaymentMethodType.wallet =>
        isInternational ? 'Digital wallet' : 'デジタルウォレット',
      PaymentMethodType.bank => isInternational ? 'Bank transfer' : '銀行振込',
      PaymentMethodType.other => isInternational ? 'Payment method' : '支払い方法',
    };
    final expiry = method.hasExpiry
        ? ' • ${method.expMonth!.toString().padLeft(2, '0')}/${method.expYear}'
        : '';
    return '$type • $brand • **** $last4$expiry';
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: AppTokens.radiusL,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.spaceS),
            TextField(
              controller: controller,
              enabled: enabled,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderConfirmationCard extends StatelessWidget {
  const _OrderConfirmationCard({
    required this.receipt,
    required this.isInternational,
    required this.formatter,
  });

  final CheckoutOrderReceipt receipt;
  final bool isInternational;
  final _CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isInternational ? 'Latest order' : '最新の注文';
    final placedLabel = isInternational ? 'Placed at' : '注文日時';
    final etaLabel = isInternational ? 'Estimated delivery' : 'お届け予定';
    final noteLabel = isInternational ? 'Instructions' : '連絡事項';
    final dateFormatter = DateFormat.yMMMd().add_Hm();
    final totalText = formatter.format(receipt.total);

    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTheme(
                  data: IconThemeData(color: theme.colorScheme.primary),
                  child: const Icon(Icons.check_circle_outline),
                ),
                const SizedBox(width: AppTokens.spaceS),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(receipt.orderId, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppTokens.spaceXS),
            Text(
              '$placedLabel: ${dateFormatter.format(receipt.placedAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (receipt.estimatedDelivery != null) ...[
              const SizedBox(height: AppTokens.spaceXS),
              Text(
                '$etaLabel: ${receipt.estimatedDelivery}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppTokens.spaceXS),
            Text(
              isInternational ? 'Total charged: $totalText' : '請求額: $totalText',
              style: theme.textTheme.bodyMedium,
            ),
            if (receipt.note != null && receipt.note!.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spaceS),
              Text(
                '$noteLabel: ${receipt.note}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyCartNotice extends StatelessWidget {
  const _EmptyCartNotice({required this.isInternational});

  final bool isInternational;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = isInternational
        ? 'Add items to your cart to place an order.'
        : 'ご注文にはカートに商品を追加してください。';
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}

class _CheckoutErrorView extends StatelessWidget {
  const _CheckoutErrorView({
    required this.message,
    required this.onRetry,
    required this.isInternational,
  });

  final String message;
  final Future<void> Function() onRetry;
  final bool isInternational;

  @override
  Widget build(BuildContext context) {
    final retryLabel = isInternational ? 'Retry' : '再試行';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

class _CurrencyFormatter {
  _CurrencyFormatter(this.experience);

  final ExperienceGate? experience;

  String format(double value) {
    final currencyCode = experience?.currencyCode ?? 'JPY';
    final locale = experience?.locale.toString() ?? 'ja_JP';
    final format = NumberFormat.currency(
      locale: locale,
      symbol: '',
      decimalDigits: currencyCode == 'JPY' ? 0 : 2,
    );
    final formatted = format.format(value);
    final symbol = experience?.currencySymbol ?? '¥';
    return '$symbol$formatted';
  }
}
