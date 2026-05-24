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

  test('parses checkout failure returns', () {
    final result = parseCheckoutReturnRoute(
      'hankofield://checkout/failed?order_id=ord_003&checkout_session_id=cs_test_003',
    );

    expect(result?.outcome, CheckoutReturnOutcome.failed);
    expect(result?.orderId, 'ord_003');
    expect(result?.sessionId, 'cs_test_003');
  });

  test('ignores unrelated app routes', () {
    expect(parseCheckoutReturnRoute('/design'), isNull);
    expect(parseCheckoutReturnRoute('/design?checkout=success'), isNull);
  });

  test('detects malformed checkout return routes', () {
    expect(
      isMalformedCheckoutReturnRoute(
        'hankofield://checkout/unknown?session_id=cs_test_001',
      ),
      isTrue,
    );
    expect(isMalformedCheckoutReturnRoute('/design?checkout=success'), isFalse);
  });
}
