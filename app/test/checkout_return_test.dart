import 'package:flutter_test/flutter_test.dart';
import 'package:hankofield/features/order/order.dart';

void main() {
  test('parses custom scheme checkout success returns', () {
    final result = parseCheckoutReturnRoute(
      'hankofield://checkout/success?order_id=ord_001&session_id=cs_test_001&lang=ja',
    );

    expect(result?.outcome, CheckoutReturnOutcome.success);
    expect(result?.orderId, 'ord_001');
    expect(result?.sessionId, 'cs_test_001');
    expect(result?.locale, 'ja');
  });

  test('parses localized web checkout cancel returns', () {
    final result = parseCheckoutReturnRoute(
      'https://finitefield.org/ja/payment/cancel?checkout=cancel&order_id=ord_002',
    );

    expect(result?.outcome, CheckoutReturnOutcome.canceled);
    expect(result?.orderId, 'ord_002');
  });

  test('ignores unrelated app routes', () {
    expect(parseCheckoutReturnRoute('/design'), isNull);
    expect(parseCheckoutReturnRoute('/design?checkout=success'), isNull);
  });
}
