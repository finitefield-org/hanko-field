import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/domain/entities/order_reorder.dart';
import 'package:app/core/domain/repositories/order_repository.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:app/features/orders/presentation/order_reorder_screen.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders reorder preview with selectable lines', (tester) async {
    final order = _buildOrder();
    final repository = _StubOrderRepository(order);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OrderReorderScreen(orderId: order.id),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Reorder'), findsWidgets);
    expect(find.textContaining('items selected'), findsOneWidget);
    expect(find.text('Limited stock — ships a bit slower'), findsOneWidget);

    final firstCheckboxFinder = find.byType(Checkbox).first;
    expect(tester.widget<Checkbox>(firstCheckboxFinder).value, isTrue);

    await tester.tap(firstCheckboxFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(firstCheckboxFinder).value, isFalse);
  });
}

class _StubOrderRepository extends OrderRepository {
  _StubOrderRepository(this.order);

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
  Future<OrderInvoice> fetchInvoice(String orderId) async =>
      throw UnimplementedError();

  @override
  Future<Order> cancelOrder(String orderId, {String? reason}) async => order;

  @override
  Future<Order> requestInvoice(String orderId) async => order;

  @override
  Future<OrderReorderPreview> fetchReorderPreview(String orderId) async {
    return OrderReorderPreview(
      order: order,
      lines: [
        OrderReorderLine(
          id: 'line-1',
          item: order.lineItems.first,
          availability: OrderReorderLineAvailability.available,
        ),
        OrderReorderLine(
          id: 'line-2',
          item: order.lineItems.last,
          availability: OrderReorderLineAvailability.lowStock,
        ),
      ],
      generatedAt: DateTime(2024, 4, 18),
    );
  }

  @override
  Future<OrderReorderResult> reorder(
    String orderId, {
    Iterable<String>? lineIds,
  }) async {
    return OrderReorderResult(
      orderId: orderId,
      cartId: 'cart-$orderId',
      addedLineIds: lineIds?.toList() ?? const [],
      skippedLineIds: const [],
      priceAdjustedLineIds: const [],
      createdAt: DateTime(2024, 4, 18),
    );
  }
}

Order _buildOrder() {
  const firstLine = OrderLineItem(
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

  const secondLine = OrderLineItem(
    id: 'line-2',
    productRef: 'product-2',
    designRef: 'design-2',
    designSnapshot: {
      'emoji': '🪵',
      'background': 0xFFA5D6A7,
      'title': 'Wooden Case',
    },
    sku: 'SKU-002',
    name: 'Wooden Case',
    quantity: 1,
    unitPrice: 6800,
    total: 6800,
    options: {'finish': 'Matte'},
  );

  return Order(
    id: 'order-1',
    orderNumber: 'HF-001',
    userRef: 'user/test',
    status: OrderStatus.delivered,
    currency: 'JPY',
    totals: const OrderTotals(
      subtotal: 18800,
      discount: 0,
      shipping: 800,
      tax: 1880,
      fees: 0,
      total: 21480,
    ),
    promotion: null,
    lineItems: [firstLine, secondLine],
    shippingAddress: null,
    billingAddress: null,
    contact: null,
    fulfillment: null,
    production: null,
    notes: null,
    flags: null,
    audit: null,
    createdAt: DateTime(2024, 4, 10, 8),
    updatedAt: DateTime(2024, 4, 12, 12),
    placedAt: DateTime(2024, 4, 10, 8),
    paidAt: DateTime(2024, 4, 10, 8, 30),
    shippedAt: DateTime(2024, 4, 11),
    deliveredAt: DateTime(2024, 4, 12),
    canceledAt: null,
    cancelReason: null,
    metadata: const {},
  );
}
