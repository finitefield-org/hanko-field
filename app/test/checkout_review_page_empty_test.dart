import 'package:app/core/model/value_objects.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/features/checkout/view/checkout_review_page.dart';
import 'package:app/features/checkout/view_model/checkout_review_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('CheckoutReviewPage shows empty cart state', (tester) async {
    const cart = CartState(
      lines: [],
      estimate: CartEstimate(
        minDays: 0,
        maxDays: 0,
        methodLabel: 'Standard',
        international: false,
      ),
    );
    const state = CheckoutReviewState(
      cart: cart,
      isInternational: false,
      address: null,
      shipping: null,
      payment: null,
      shippingCost: Money(amount: 0, currency: 'JPY'),
      tax: Money(amount: 0, currency: 'JPY'),
      total: Money(amount: 0, currency: 'JPY'),
    );

    final reviewOverride = Provider<AsyncValue<CheckoutReviewState>>(
      (_) => const AsyncData<CheckoutReviewState>(state),
    );
    final overrides = [
      ...buildTestOverrides(),
      checkoutReviewViewModel.overrideWith(reviewOverride),
    ];

    await tester.pumpWidget(
      buildTestApp(child: const CheckoutReviewPage(), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cart is empty'), findsOneWidget);
    expect(find.text('Back to cart'), findsOneWidget);
  });
}
