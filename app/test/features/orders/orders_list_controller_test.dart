import 'dart:async';

import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/domain/repositories/order_repository.dart';
import 'package:app/features/orders/application/orders_list_controller.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:app/features/orders/domain/order_list_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  late ProviderContainer container;
  late OrderRepository repository;

  setUp(() {
    repository = _TestOrderRepository();
    container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Future<OrdersListState> pumpInitialState() {
    return container.read(ordersListControllerProvider.future);
  }

  test('loads initial page with pagination metadata', () async {
    final state = await pumpInitialState();
    expect(state.orders, hasLength(OrdersListController.pageSize));
    expect(state.hasMore, isTrue);
    expect(state.nextCursor, isNotNull);
    expect(
      state.orders.first.createdAt.isAfter(state.orders.last.createdAt),
      isTrue,
    );
  });

  test('loadMore appends additional orders without duplicates', () async {
    await pumpInitialState();
    final notifier = container.read(ordersListControllerProvider.notifier);
    await notifier.loadMore();

    final asyncState = container.read(ordersListControllerProvider);
    final state = asyncState.asData!.value;

    expect(state.orders.length, greaterThan(OrdersListController.pageSize));
    expect(
      state.orders.map((order) => order.id).toSet().length,
      state.orders.length,
    );
  });

  test('changing status filter refreshes with matching orders only', () async {
    await pumpInitialState();
    final notifier = container.read(ordersListControllerProvider.notifier);

    notifier.changeStatus(OrderStatusGroup.delivered);
    final state = await pumpInitialState();

    expect(state.filter.status, OrderStatusGroup.delivered);
    expect(state.orders, isNotEmpty);
    expect(
      state.orders.every((order) => order.status == OrderStatus.delivered),
      isTrue,
    );
  });

  test('ignores stale loadMore result after filter changes', () async {
    container.dispose();
    final blockingRepo = _BlockingOrderRepository();
    repository = blockingRepo;
    container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(blockingRepo)],
    );

    await pumpInitialState();
    final notifier = container.read(ordersListControllerProvider.notifier);

    final loadStarted = blockingRepo.waitForLoadMoreStart();
    final loadFuture = notifier.loadMore();
    await loadStarted;

    notifier.changeStatus(OrderStatusGroup.delivered);
    final deliveredState = await pumpInitialState();
    expect(deliveredState.filter.status, OrderStatusGroup.delivered);

    blockingRepo.allowLoadMore();
    await loadFuture;

    final finalState = await pumpInitialState();
    expect(finalState.filter.status, OrderStatusGroup.delivered);
    expect(
      finalState.orders.every((order) => order.status == OrderStatus.delivered),
      isTrue,
    );
  });
}

class _TestOrderRepository extends OrderRepository {
  _TestOrderRepository()
    : _orders = _createOrderDataset(),
      _index = <String, Order>{} {
    for (final order in _orders) {
      _index[order.id] = order;
    }
  }

  final List<Order> _orders;
  final Map<String, Order> _index;

  @override
  Future<List<Order>> fetchOrders({
    int? pageSize,
    String? pageToken,
    Map<String, dynamic>? filters,
  }) async {
    final filter = OrderListFilter.fromMap(filters);
    final filtered = _filterOrdersForTest(_orders, filter);
    final start = _startIndex(filtered, pageToken);
    final limit = pageSize ?? _kDefaultPageSize;
    return filtered.skip(start).take(limit).toList();
  }

  @override
  Future<Order> fetchOrder(String orderId) async {
    final order = _index[orderId];
    if (order == null) {
      throw StateError('Order $orderId not found');
    }
    return order;
  }

  @override
  Future<List<OrderPayment>> fetchPayments(String orderId) async {
    return const <OrderPayment>[];
  }

  @override
  Future<List<OrderShipment>> fetchShipments(String orderId) async {
    return const <OrderShipment>[];
  }

  @override
  Future<List<ProductionEvent>> fetchProductionEvents(String orderId) async {
    return const <ProductionEvent>[];
  }

  @override
  Future<OrderInvoice> fetchInvoice(String orderId) async {
    final order = await fetchOrder(orderId);
    return OrderInvoice(
      id: 'invoice-$orderId',
      orderId: orderId,
      invoiceNumber: 'TEST-$orderId',
      status: OrderInvoiceStatus.draft,
      taxStatus: OrderInvoiceTaxStatus.inclusive,
      currency: order.currency,
      amount: order.totals.total,
      taxAmount: order.totals.tax,
      lineItems: const [],
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
    );
  }

  @override
  Future<Order> cancelOrder(String orderId, {String? reason}) {
    return fetchOrder(orderId);
  }

  @override
  Future<Order> requestInvoice(String orderId) {
    return fetchOrder(orderId);
  }

  @override
  Future<Order> reorder(String orderId) {
    return fetchOrder(orderId);
  }
}

class _BlockingOrderRepository extends OrderRepository {
  _BlockingOrderRepository()
    : _orders = _createOrderDataset(),
      _index = <String, Order>{} {
    for (final order in _orders) {
      _index[order.id] = order;
    }
  }

  final List<Order> _orders;
  final Map<String, Order> _index;
  Completer<void>? _loadMoreGate;
  Completer<void>? _loadMoreStarted;
  bool _loadMoreInProgress = false;

  Future<void> waitForLoadMoreStart() {
    if (_loadMoreInProgress) {
      return Future.value();
    }
    _loadMoreStarted = Completer<void>();
    return _loadMoreStarted!.future;
  }

  void allowLoadMore() {
    _loadMoreGate?.complete();
    _loadMoreGate = null;
    _loadMoreInProgress = false;
  }

  @override
  Future<List<Order>> fetchOrders({
    int? pageSize,
    String? pageToken,
    Map<String, dynamic>? filters,
  }) async {
    final filter = OrderListFilter.fromMap(filters);
    final filtered = _filterOrdersForTest(_orders, filter);
    if (pageToken != null) {
      _loadMoreInProgress = true;
      if (_loadMoreStarted != null && !_loadMoreStarted!.isCompleted) {
        _loadMoreStarted!.complete();
      }
      _loadMoreStarted = null;
      _loadMoreGate = Completer<void>();
      await _loadMoreGate!.future;
      _loadMoreGate = null;
      _loadMoreInProgress = false;
    }
    final start = _startIndex(filtered, pageToken);
    final limit = pageSize ?? _kDefaultPageSize;
    return filtered.skip(start).take(limit).toList();
  }

  @override
  Future<Order> fetchOrder(String orderId) async {
    final order = _index[orderId];
    if (order == null) {
      throw StateError('Order $orderId not found');
    }
    return order;
  }

  @override
  Future<List<OrderPayment>> fetchPayments(String orderId) async {
    return const <OrderPayment>[];
  }

  @override
  Future<List<OrderShipment>> fetchShipments(String orderId) async {
    return const <OrderShipment>[];
  }

  @override
  Future<List<ProductionEvent>> fetchProductionEvents(String orderId) async {
    return const <ProductionEvent>[];
  }

  @override
  Future<OrderInvoice> fetchInvoice(String orderId) async {
    final order = await fetchOrder(orderId);
    return OrderInvoice(
      id: 'invoice-$orderId',
      orderId: orderId,
      invoiceNumber: 'TEST-$orderId',
      status: OrderInvoiceStatus.draft,
      taxStatus: OrderInvoiceTaxStatus.inclusive,
      currency: order.currency,
      amount: order.totals.total,
      taxAmount: order.totals.tax,
      lineItems: const [],
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
    );
  }

  @override
  Future<Order> cancelOrder(String orderId, {String? reason}) {
    return fetchOrder(orderId);
  }

  @override
  Future<Order> requestInvoice(String orderId) {
    return fetchOrder(orderId);
  }

  @override
  Future<Order> reorder(String orderId) {
    return fetchOrder(orderId);
  }
}

const _kDefaultPageSize = 20;
final _kTestNow = DateTime(2024, 4, 20);

List<Order> _filterOrdersForTest(List<Order> orders, OrderListFilter filter) {
  return [
    for (final order in orders)
      if (filter.matches(order, _kTestNow)) order,
  ];
}

int _startIndex(List<Order> orders, String? cursor) {
  if (cursor == null) {
    return 0;
  }
  final index = orders.indexWhere((order) => order.id == cursor);
  if (index == -1) {
    return 0;
  }
  return index + 1;
}

List<Order> _createOrderDataset() {
  final base = _kTestNow;
  final orders = <Order>[
    _buildTestOrder(
      id: 'order-18',
      number: 'HF-202404-018',
      status: OrderStatus.pendingPayment,
      createdAt: base.subtract(const Duration(days: 1)),
      total: 12800,
    ),
    _buildTestOrder(
      id: 'order-17',
      number: 'HF-202404-017',
      status: OrderStatus.paid,
      createdAt: base.subtract(const Duration(days: 2)),
      total: 14200,
    ),
    _buildTestOrder(
      id: 'order-16',
      number: 'HF-202404-016',
      status: OrderStatus.inProduction,
      createdAt: base.subtract(const Duration(days: 3)),
      total: 16800,
    ),
    _buildTestOrder(
      id: 'order-15',
      number: 'HF-202404-015',
      status: OrderStatus.readyToShip,
      createdAt: base.subtract(const Duration(days: 4)),
      total: 15400,
    ),
    _buildTestOrder(
      id: 'order-14',
      number: 'HF-202404-014',
      status: OrderStatus.shipped,
      createdAt: base.subtract(const Duration(days: 5)),
      shippedAt: base.subtract(const Duration(days: 2)),
      total: 11800,
    ),
    _buildTestOrder(
      id: 'order-13',
      number: 'HF-202404-013',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 6)),
      deliveredAt: base.subtract(const Duration(days: 2)),
      shippedAt: base.subtract(const Duration(days: 4)),
      total: 13200,
    ),
    _buildTestOrder(
      id: 'order-12',
      number: 'HF-202404-012',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 8)),
      deliveredAt: base.subtract(const Duration(days: 4)),
      shippedAt: base.subtract(const Duration(days: 6)),
      total: 9800,
    ),
    _buildTestOrder(
      id: 'order-11',
      number: 'HF-202403-011',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 12)),
      deliveredAt: base.subtract(const Duration(days: 7)),
      shippedAt: base.subtract(const Duration(days: 9)),
      total: 12600,
    ),
    _buildTestOrder(
      id: 'order-10',
      number: 'HF-202403-010',
      status: OrderStatus.shipped,
      createdAt: base.subtract(const Duration(days: 15)),
      shippedAt: base.subtract(const Duration(days: 3)),
      total: 8700,
    ),
    _buildTestOrder(
      id: 'order-09',
      number: 'HF-202403-009',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 20)),
      deliveredAt: base.subtract(const Duration(days: 16)),
      shippedAt: base.subtract(const Duration(days: 18)),
      total: 11200,
    ),
    _buildTestOrder(
      id: 'order-08',
      number: 'HF-202402-008',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 28)),
      deliveredAt: base.subtract(const Duration(days: 24)),
      shippedAt: base.subtract(const Duration(days: 26)),
      total: 10100,
    ),
    _buildTestOrder(
      id: 'order-07',
      number: 'HF-202402-007',
      status: OrderStatus.canceled,
      createdAt: base.subtract(const Duration(days: 35)),
      canceledAt: base.subtract(const Duration(days: 34)),
      total: 7600,
    ),
    _buildTestOrder(
      id: 'order-06',
      number: 'HF-202402-006',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 45)),
      deliveredAt: base.subtract(const Duration(days: 40)),
      shippedAt: base.subtract(const Duration(days: 43)),
      total: 14900,
    ),
    _buildTestOrder(
      id: 'order-05',
      number: 'HF-202401-005',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 60)),
      deliveredAt: base.subtract(const Duration(days: 55)),
      shippedAt: base.subtract(const Duration(days: 58)),
      total: 9100,
    ),
    _buildTestOrder(
      id: 'order-04',
      number: 'HF-202312-004',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 90)),
      deliveredAt: base.subtract(const Duration(days: 82)),
      shippedAt: base.subtract(const Duration(days: 85)),
      total: 13400,
    ),
    _buildTestOrder(
      id: 'order-03',
      number: 'HF-202311-003',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 120)),
      deliveredAt: base.subtract(const Duration(days: 112)),
      shippedAt: base.subtract(const Duration(days: 116)),
      total: 8800,
    ),
    _buildTestOrder(
      id: 'order-02',
      number: 'HF-202309-002',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 180)),
      deliveredAt: base.subtract(const Duration(days: 172)),
      shippedAt: base.subtract(const Duration(days: 176)),
      total: 9900,
    ),
    _buildTestOrder(
      id: 'order-01',
      number: 'HF-202306-001',
      status: OrderStatus.delivered,
      createdAt: base.subtract(const Duration(days: 240)),
      deliveredAt: base.subtract(const Duration(days: 232)),
      shippedAt: base.subtract(const Duration(days: 236)),
      total: 8700,
    ),
  ];
  orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return orders;
}

Order _buildTestOrder({
  required String id,
  required String number,
  required OrderStatus status,
  required DateTime createdAt,
  required int total,
  DateTime? deliveredAt,
  DateTime? shippedAt,
  DateTime? canceledAt,
}) {
  final totals = OrderTotals(
    subtotal: total - 1600,
    discount: 0,
    shipping: 800,
    tax: 800,
    fees: 0,
    total: total,
  );
  final lineItem = OrderLineItem(
    id: '$id-line',
    productRef: 'product-$id',
    sku: 'SKU-$id',
    name: 'Order $number',
    quantity: 1,
    unitPrice: total,
    total: total,
  );
  return Order(
    id: id,
    orderNumber: number,
    userRef: 'user/test',
    status: status,
    currency: 'JPY',
    totals: totals,
    lineItems: [lineItem],
    createdAt: createdAt,
    updatedAt: deliveredAt ?? shippedAt ?? createdAt,
    deliveredAt: deliveredAt,
    canceledAt: canceledAt,
    shippingAddress: null,
    billingAddress: null,
    contact: null,
    fulfillment: null,
    production: null,
    notes: null,
    flags: null,
    audit: null,
    placedAt: createdAt,
    paidAt: createdAt,
    shippedAt: shippedAt,
    metadata: null,
  );
}
