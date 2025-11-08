import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/checkout_payment_controller.dart';
import 'package:flutter/material.dart';

class TokenizedPaymentMethodForm extends StatefulWidget {
  const TokenizedPaymentMethodForm({
    super.key,
    required this.experience,
    required this.existingMethodCount,
  });

  final ExperienceGate? experience;
  final int existingMethodCount;

  @override
  State<TokenizedPaymentMethodForm> createState() =>
      _TokenizedPaymentMethodFormState();
}

class _TokenizedPaymentMethodFormState
    extends State<TokenizedPaymentMethodForm> {
  final _formKey = GlobalKey<FormState>();
  final _cardHolderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _walletEmailController = TextEditingController();
  PaymentProvider _selectedProvider = PaymentProvider.stripe;
  bool _reuseShippingAddress = true;

  @override
  void dispose() {
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _walletEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIntl = widget.experience?.isInternational ?? false;
    final title = isIntl ? 'Add payment method' : 'お支払い方法を追加';
    final nameLabel = isIntl ? 'Cardholder name' : 'カード名義';
    final numberLabel = isIntl ? 'Card number' : 'カード番号';
    final expiryLabel = isIntl ? 'Expiry (MM/YY)' : '有効期限 (MM/YY)';
    final cvcLabel = isIntl ? 'CVC' : 'セキュリティコード';
    final billingLabel = isIntl ? 'Billing address' : '請求先住所';
    final useShipping = isIntl ? 'Use shipping address' : '配送先住所を使用';
    final customBilling = isIntl ? 'Enter billing address later' : '別の住所を後で入力';
    final providerLabel = isIntl ? 'Provider' : '決済プロバイダ';
    final walletEmailLabel = isIntl ? 'Account email' : 'アカウントのメールアドレス';
    final saveLabel = isIntl ? 'Save method' : '追加する';
    final helper = isIntl
        ? 'Your details are tokenized by our PSP.'
        : '入力情報は決済代行でトークン化され安全に保存されます。';
    final capacity = isIntl ? 5 : 3;
    final usageLabel = isIntl
        ? 'Stored methods: ${widget.existingMethodCount}/$capacity'
        : '保存済み: ${widget.existingMethodCount}/$capacity 件';

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTokens.spaceS),
            Text(helper, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppTokens.spaceXS),
            Text(usageLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppTokens.spaceL),
            DropdownButtonFormField<PaymentProvider>(
              initialValue: _selectedProvider,
              decoration: InputDecoration(labelText: providerLabel),
              items: PaymentProvider.values
                  .map(
                    (provider) => DropdownMenuItem<PaymentProvider>(
                      value: provider,
                      child: Text(_providerLabel(provider, isIntl)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedProvider = value;
                });
              },
            ),
            const SizedBox(height: AppTokens.spaceM),
            if (_selectedProvider == PaymentProvider.stripe) ...[
              TextFormField(
                controller: _cardHolderController,
                decoration: InputDecoration(labelText: nameLabel),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return isIntl
                        ? 'Enter the cardholder name'
                        : 'カード名義を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.spaceM),
              TextFormField(
                controller: _cardNumberController,
                decoration: InputDecoration(labelText: numberLabel),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                  if (digits.length < 12) {
                    return isIntl
                        ? 'Enter a valid card number'
                        : '正しいカード番号を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.spaceM),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      decoration: InputDecoration(labelText: expiryLabel),
                      keyboardType: TextInputType.datetime,
                      validator: (value) {
                        if (!_validateExpiry(value)) {
                          return isIntl ? 'Invalid expiry' : '有効期限が正しくありません';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceM),
                  Expanded(
                    child: TextFormField(
                      controller: _cvcController,
                      decoration: InputDecoration(labelText: cvcLabel),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (value) {
                        final digits =
                            value?.replaceAll(RegExp(r'\D'), '') ?? '';
                        if (digits.length < 3) {
                          return isIntl ? 'Enter CVC' : 'CVC を入力してください';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextFormField(
                controller: _walletEmailController,
                decoration: InputDecoration(labelText: walletEmailLabel),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return isIntl
                        ? 'Enter a valid account email'
                        : '有効なメールアドレスを入力してください';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: AppTokens.spaceL),
            Text(billingLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTokens.spaceS),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  label: Text(useShipping),
                  icon: const Icon(Icons.home_outlined),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text(customBilling),
                  icon: const Icon(Icons.edit_location_alt_outlined),
                ),
              ],
              selected: {_reuseShippingAddress},
              onSelectionChanged: (selection) {
                setState(() {
                  _reuseShippingAddress = selection.first;
                });
              },
            ),
            const SizedBox(height: AppTokens.spaceL),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _submit, child: Text(saveLabel)),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final token = _generateProviderRef();
    final provider = _selectedProvider;
    final methodType = provider == PaymentProvider.paypal
        ? PaymentMethodType.wallet
        : PaymentMethodType.card;
    String? brand;
    String? last4;
    int? expMonth;
    int? expYear;
    String? billingName;

    if (provider == PaymentProvider.stripe) {
      final number = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
      brand = _detectBrand(number);
      last4 = number.length >= 4 ? number.substring(number.length - 4) : null;
      final expiryParts = _parseExpiry(_expiryController.text);
      expMonth = expiryParts.$1;
      expYear = expiryParts.$2;
      billingName = _cardHolderController.text.trim();
    } else {
      brand = 'PayPal';
      billingName = _walletEmailController.text.trim();
    }

    final payload = TokenizedPaymentMethodPayload(
      provider: provider,
      methodType: methodType,
      providerRef: token,
      brand: brand,
      last4: last4,
      expMonth: expMonth,
      expYear: expYear,
      billingName: billingName,
    );

    Navigator.of(context).pop(payload);
  }

  bool _validateExpiry(String? value) {
    final match = RegExp(
      r'^(0[1-9]|1[0-2])/?([0-9]{2})$',
    ).firstMatch(value?.trim() ?? '');
    if (match == null) {
      return false;
    }
    final month = int.parse(match.group(1)!);
    final year = int.parse(match.group(2)!);
    final normalizedYear = 2000 + year;
    final now = DateTime.now();
    final expiry = DateTime(normalizedYear, month);
    final normalizedNow = DateTime(now.year, now.month);
    return !expiry.isBefore(normalizedNow);
  }

  (int?, int?) _parseExpiry(String value) {
    final match = RegExp(
      r'^(0[1-9]|1[0-2])/?([0-9]{2})$',
    ).firstMatch(value.trim());
    if (match == null) {
      return (null, null);
    }
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    return (month, year);
  }

  String _generateProviderRef() {
    final prefix = _selectedProvider == PaymentProvider.paypal
        ? 'paypal'
        : 'tok';
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _detectBrand(String digits) {
    if (digits.startsWith('4')) {
      return 'Visa';
    }
    if (digits.startsWith('5')) {
      return 'Mastercard';
    }
    if (digits.startsWith('34') || digits.startsWith('37')) {
      return 'American Express';
    }
    if (digits.startsWith('35')) {
      return 'JCB';
    }
    if (digits.startsWith('6')) {
      return 'Discover';
    }
    return 'Card';
  }

  String _providerLabel(PaymentProvider provider, bool isIntl) {
    switch (provider) {
      case PaymentProvider.stripe:
        return isIntl ? 'Stripe (Card)' : 'Stripe（カード）';
      case PaymentProvider.paypal:
        return 'PayPal';
      case PaymentProvider.other:
        return isIntl ? 'Other provider' : 'その他のプロバイダ';
    }
  }
}
