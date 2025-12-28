// ignore_for_file: public_member_api_docs

import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/localization/app_localizations.dart';

class PaymentMethodDraft {
  const PaymentMethodDraft({
    this.provider = PaymentProvider.stripe,
    this.methodType = PaymentMethodType.card,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.billingName,
  });

  final PaymentProvider provider;
  final PaymentMethodType methodType;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final String? billingName;
}

class PaymentValidationResult {
  const PaymentValidationResult({this.fieldErrors = const {}, this.message});

  final Map<String, String> fieldErrors;
  final String? message;

  bool get isValid => fieldErrors.isEmpty && message == null;
}

PaymentValidationResult validatePaymentDraft(
  PaymentMethodDraft draft,
  AppLocalizations l10n,
) {
  final errors = <String, String>{};
  final last4 = draft.last4?.trim();
  if (draft.methodType == PaymentMethodType.card) {
    if (last4 == null || last4.length != 4) {
      errors['last4'] = l10n.paymentMethodErrorLast4;
    }
    if (draft.expMonth == null || draft.expMonth! < 1 || draft.expMonth! > 12) {
      errors['expMonth'] = l10n.paymentMethodErrorExpMonth;
    }
    if (draft.expYear == null || draft.expYear! < DateTime.now().year) {
      errors['expYear'] = l10n.paymentMethodErrorExpYear;
    }
  }

  return PaymentValidationResult(
    fieldErrors: errors,
    message: errors.isEmpty ? null : l10n.paymentMethodErrorFixFields,
  );
}
