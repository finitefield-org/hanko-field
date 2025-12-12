// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/orders/data/dtos/order_dtos.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class OrderRepository {
  static const fallback = Scope<OrderRepository>.required('order.repository');

  Future<Page<Order>> listOrders({OrderStatus? status, String? pageToken});

  Future<Order> getOrder(String orderId);

  Future<Order> cancelOrder(String orderId, {String? reason});

  Future<void> requestInvoice(String orderId);

  Future<Order> reorder(String orderId);

  Future<List<OrderPayment>> listPayments(String orderId);

  Future<List<OrderShipment>> listShipments(String orderId);

  Future<List<ProductionEvent>> listProductionEvents(String orderId);
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final cache = ref.watch(ordersCacheProvider);
  final gates = ref.watch(appExperienceGatesProvider);
  final logger = Logger('OrderRepository');

  return LocalOrderRepository(cache: cache, gates: gates, logger: logger);
});

class LocalOrderRepository implements OrderRepository {
  LocalOrderRepository({
    required LocalCacheStore<JsonMap> cache,
    required AppExperienceGates gates,
    Logger? logger,
  }) : _cache = cache,
       _gates = gates,
       _logger = logger ?? Logger('LocalOrderRepository');

  final LocalCacheStore<JsonMap> _cache;
  final AppExperienceGates _gates;
  final Logger _logger;

  static const int _pageSize = 12;

  bool _seeded = false;
  late List<Order> _orders;
  late final LocalCacheKey _cacheKey = LocalCacheKeys.orders(
    userId: _gates.isAuthenticated ? 'current' : 'guest',
  );

  @override
  Future<Page<Order>> listOrders({
    OrderStatus? status,
    String? pageToken,
  }) async {
    await _ensureSeeded();
    await Future<void>.delayed(const Duration(milliseconds: 160));

    final sorted = List<Order>.of(_orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final filtered = status == null
        ? sorted
        : sorted.where((o) => o.status == status).toList();

    final start = int.tryParse(pageToken ?? '') ?? 0;
    final items = filtered.skip(start).take(_pageSize).toList();
    final next = start + items.length < filtered.length
        ? '${start + items.length}'
        : null;

    return Page(items: items, nextPageToken: next);
  }

  @override
  Future<Order> getOrder(String orderId) async {
    await _ensureSeeded();
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) throw StateError('Unknown order id: $orderId');
    return order;
  }

  @override
  Future<Order> cancelOrder(String orderId, {String? reason}) async {
    await _ensureSeeded();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) throw StateError('Unknown order id: $orderId');

    final current = _orders[index];
    final now = DateTime.now();
    final updated = current.copyWith(
      status: OrderStatus.canceled,
      canceledAt: now,
      cancelReason: reason,
      updatedAt: now,
    );

    _orders[index] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<void> requestInvoice(String orderId) async {
    await _ensureSeeded();
    if (_orders.where((o) => o.id == orderId).isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  @override
  Future<Order> reorder(String orderId) async {
    await _ensureSeeded();
    final original = _orders.where((o) => o.id == orderId).firstOrNull;
    if (original == null) throw StateError('Unknown order id: $orderId');

    final now = DateTime.now();
    final nextNumber = _nextOrderNumber(now);
    final newOrder = original.copyWith(
      id: _newId(),
      orderNumber: nextNumber,
      status: OrderStatus.draft,
      createdAt: now,
      updatedAt: now,
      placedAt: null,
      paidAt: null,
      shippedAt: null,
      deliveredAt: null,
      canceledAt: null,
      cancelReason: null,
    );

    _orders.insert(0, newOrder);
    await _persist();
    return newOrder;
  }

  @override
  Future<List<OrderPayment>> listPayments(String orderId) async {
    final order = await getOrder(orderId);
    return order.payments;
  }

  @override
  Future<List<OrderShipment>> listShipments(String orderId) async {
    final order = await getOrder(orderId);
    return order.shipments;
  }

  @override
  Future<List<ProductionEvent>> listProductionEvents(String orderId) async {
    final order = await getOrder(orderId);
    return order.productionEvents;
  }

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    _orders = _seedOrders();
    await _loadFromCache();
    _seeded = true;
  }

  Future<void> _loadFromCache() async {
    try {
      final hit = await _cache.read(_cacheKey.value);
      final raw = hit?.value['orders'];
      if (raw is! List) return;

      _orders = raw
          .whereType<Map<Object?, Object?>>()
          .map(
            (e) => OrderDto.fromJson(Map<String, Object?>.from(e)).toDomain(),
          )
          .toList();
    } catch (e, stack) {
      _logger.fine('Ignoring invalid orders cache', e, stack);
    }
  }

  Future<void> _persist() {
    final payload = <String, Object?>{
      'orders': _orders.map((o) => OrderDto.fromDomain(o).toJson()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    return _cache.write(_cacheKey.value, payload, tags: _cacheKey.tags);
  }

  List<Order> _seedOrders() {
    final now = DateTime.now();
    final random = Random(42);

    final statuses = <OrderStatus>[
      OrderStatus.pendingPayment,
      OrderStatus.paid,
      OrderStatus.inProduction,
      OrderStatus.readyToShip,
      OrderStatus.shipped,
      OrderStatus.delivered,
      OrderStatus.canceled,
    ];

    return List.generate(48, (index) {
      final createdAt = now.subtract(Duration(days: random.nextInt(240)));
      final status = statuses[random.nextInt(statuses.length)];
      final paidAt =
          (status.index >= OrderStatus.paid.index &&
              status != OrderStatus.canceled)
          ? createdAt.add(Duration(hours: random.nextInt(18) + 1))
          : null;
      final shippedAt =
          (status.index >= OrderStatus.shipped.index &&
              status != OrderStatus.canceled)
          ? createdAt.add(Duration(days: random.nextInt(5) + 2))
          : null;
      final deliveredAt = status == OrderStatus.delivered
          ? (shippedAt ?? createdAt).add(Duration(days: random.nextInt(3) + 1))
          : null;
      final canceledAt = status == OrderStatus.canceled
          ? createdAt.add(Duration(hours: random.nextInt(48) + 1))
          : null;

      final subtotal = 8900 + random.nextInt(8000);
      final shipping = 0;
      final tax = (subtotal * 0.1).round();
      final total = subtotal + shipping + tax;

      return Order(
        id: 'ord_${1000 + index}',
        orderNumber: _seedOrderNumber(index, createdAt),
        userRef: _gates.isAuthenticated ? 'users/current' : 'users/guest',
        status: status,
        currency: 'JPY',
        totals: OrderTotals(
          subtotal: subtotal,
          discount: 0,
          shipping: shipping,
          tax: tax,
          total: total,
        ),
        lineItems: [
          OrderLineItem(
            productRef: 'products/stamp-basic',
            sku: 'STAMP_BASIC',
            quantity: 1,
            unitPrice: subtotal,
            total: subtotal,
            name: _gates.prefersEnglish ? 'Hanko Stamp' : '印鑑',
            designSnapshot: <String, Object?>{
              'kind': 'stamp',
              'label': _gates.prefersEnglish ? 'Round' : '丸印',
            },
          ),
        ],
        shippingAddress: OrderAddress(
          recipient: _gates.prefersEnglish ? 'Taro Yamada' : '山田 太郎',
          line1: _gates.prefersEnglish ? '1-2-3 Ginza' : '銀座1-2-3',
          city: _gates.prefersEnglish ? 'Tokyo' : '中央区',
          postalCode: '100-0000',
          country: 'JP',
          phone: '090-0000-0000',
        ),
        createdAt: createdAt,
        updatedAt: createdAt,
        placedAt: createdAt,
        paidAt: paidAt,
        shippedAt: shippedAt,
        deliveredAt: deliveredAt,
        canceledAt: canceledAt,
        cancelReason: status == OrderStatus.canceled
            ? (_gates.prefersEnglish ? 'Changed my mind' : '都合によりキャンセル')
            : null,
        payments: const [],
        shipments: const [],
        productionEvents: const [],
      );
    });
  }

  String _seedOrderNumber(int index, DateTime createdAt) {
    final year = createdAt.year;
    final serial = (index + 1).toString().padLeft(4, '0');
    return 'HF-$year-$serial';
  }

  String _nextOrderNumber(DateTime now) {
    final year = now.year;
    final serial = (_orders.length + 1).toString().padLeft(4, '0');
    return 'HF-$year-$serial';
  }

  String _newId() {
    final random = Random();
    final nonce = random.nextInt(1000000).toString().padLeft(6, '0');
    return 'ord_${DateTime.now().millisecondsSinceEpoch}_$nonce';
  }
}
