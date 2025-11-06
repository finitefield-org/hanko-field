import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/domain/repositories/order_repository.dart';
import 'package:app/features/orders/application/order_invoice_provider.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fetches invoice metadata for order', () async {
    const orderId = 'hf-202404-017';
    final repository = _StubOrderRepository();
    final container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final invoice = await container.read(orderInvoiceProvider(orderId).future);

    expect(invoice.invoiceNumber, equals('INV-2024-017'));
    expect(invoice.isDownloadReady, isTrue);
    expect(invoice.amount, equals(14200));
  });
}

class _StubOrderRepository extends OrderRepository {
  _StubOrderRepository();

  @override
  Future<OrderInvoice> fetchInvoice(String orderId) async {
    return OrderInvoice(
      id: 'invoice-$orderId',
      orderId: orderId,
      invoiceNumber: 'INV-2024-017',
      status: OrderInvoiceStatus.issued,
      taxStatus: OrderInvoiceTaxStatus.inclusive,
      currency: 'JPY',
      amount: 14200,
      taxAmount: 1291,
      lineItems: const [
        OrderInvoiceLineItem(description: '黒水牛 薩摩本柘セット x1', amount: 13200),
        OrderInvoiceLineItem(description: '配送保険', amount: 1000),
      ],
      createdAt: DateTime(2024, 4, 18, 9),
      updatedAt: DateTime(2024, 4, 18, 9, 5),
      dueDate: DateTime(2024, 5, 2),
      pdfAssetRef: '/assets/invoices/INV-2024-017',
      downloadUrl:
          'https://storage.googleapis.com/hanko-dev-assets/invoices/INV-2024-017.pdf',
      metadata: const {'taxLabel': '消費税10%対象'},
    );
  }

  @override
  Future<List<Order>> fetchOrders({
    int? pageSize,
    String? pageToken,
    Map<String, dynamic>? filters,
  }) => Future.value(const <Order>[]);

  @override
  Future<Order> fetchOrder(String orderId) => throw UnimplementedError();

  @override
  Future<List<OrderPayment>> fetchPayments(String orderId) =>
      throw UnimplementedError();

  @override
  Future<List<OrderShipment>> fetchShipments(String orderId) =>
      throw UnimplementedError();

  @override
  Future<List<ProductionEvent>> fetchProductionEvents(String orderId) =>
      throw UnimplementedError();

  @override
  Future<Order> cancelOrder(String orderId, {String? reason}) =>
      throw UnimplementedError();

  @override
  Future<Order> requestInvoice(String orderId) => throw UnimplementedError();

  @override
  Future<Order> reorder(String orderId) => throw UnimplementedError();
}
