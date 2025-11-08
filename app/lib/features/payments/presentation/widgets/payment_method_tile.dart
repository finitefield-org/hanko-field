import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/domain/checkout_payment_models.dart';
import 'package:flutter/material.dart';

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.method,
    required this.isInternational,
    this.selectedMethodId,
    this.onSelect,
    this.trailingAccessory,
    this.additionalDetails = const <String>[],
    this.showSelectionIndicator = true,
    this.disabled = false,
    this.showBusyIndicator = false,
    this.defaultBadgeLabel,
  });

  final CheckoutPaymentMethodSummary method;
  final bool isInternational;
  final String? selectedMethodId;
  final ValueChanged<String>? onSelect;
  final Widget? trailingAccessory;
  final List<String> additionalDetails;
  final bool showSelectionIndicator;
  final bool disabled;
  final bool showBusyIndicator;
  final String? defaultBadgeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleLines = _buildSubtitleLines();
    final isSelected = selectedMethodId == method.id;
    final trailingChildren = <Widget>[];

    if (showSelectionIndicator) {
      trailingChildren.add(
        Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? theme.colorScheme.primary : theme.iconTheme.color,
        ),
      );
    }
    if (trailingAccessory != null) {
      trailingChildren.add(trailingAccessory!);
    }
    if (showBusyIndicator) {
      trailingChildren.add(
        const Padding(
          padding: EdgeInsets.only(top: AppTokens.spaceS),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final trailing = trailingChildren.isEmpty
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: trailingChildren,
          );

    final chips = <Widget>[];
    if (method.isExpired) {
      chips.add(
        Chip(
          label: Text(isInternational ? 'Expired' : '有効期限切れ'),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: theme.colorScheme.errorContainer,
          labelStyle: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      );
    }
    if (defaultBadgeLabel != null && isSelected) {
      chips.add(
        Chip(
          label: Text(defaultBadgeLabel!),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: theme.colorScheme.primaryContainer,
          labelStyle: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppTokens.radiusL,
      child: InkWell(
        borderRadius: AppTokens.radiusL,
        onTap: disabled ? null : () => onSelect?.call(method.id),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PaymentBrandIcon(method: method),
              const SizedBox(width: AppTokens.spaceL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_primaryLabel(), style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppTokens.spaceXS),
                    for (final line in subtitleLines)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTokens.spaceXS,
                        ),
                        child: Text(line, style: theme.textTheme.bodySmall),
                      ),
                    if (chips.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                        child: Wrap(
                          spacing: AppTokens.spaceS,
                          runSpacing: AppTokens.spaceS,
                          children: chips,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppTokens.spaceM),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildSubtitleLines() {
    final lines = <String>[];
    final brandLabel = method.brand?.isNotEmpty == true
        ? method.brand!
        : _fallbackBrandLabel();
    final last4Digits = method.last4?.trim() ?? '';
    final maskedLast4 = last4Digits.isEmpty ? '••••' : last4Digits;
    final expiryLabel = _formatExpiry();

    lines.add(
      isInternational
          ? '$brandLabel •••• $maskedLast4'
          : '$brandLabel（下4桁 ${last4Digits.isEmpty ? '----' : last4Digits}）',
    );
    lines.add(isInternational ? 'Expires $expiryLabel' : '有効期限: $expiryLabel');
    if (method.billingName != null && method.billingName!.isNotEmpty) {
      lines.add(
        isInternational
            ? 'Billing name: ${method.billingName}'
            : '請求先氏名: ${method.billingName}',
      );
    }
    if (additionalDetails.isNotEmpty) {
      lines.addAll(additionalDetails);
    }
    return lines;
  }

  String _fallbackBrandLabel() {
    switch (method.provider) {
      case PaymentProvider.stripe:
        return isInternational ? 'Card' : 'カード';
      case PaymentProvider.paypal:
        return 'PayPal';
      case PaymentProvider.other:
        return isInternational ? 'Payment' : 'お支払い';
    }
  }

  String _primaryLabel() {
    switch (method.provider) {
      case PaymentProvider.stripe:
        return method.brand ?? (isInternational ? 'Card' : 'カード');
      case PaymentProvider.paypal:
        return 'PayPal';
      case PaymentProvider.other:
        return isInternational ? 'Payment method' : 'お支払い方法';
    }
  }

  String _formatExpiry() {
    if (!method.hasExpiry ||
        method.expMonth == null ||
        method.expYear == null) {
      return isInternational ? 'No expiry' : '有効期限なし';
    }
    final monthValue = method.expMonth!;
    final month = monthValue.toString().padLeft(2, '0');
    final year = method.expYear!;
    if (isInternational) {
      final shortYear = (year % 100).toString().padLeft(2, '0');
      return '$month/$shortYear';
    }
    return '$year年$monthValue月';
  }
}

class PaymentBrandIcon extends StatelessWidget {
  const PaymentBrandIcon({super.key, required this.method});

  final CheckoutPaymentMethodSummary method;

  @override
  Widget build(BuildContext context) {
    final icon = _resolveIcon();
    final color = Theme.of(context).colorScheme.primary;
    return Icon(icon, size: 32, color: color);
  }

  IconData _resolveIcon() {
    final brand = method.brand?.toLowerCase();
    if (brand == null) {
      return Icons.credit_card;
    }
    if (brand.contains('visa')) {
      return Icons.credit_card;
    }
    if (brand.contains('master')) {
      return Icons.credit_card;
    }
    if (brand.contains('amex') || brand.contains('american')) {
      return Icons.credit_card;
    }
    if (brand.contains('jcb')) {
      return Icons.credit_card;
    }
    if (brand.contains('paypal')) {
      return Icons.account_balance_wallet_outlined;
    }
    return Icons.credit_card;
  }
}
