import 'package:flutter_test/flutter_test.dart';

import 'package:hankofield/app/localization/app_locale_view_model.dart';

void main() {
  test('legal urls point to the correct hosts', () {
    expect(termsUrlForLocaleCode('ja'), 'https://inkanfield.org/terms?lang=ja');
    expect(termsUrlForLocaleCode('en'), 'https://inkanfield.org/terms');

    expect(
      commercialTransactionsUrlForLocaleCode('ja'),
      'https://inkanfield.org/commercial-transactions?lang=ja',
    );
    expect(
      commercialTransactionsUrlForLocaleCode('en'),
      'https://inkanfield.org/commercial-transactions',
    );

    expect(
      privacyPolicyUrlForLocaleCode('ja'),
      'https://finitefield.org/privacy/',
    );
    expect(
      privacyPolicyUrlForLocaleCode('en'),
      'https://finitefield.org/en/privacy/',
    );

    expect(inquiryUrlForLocaleCode('ja'), 'https://finitefield.org/contact/');
    expect(
      inquiryUrlForLocaleCode('en'),
      'https://finitefield.org/en/contact/',
    );
  });
}
