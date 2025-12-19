// ignore_for_file: public_member_api_docs

import 'package:app/features/users/data/models/user_models.dart';

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
  bool prefersEnglish,
) {
  final errors = <String, String>{};
  final last4 = draft.last4?.trim();
  if (draft.methodType == PaymentMethodType.card) {
    if (last4 == null || last4.length != 4) {
      errors['last4'] = prefersEnglish ? 'Enter last 4 digits' : '下4桁を入力してください';
    }
    if (draft.expMonth == null || draft.expMonth! < 1 || draft.expMonth! > 12) {
      errors['expMonth'] = prefersEnglish
          ? 'Enter expiry month'
          : '有効期限(月)を入力してください';
    }
    if (draft.expYear == null || draft.expYear! < DateTime.now().year) {
      errors['expYear'] = prefersEnglish
          ? 'Enter expiry year'
          : '有効期限(年)を入力してください';
    }
  }

  return PaymentValidationResult(
    fieldErrors: errors,
    message: errors.isEmpty
        ? null
        : (prefersEnglish ? 'Fix the highlighted fields' : '入力内容を確認してください'),
  );
}
