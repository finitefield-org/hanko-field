import 'dart:async';

import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/domain/repositories/order_repository.dart';
import 'package:app/core/storage/cache_policy.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/orders/domain/order_list_filter.dart';

class FakeOrderRepository extends OrderRepository {
  FakeOrderRepository({
    required OfflineCacheRepository cache,
    Duration latency = const Duration(milliseconds: 260),
    DateTime Function()? now,
  }) : _cache = cache,
       _latency = latency,
       _now = now ?? DateTime.now {
    final base = _now();
    _orders = _buildSeedOrders(base);
    _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _ordersById = {for (final order in _orders) order.id: order};
  }

  final OfflineCacheRepository _cache;
  final Duration _latency;
  final DateTime Function() _now;

  late final List<Order> _orders;
  late final Map<String, Order> _ordersById;

  static const _defaultPageSize = 10;

  @override
  Future<List<Order>> fetchOrders({
    int? pageSize,
    String? pageToken,
    Map<String, dynamic>? filters,
  }) async {
    await Future<void>.delayed(_latency);
    final limit = pageSize ?? _defaultPageSize;
    final filter = OrderListFilter.fromMap(filters);
    final cacheKey = filter.cacheKey;

    final cacheResult = await _cache.readOrders(key: cacheKey);
    List<Order> source;
    if (cacheResult.hasValue && cacheResult.value != null) {
      source = cacheResult.value!.items.map(mapOrder).toList();
      if (cacheResult.state == CacheState.stale) {
        source = await _refreshCache(filter, cacheKey);
      }
    } else {
      source = await _refreshCache(filter, cacheKey);
    }
    source.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final startIndex = _startIndexForCursor(source, pageToken);
    return source.skip(startIndex).take(limit).toList();
  }

  Future<List<Order>> _refreshCache(
    OrderListFilter filter,
    String cacheKey,
  ) async {
    final now = _now();
    final filtered = <Order>[
      for (final order in _orders)
        if (filter.matches(order, now)) order,
    ];
    await _cache.writeOrders(
      CachedOrderList(
        items: filtered.map(mapOrderToDto).toList(),
        appliedFilters: filter.toMap(),
      ),
      key: cacheKey,
    );
    return filtered;
  }

  int _startIndexForCursor(List<Order> source, String? cursor) {
    if (cursor == null) {
      return 0;
    }
    final index = source.indexWhere((order) => order.id == cursor);
    if (index == -1) {
      return 0;
    }
    return index + 1;
  }

  @override
  Future<Order> fetchOrder(String orderId) async {
    await Future<void>.delayed(_latency);
    final normalized = orderId.toLowerCase();
    final existing = _ordersById[normalized];
    if (existing == null) {
      throw StateError('Order $orderId not found');
    }
    return existing;
  }

  @override
  Future<List<OrderPayment>> fetchPayments(String orderId) async {
    await Future<void>.delayed(_latency);
    return const <OrderPayment>[];
  }

  @override
  Future<List<OrderShipment>> fetchShipments(String orderId) async {
    await Future<void>.delayed(_latency);
    return const <OrderShipment>[];
  }

  @override
  Future<List<ProductionEvent>> fetchProductionEvents(String orderId) async {
    await Future<void>.delayed(_latency);
    return const <ProductionEvent>[];
  }

  @override
  Future<Order> cancelOrder(String orderId, {String? reason}) async {
    await Future<void>.delayed(_latency);
    final existing = await fetchOrder(orderId);
    final canceled = existing.copyWith(
      status: OrderStatus.canceled,
      canceledAt: _now(),
      cancelReason: reason ?? 'User requested cancellation',
    );
    _ordersById[existing.id] = canceled;
    return canceled;
  }

  @override
  Future<Order> requestInvoice(String orderId) async {
    return fetchOrder(orderId);
  }

  @override
  Future<Order> reorder(String orderId) async {
    return fetchOrder(orderId);
  }

  List<Order> _buildSeedOrders(DateTime base) {
    final orders = <Order>[
      _buildOrder(
        id: 'hf-202404-018',
        number: 'HF-202404-018',
        status: OrderStatus.pendingPayment,
        createdAt: base.subtract(const Duration(days: 1, hours: 3)),
        placedAt: base.subtract(const Duration(days: 1, hours: 5)),
        merchandiseTotal: 12800,
        productName: '手彫り印鑑（檜）',
        designEmoji: '🌲',
        color: 0xFF9CCC65,
      ),
      _buildOrder(
        id: 'hf-202404-017',
        number: 'HF-202404-017',
        status: OrderStatus.paid,
        createdAt: base.subtract(const Duration(days: 2, hours: 6)),
        placedAt: base.subtract(const Duration(days: 2, hours: 8)),
        paidAt: base.subtract(const Duration(days: 2, hours: 2)),
        merchandiseTotal: 14200,
        productName: '黒水牛 薩摩本柘セット',
        designEmoji: '🐃',
        color: 0xFF9575CD,
      ),
      _buildOrder(
        id: 'hf-202404-016',
        number: 'HF-202404-016',
        status: OrderStatus.inProduction,
        createdAt: base.subtract(const Duration(days: 4)),
        placedAt: base.subtract(const Duration(days: 4, hours: 3)),
        paidAt: base.subtract(const Duration(days: 3, hours: 20)),
        merchandiseTotal: 16800,
        productName: '法人代表印（丸印）',
        designEmoji: '🏢',
        color: 0xFF4DB6AC,
      ),
      _buildOrder(
        id: 'hf-202404-015',
        number: 'HF-202404-015',
        status: OrderStatus.readyToShip,
        createdAt: base.subtract(const Duration(days: 5, hours: 3)),
        placedAt: base.subtract(const Duration(days: 5, hours: 8)),
        paidAt: base.subtract(const Duration(days: 4, hours: 22)),
        merchandiseTotal: 15400,
        productName: '銀行印＋認印セット',
        designEmoji: '🏦',
        color: 0xFFFFB74D,
      ),
      _buildOrder(
        id: 'hf-202404-014',
        number: 'HF-202404-014',
        status: OrderStatus.shipped,
        createdAt: base.subtract(const Duration(days: 6)),
        placedAt: base.subtract(const Duration(days: 6, hours: 6)),
        paidAt: base.subtract(const Duration(days: 6, hours: 2)),
        shippedAt: base.subtract(const Duration(days: 1, hours: 20)),
        merchandiseTotal: 11800,
        productName: '角印（会社用）',
        designEmoji: '📦',
        color: 0xFFFF8A80,
      ),
      _buildOrder(
        id: 'hf-202404-013',
        number: 'HF-202404-013',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 8, hours: 4)),
        placedAt: base.subtract(const Duration(days: 9)),
        paidAt: base.subtract(const Duration(days: 8, hours: 1)),
        shippedAt: base.subtract(const Duration(days: 5, hours: 20)),
        deliveredAt: base.subtract(const Duration(days: 2, hours: 12)),
        merchandiseTotal: 13200,
        productName: 'チタン印鑑セット',
        designEmoji: '⚙️',
        color: 0xFF90CAF9,
      ),
      _buildOrder(
        id: 'hf-202404-012',
        number: 'HF-202404-012',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 12)),
        placedAt: base.subtract(const Duration(days: 12, hours: 7)),
        paidAt: base.subtract(const Duration(days: 11, hours: 23)),
        shippedAt: base.subtract(const Duration(days: 7, hours: 8)),
        deliveredAt: base.subtract(const Duration(days: 3, hours: 6)),
        merchandiseTotal: 9800,
        productName: '開運 印鑑（彩色）',
        designEmoji: '🎏',
        color: 0xFFF06292,
      ),
      _buildOrder(
        id: 'hf-202403-011',
        number: 'HF-202403-011',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 18)),
        placedAt: base.subtract(const Duration(days: 18, hours: 4)),
        paidAt: base.subtract(const Duration(days: 17, hours: 18)),
        shippedAt: base.subtract(const Duration(days: 14)),
        deliveredAt: base.subtract(const Duration(days: 10)),
        merchandiseTotal: 12600,
        productName: '彩樺 認印',
        designEmoji: '🍁',
        color: 0xFFA1887F,
      ),
      _buildOrder(
        id: 'hf-202403-010',
        number: 'HF-202403-010',
        status: OrderStatus.shipped,
        createdAt: base.subtract(const Duration(days: 24)),
        placedAt: base.subtract(const Duration(days: 24, hours: 5)),
        paidAt: base.subtract(const Duration(days: 24, hours: 1)),
        shippedAt: base.subtract(const Duration(days: 2, hours: 6)),
        merchandiseTotal: 8700,
        productName: '銀行印（柘）',
        designEmoji: '🏮',
        color: 0xFF81D4FA,
      ),
      _buildOrder(
        id: 'hf-202403-009',
        number: 'HF-202403-009',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 32)),
        placedAt: base.subtract(const Duration(days: 32, hours: 3)),
        paidAt: base.subtract(const Duration(days: 31, hours: 19)),
        shippedAt: base.subtract(const Duration(days: 28, hours: 5)),
        deliveredAt: base.subtract(const Duration(days: 25, hours: 2)),
        merchandiseTotal: 11200,
        productName: '彩華 印鑑ケース付',
        designEmoji: '🧧',
        color: 0xFFFFCC80,
      ),
      _buildOrder(
        id: 'hf-202402-008',
        number: 'HF-202402-008',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 45)),
        placedAt: base.subtract(const Duration(days: 45, hours: 6)),
        paidAt: base.subtract(const Duration(days: 44, hours: 19)),
        shippedAt: base.subtract(const Duration(days: 40)),
        deliveredAt: base.subtract(const Duration(days: 36)),
        merchandiseTotal: 10100,
        productName: '法人 角印セット',
        designEmoji: '🧱',
        color: 0xFF64B5F6,
      ),
      _buildOrder(
        id: 'hf-202402-007',
        number: 'HF-202402-007',
        status: OrderStatus.canceled,
        createdAt: base.subtract(const Duration(days: 52)),
        placedAt: base.subtract(const Duration(days: 52, hours: 2)),
        canceledAt: base.subtract(const Duration(days: 51, hours: 18)),
        merchandiseTotal: 7600,
        productName: '法人ゴム印（3行）',
        designEmoji: '⛔️',
        color: 0xFFB0BEC5,
        cancelReason: '支払方法の確認が取れませんでした',
      ),
      _buildOrder(
        id: 'hf-202402-006',
        number: 'HF-202402-006',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 67)),
        placedAt: base.subtract(const Duration(days: 67, hours: 6)),
        paidAt: base.subtract(const Duration(days: 66, hours: 23)),
        shippedAt: base.subtract(const Duration(days: 62)),
        deliveredAt: base.subtract(const Duration(days: 57)),
        merchandiseTotal: 14900,
        productName: '銀行印・認印セット（黒彩樺）',
        designEmoji: '🖋️',
        color: 0xFF7986CB,
      ),
      _buildOrder(
        id: 'hf-202401-005',
        number: 'HF-202401-005',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 84)),
        placedAt: base.subtract(const Duration(days: 84, hours: 8)),
        paidAt: base.subtract(const Duration(days: 83, hours: 16)),
        shippedAt: base.subtract(const Duration(days: 78)),
        deliveredAt: base.subtract(const Duration(days: 73)),
        merchandiseTotal: 9100,
        productName: '法人実印（牛角）',
        designEmoji: '🐮',
        color: 0xFF4DD0E1,
      ),
      _buildOrder(
        id: 'hf-202312-004',
        number: 'HF-202312-004',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 110)),
        placedAt: base.subtract(const Duration(days: 110, hours: 5)),
        paidAt: base.subtract(const Duration(days: 109, hours: 20)),
        shippedAt: base.subtract(const Duration(days: 104)),
        deliveredAt: base.subtract(const Duration(days: 99)),
        merchandiseTotal: 13400,
        productName: '年賀状用住所印',
        designEmoji: '🗞️',
        color: 0xFFBA68C8,
      ),
      _buildOrder(
        id: 'hf-202311-003',
        number: 'HF-202311-003',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 138)),
        placedAt: base.subtract(const Duration(days: 138, hours: 3)),
        paidAt: base.subtract(const Duration(days: 137, hours: 18)),
        shippedAt: base.subtract(const Duration(days: 132)),
        deliveredAt: base.subtract(const Duration(days: 127)),
        merchandiseTotal: 8800,
        productName: 'こども銀行印セット',
        designEmoji: '🧸',
        color: 0xFFFF8A65,
      ),
      _buildOrder(
        id: 'hf-202309-002',
        number: 'HF-202309-002',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 190)),
        placedAt: base.subtract(const Duration(days: 190, hours: 6)),
        paidAt: base.subtract(const Duration(days: 189, hours: 22)),
        shippedAt: base.subtract(const Duration(days: 184)),
        deliveredAt: base.subtract(const Duration(days: 179)),
        merchandiseTotal: 9900,
        productName: '越前和紙 印鑑セット',
        designEmoji: '🗻',
        color: 0xFFA5D6A7,
      ),
      _buildOrder(
        id: 'hf-202306-001',
        number: 'HF-202306-001',
        status: OrderStatus.delivered,
        createdAt: base.subtract(const Duration(days: 300)),
        placedAt: base.subtract(const Duration(days: 300, hours: 4)),
        paidAt: base.subtract(const Duration(days: 299, hours: 18)),
        shippedAt: base.subtract(const Duration(days: 294)),
        deliveredAt: base.subtract(const Duration(days: 289)),
        merchandiseTotal: 8700,
        productName: '朱肉セット（携帯用）',
        designEmoji: '🟥',
        color: 0xFFFFB74D,
      ),
    ];
    return orders;
  }

  Order _buildOrder({
    required String id,
    required String number,
    required OrderStatus status,
    required DateTime createdAt,
    required int merchandiseTotal,
    required String productName,
    required String designEmoji,
    required int color,
    DateTime? placedAt,
    DateTime? paidAt,
    DateTime? shippedAt,
    DateTime? deliveredAt,
    DateTime? canceledAt,
    String? cancelReason,
  }) {
    final totals = _buildTotals(merchandiseTotal);
    final lineItem = OrderLineItem(
      id: '$id-line',
      productRef: 'product-$id',
      designRef: 'design-$id',
      designSnapshot: <String, dynamic>{
        'emoji': designEmoji,
        'background': color,
        'title': productName,
      },
      sku: 'SKU-${number.substring(number.length - 3)}',
      name: productName,
      quantity: 1,
      unitPrice: merchandiseTotal,
      total: merchandiseTotal,
      options: const <String, dynamic>{'script': '楷書体', 'layout': '縦書き'},
    );
    return Order(
      id: id,
      orderNumber: number,
      userRef: 'user/demo',
      status: status,
      currency: 'JPY',
      totals: totals,
      lineItems: <OrderLineItem>[lineItem],
      shippingAddress: null,
      billingAddress: null,
      contact: null,
      fulfillment: null,
      production: null,
      notes: null,
      flags: null,
      audit: null,
      createdAt: createdAt,
      updatedAt: deliveredAt ?? shippedAt ?? paidAt ?? createdAt,
      placedAt: placedAt,
      paidAt: paidAt,
      shippedAt: shippedAt,
      deliveredAt: deliveredAt,
      canceledAt: canceledAt,
      cancelReason: cancelReason,
      metadata: <String, dynamic>{'tileColor': color, 'emoji': designEmoji},
    );
  }

  OrderTotals _buildTotals(int merchandiseTotal) {
    const shipping = 800;
    final tax = (merchandiseTotal * 0.1).round();
    final total = merchandiseTotal + shipping + tax;
    return OrderTotals(
      subtotal: merchandiseTotal,
      discount: 0,
      shipping: shipping,
      tax: tax,
      fees: 0,
      total: total,
    );
  }
}
