import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/checkout_payment_controller.dart';
import 'package:app/features/cart/domain/checkout_payment_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckoutPaymentScreen extends ConsumerStatefulWidget {
  const CheckoutPaymentScreen({super.key});

  @override
  ConsumerState<CheckoutPaymentScreen> createState() =>
      _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends ConsumerState<CheckoutPaymentScreen> {
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

  Future<void> _startAddMethod(
    CheckoutPaymentState? state,
    ExperienceGate? experience,
  ) async {
    if (state == null || !state.canAddNewMethod) {
      final message = experience?.isInternational ?? false
          ? 'You have reached the maximum number of stored methods.'
          : '登録できるお支払い方法の上限に達しています。';
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final payload = await showModalBottomSheet<TokenizedPaymentMethodPayload>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppTokens.spaceL,
          right: AppTokens.spaceL,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTokens.spaceL,
          top: AppTokens.spaceL,
        ),
        child: _AddPaymentMethodSheet(
          experience: experience,
          existingMethodCount: state.methods.length,
        ),
      ),
    );
    if (payload == null) {
      return;
    }
    await _controller.registerTokenizedMethod(payload);
  }

  Future<void> _handleConfirm(
    CheckoutPaymentState state,
    ExperienceGate? experience,
  ) async {
    if (state.selectedMethodId == null) {
      final message = experience?.isInternational ?? false
          ? 'Select a payment method to continue.'
          : '続けるにはお支払い方法を選択してください。';
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final asyncExperience = ref.watch(experienceGateProvider);
    final experience = asyncExperience.value;
    final asyncState = ref.watch(checkoutPaymentControllerProvider);
    final state = asyncState.asData?.value;
    final isIntl = experience?.isInternational ?? false;

    final title = isIntl ? 'Payment methods' : 'お支払い方法';
    final addTooltip = isIntl ? 'Add payment method' : '支払い方法を追加';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: addTooltip,
            onPressed:
                state == null ||
                    state.isProcessing ||
                    state.isAdding ||
                    !state.canAddNewMethod
                ? null
                : () => _startAddMethod(state, experience),
            icon: const Icon(Icons.add_card_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _PaymentLoadingView(),
          error: (error, stackTrace) => _PaymentErrorView(
            message: error.toString(),
            onRetry: _controller.refresh,
            isInternational: isIntl,
          ),
          data: (data) => RefreshIndicator(
            onRefresh: _controller.refresh,
            child: _PaymentMethodListView(
              state: data,
              isInternational: isIntl,
              controller: _controller,
              scrollController: _scrollController,
            ),
          ),
        ),
      ),
      bottomNavigationBar: asyncState.maybeWhen(
        data: (data) {
          final continueLabel = isIntl ? 'Continue' : '次へ';
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceS,
              AppTokens.spaceL,
              AppTokens.spaceL,
            ),
            child: FilledButton(
              onPressed: data.isProcessing
                  ? null
                  : () => _handleConfirm(data, experience),
              child: Text(continueLabel),
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _PaymentMethodListView extends StatelessWidget {
  const _PaymentMethodListView({
    required this.state,
    required this.isInternational,
    required this.controller,
    required this.scrollController,
  });

  final CheckoutPaymentState state;
  final bool isInternational;
  final CheckoutPaymentController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (!state.hasMethods) {
      final headline = isInternational
          ? 'Add a payment method to complete checkout.'
          : 'チェックアウトを完了するにはお支払い方法を追加してください。';
      final helper = isInternational
          ? 'We securely store card tokens via our payment provider.'
          : 'カード情報は決済プロバイダでトークン化され安全に管理されます。';
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.spaceXXL),
        children: [
          Icon(
            Icons.credit_card_off_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            headline,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.only(
        left: AppTokens.spaceL,
        right: AppTokens.spaceL,
        top: AppTokens.spaceL,
        bottom: AppTokens.spaceXXL,
      ),
      itemBuilder: (context, index) {
        if (index == 0 && state.isProcessing) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        final method = state.methods[state.isProcessing ? index - 1 : index];
        final selected = method.id == state.selectedMethodId;
        return _PaymentMethodTile(
          method: method,
          isInternational: isInternational,
          isSelected: selected,
          onSelect: () => controller.selectMethod(method.id),
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppTokens.spaceM),
      itemCount: state.isProcessing
          ? state.methods.length + 1
          : state.methods.length,
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.isInternational,
    required this.isSelected,
    required this.onSelect,
  });

  final CheckoutPaymentMethodSummary method;
  final bool isInternational;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = <String>[];
    final brandLabel = method.brand?.isNotEmpty == true
        ? method.brand!
        : _fallbackBrandLabel(method);
    final last4Digits = method.last4?.trim() ?? '';
    final maskedLast4 = last4Digits.isEmpty ? '••••' : last4Digits;
    final expiryLabel = _formatExpiry(method, isInternational);

    subtitle.add(
      isInternational
          ? '$brandLabel •••• $maskedLast4'
          : '$brandLabel（下4桁 ${last4Digits.isEmpty ? '----' : last4Digits}）',
    );
    subtitle.add(
      isInternational ? 'Expires $expiryLabel' : '有効期限: $expiryLabel',
    );
    if (method.billingName != null && method.billingName!.isNotEmpty) {
      subtitle.add(
        isInternational
            ? 'Billing name: ${method.billingName}'
            : '請求先氏名: ${method.billingName}',
      );
    }

    final expiredLabel = isInternational ? 'Expired' : '有効期限切れ';
    final trailing = isSelected
        ? const Icon(Icons.radio_button_checked)
        : const Icon(Icons.radio_button_off);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppTokens.radiusL,
      child: InkWell(
        borderRadius: AppTokens.radiusL,
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PaymentBrandIcon(method: method),
              const SizedBox(width: AppTokens.spaceL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _primaryLabel(method, isInternational),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.spaceXS),
                    for (final line in subtitle)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTokens.spaceXS,
                        ),
                        child: Text(line, style: theme.textTheme.bodySmall),
                      ),
                    if (method.isExpired)
                      Chip(
                        label: Text(expiredLabel),
                        backgroundColor: theme.colorScheme.errorContainer,
                        labelStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  String _fallbackBrandLabel(CheckoutPaymentMethodSummary method) {
    switch (method.provider) {
      case PaymentProvider.stripe:
        return 'Card';
      case PaymentProvider.paypal:
        return 'PayPal';
      case PaymentProvider.other:
        return 'Payment';
    }
  }

  String _primaryLabel(
    CheckoutPaymentMethodSummary method,
    bool isInternational,
  ) {
    switch (method.provider) {
      case PaymentProvider.stripe:
        return method.brand ?? (isInternational ? 'Card' : 'カード');
      case PaymentProvider.paypal:
        return 'PayPal';
      case PaymentProvider.other:
        return isInternational ? 'Payment method' : 'お支払い方法';
    }
  }

  String _formatExpiry(
    CheckoutPaymentMethodSummary method,
    bool isInternational,
  ) {
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

class _PaymentBrandIcon extends StatelessWidget {
  const _PaymentBrandIcon({required this.method});

  final CheckoutPaymentMethodSummary method;

  @override
  Widget build(BuildContext context) {
    final icon = _resolveIcon(method);
    final color = Theme.of(context).colorScheme.primary;
    return Icon(icon, size: 32, color: color);
  }

  IconData _resolveIcon(CheckoutPaymentMethodSummary method) {
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

class _PaymentLoadingView extends StatelessWidget {
  const _PaymentLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _PaymentErrorView extends StatelessWidget {
  const _PaymentErrorView({
    required this.message,
    required this.onRetry,
    required this.isInternational,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isInternational;

  @override
  Widget build(BuildContext context) {
    final retryLabel = isInternational ? 'Retry' : '再試行';
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.spaceL),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

class _AddPaymentMethodSheet extends StatefulWidget {
  const _AddPaymentMethodSheet({
    required this.experience,
    required this.existingMethodCount,
  });

  final ExperienceGate? experience;
  final int existingMethodCount;

  @override
  State<_AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<_AddPaymentMethodSheet> {
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
