import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/domain/repositories/order_repository.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:app/features/orders/presentation/order_details_screen.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  testWidgets('renders order summary with items and actions', (tester) async {
    final order = _buildTestOrder();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(
            _TestOrderRepository(order),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OrderDetailsScreen(orderId: order.orderNumber),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Order ${order.orderNumber}'), findsWidgets);

    final context = tester.element(find.byType(OrderDetailsScreen));
    final l10n = AppLocalizations.of(context);

    final totalLabel = NumberFormat.currency(
      locale: 'en',
      symbol: '¥',
      decimalDigits: 0,
    ).format(order.totals.total);

    expect(find.text(totalLabel), findsWidgets);
    expect(find.text(l10n.orderDetailsActionSupport), findsOneWidget);
  });
}

class _TestOrderRepository extends OrderRepository {
  _TestOrderRepository(this.order);

  final Order order;

  @override
  Future<List<Order>> fetchOrders({
    int? pageSize,
    String? pageToken,
    Map<String, dynamic>? filters,
  }) async {
    return [order];
  }

  @override
  Future<Order> fetchOrder(String orderId) async => order;

  @override
  Future<List<OrderPayment>> fetchPayments(String orderId) async => const [];

  @override
  Future<List<OrderShipment>> fetchShipments(String orderId) async => const [];

  @override
  Future<List<ProductionEvent>> fetchProductionEvents(String orderId) async =>
      const [];

  @override
  Future<Order> cancelOrder(String orderId, {String? reason}) async => order;

  @override
  Future<Order> requestInvoice(String orderId) async => order;

  @override
  Future<Order> reorder(String orderId) async => order;
}

Order _buildTestOrder() {
  const lineItem = OrderLineItem(
    id: 'line-1',
    productRef: 'product-1',
    designRef: 'design-1',
    designSnapshot: {
      'emoji': '🖋️',
      'background': 0xFFB39DDB,
      'title': 'Signature Seal',
    },
    sku: 'SKU-001',
    name: 'Signature Seal',
    quantity: 1,
    unitPrice: 12000,
    total: 12000,
    options: {'script': '楷書体'},
  );

  return Order(
    id: 'order-1',
    orderNumber: 'HF-001',
    userRef: 'user/test',
    status: OrderStatus.pendingPayment,
    currency: 'JPY',
    totals: const OrderTotals(
      subtotal: 12000,
      discount: 0,
      shipping: 800,
      tax: 1200,
      fees: 0,
      total: 14000,
    ),
    promotion: null,
    lineItems: [lineItem],
    shippingAddress: const OrderAddress(
      recipient: '佐藤 太郎',
      line1: '東京都渋谷区道玄坂 1-12-1',
      line2: 'マークシティ 22F',
      city: '渋谷区',
      state: '東京都',
      postalCode: '150-0043',
      country: '日本',
      phone: '03-4520-1234',
    ),
    billingAddress: const OrderAddress(
      recipient: '佐藤 太郎',
      line1: '東京都港区南青山 2-11-17',
      city: '港区',
      state: '東京都',
      postalCode: '107-0062',
      country: '日本',
      phone: '03-4520-5678',
    ),
    contact: const OrderContact(
      email: 'taro.sato@example.com',
      phone: '090-1234-5678',
    ),
    fulfillment: null,
    production: null,
    notes: null,
    flags: null,
    audit: null,
    createdAt: DateTime(2024, 4, 1, 8, 0),
    updatedAt: DateTime(2024, 4, 1, 8, 30),
    placedAt: DateTime(2024, 4, 1, 7, 45),
    paidAt: DateTime(2024, 4, 1, 9, 0),
    shippedAt: null,
    deliveredAt: null,
    canceledAt: null,
    cancelReason: null,
    metadata: const {'emoji': '🖋️'},
  );
}
