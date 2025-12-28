// ignore_for_file: public_member_api_docs, deprecated_member_use

import 'package:app/features/payments/payment_method_form.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/buttons/app_button.dart';
import 'package:app/ui/forms/app_text_field.dart';
import 'package:flutter/material.dart';

class PaymentMethodFormSheet extends StatefulWidget {
  const PaymentMethodFormSheet({super.key});

  @override
  State<PaymentMethodFormSheet> createState() => _PaymentMethodFormSheetState();
}

class _PaymentMethodFormSheetState extends State<PaymentMethodFormSheet> {
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
    final l10n = AppLocalizations.of(context);

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
                  l10n.paymentMethodSheetTitle,
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
                label: Text(l10n.paymentMethodSheetCard),
                icon: const Icon(Icons.credit_card_outlined),
              ),
              ButtonSegment(
                value: PaymentMethodType.wallet,
                label: Text(l10n.paymentMethodSheetWallet),
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
              label: l10n.paymentMethodSheetBrandLabel,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: tokens.spacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _last4Ctrl,
                    label: l10n.paymentMethodSheetLast4Label,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _expMonthCtrl,
                    label: l10n.paymentMethodSheetExpMonthLabel,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _expYearCtrl,
                    label: l10n.paymentMethodSheetExpYearLabel,
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
            label: l10n.paymentMethodSheetBillingNameLabel,
          ),
          SizedBox(height: tokens.spacing.lg),
          AppButton(
            label: l10n.paymentMethodSheetSave,
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
