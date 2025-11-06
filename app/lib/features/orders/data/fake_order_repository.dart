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
    _shipmentsByOrder = _buildSeedShipments(base);
    _productionEventsByOrder = _buildSeedProductionEvents(base);
    _invoicesByOrder = _buildSeedInvoices(base);
  }

  final OfflineCacheRepository _cache;
  final Duration _latency;
  final DateTime Function() _now;

  late final List<Order> _orders;
  late final Map<String, Order> _ordersById;
  late final Map<String, List<OrderShipment>> _shipmentsByOrder;
  late final Map<String, List<ProductionEvent>> _productionEventsByOrder;
  late final Map<String, OrderInvoice> _invoicesByOrder;

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
    final normalized = orderId.toLowerCase();
    final shipments = _shipmentsByOrder[normalized];
    if (shipments == null) {
      return const <OrderShipment>[];
    }
    final sorted = List<OrderShipment>.from(shipments)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  @override
  Future<List<ProductionEvent>> fetchProductionEvents(String orderId) async {
    await Future<void>.delayed(_latency);
    final normalized = orderId.toLowerCase();
    final events = _productionEventsByOrder[normalized];
    if (events == null) {
      return const <ProductionEvent>[];
    }
    final sorted = List<ProductionEvent>.from(events)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  @override
  Future<OrderInvoice> fetchInvoice(String orderId) async {
    await Future<void>.delayed(_latency);
    final normalized = orderId.toLowerCase();
    final invoice = _invoicesByOrder[normalized];
    if (invoice != null) {
      return invoice;
    }
    final fallback = OrderInvoice(
      id: normalized,
      orderId: normalized,
      invoiceNumber: 'PENDING-$normalized',
      status: OrderInvoiceStatus.draft,
      taxStatus: OrderInvoiceTaxStatus.inclusive,
      currency: 'JPY',
      amount: 0,
      taxAmount: 0,
      lineItems: const [],
      createdAt: _now(),
      updatedAt: _now(),
      downloadUrl: null,
      metadata: const {'note': 'Invoice generation pending'},
    );
    _invoicesByOrder[normalized] = fallback;
    return fallback;
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

  Map<String, OrderInvoice> _buildSeedInvoices(DateTime base) {
    final issuedAt = base.subtract(const Duration(days: 2, hours: 1));
    final sentAt = base.subtract(const Duration(days: 2));
    final pendingCreated = base.subtract(const Duration(hours: 6));
    return {
      'hf-202404-018': OrderInvoice(
        id: 'invoice-hf-202404-018',
        orderId: 'hf-202404-018',
        invoiceNumber: 'INV-2024-018',
        status: OrderInvoiceStatus.draft,
        taxStatus: OrderInvoiceTaxStatus.inclusive,
        currency: 'JPY',
        amount: 12800,
        taxAmount: 1164,
        lineItems: const [
          OrderInvoiceLineItem(description: '手彫り印鑑（檜） x1', amount: 11800),
          OrderInvoiceLineItem(description: '送料', amount: 1000),
        ],
        createdAt: pendingCreated,
        updatedAt: pendingCreated,
        dueDate: base.add(const Duration(days: 7)),
        pdfAssetRef: null,
        downloadUrl: null,
        metadata: const {'taxLabel': '消費税10%対象', 'emailSent': false},
      ),
      'hf-202404-017': OrderInvoice(
        id: 'invoice-hf-202404-017',
        orderId: 'hf-202404-017',
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
        createdAt: issuedAt,
        updatedAt: issuedAt,
        dueDate: issuedAt.add(const Duration(days: 14)),
        sentAt: sentAt,
        pdfAssetRef: '/assets/invoices/INV-2024-017',
        downloadUrl:
            'https://storage.googleapis.com/hanko-dev-assets/invoices/INV-2024-017.pdf',
        metadata: const {'taxLabel': '消費税10%対象', 'emailSent': true},
      ),
      'hf-202404-016': OrderInvoice(
        id: 'invoice-hf-202404-016',
        orderId: 'hf-202404-016',
        invoiceNumber: 'INV-2024-016',
        status: OrderInvoiceStatus.sent,
        taxStatus: OrderInvoiceTaxStatus.exclusive,
        currency: 'JPY',
        amount: 16800,
        taxAmount: 0,
        lineItems: const [
          OrderInvoiceLineItem(description: '法人代表印（丸印） x1', amount: 15800),
          OrderInvoiceLineItem(description: '海外配送手数料', amount: 1000),
        ],
        createdAt: base.subtract(const Duration(days: 3, hours: 5)),
        updatedAt: base.subtract(const Duration(days: 3, hours: 5)),
        dueDate: base.add(const Duration(days: 10)),
        sentAt: base.subtract(const Duration(days: 3, hours: 4)),
        pdfAssetRef: '/assets/invoices/INV-2024-016',
        downloadUrl:
            'https://storage.googleapis.com/hanko-dev-assets/invoices/INV-2024-016.pdf',
        metadata: const {'taxLabel': '輸出免税', 'emailSent': true},
      ),
    };
  }

  Map<String, List<OrderShipment>> _buildSeedShipments(DateTime base) {
    final now = base;

    final shipments = <String, List<OrderShipment>>{
      'hf-202404-015': [
        _shipment(
          id: 'hf-202404-015-shp1',
          carrier: OrderShipmentCarrier.yamato,
          service: '宅急便 (クール便)',
          trackingNumber: 'YMT123456789JP',
          status: OrderShipmentStatus.labelCreated,
          createdAt: now.subtract(const Duration(days: 4, hours: 12)),
          eta: now.add(const Duration(days: 2)),
          events: [
            _shipmentEvent(
              code: OrderShipmentEventCode.labelCreated,
              timestamp: now.subtract(const Duration(days: 4, hours: 12)),
              location: '渋谷区 道玄坂フルフィルメントセンター',
              note: '送り状を発行しました。集荷を待っています。',
            ),
          ],
        ),
      ],
      'hf-202404-014': [
        _shipment(
          id: 'hf-202404-014-shp1',
          carrier: OrderShipmentCarrier.yamato,
          service: '宅急便 (時間指定)',
          trackingNumber: 'YMT987654321JP',
          status: OrderShipmentStatus.outForDelivery,
          createdAt: now.subtract(const Duration(days: 3, hours: 18)),
          eta: now.add(const Duration(hours: 6)),
          events: [
            _shipmentEvent(
              code: OrderShipmentEventCode.labelCreated,
              timestamp: now.subtract(const Duration(days: 3, hours: 18)),
              location: '渋谷区 道玄坂フルフィルメントセンター',
              note: '荷物情報を登録しました。',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.pickedUp,
              timestamp: now.subtract(const Duration(days: 2, hours: 20)),
              location: '渋谷区',
              note: 'ドライバーが荷物を集荷しました。',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.inTransit,
              timestamp: now.subtract(const Duration(days: 2, hours: 6)),
              location: '東京ゲートウェイベース',
              note: '仕分け中です。',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.arrivedHub,
              timestamp: now.subtract(const Duration(days: 1, hours: 5)),
              location: '横浜南ベース',
              note: '配達営業所に到着しました。',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.outForDelivery,
              timestamp: now.subtract(const Duration(hours: 3, minutes: 20)),
              location: '横浜市 西区',
              note: '配達員が持ち出しました。',
            ),
          ],
        ),
      ],
      'hf-202404-013': [
        _shipment(
          id: 'hf-202404-013-shp1',
          carrier: OrderShipmentCarrier.dhl,
          service: 'Express Worldwide',
          trackingNumber: 'DHL0011223344',
          status: OrderShipmentStatus.delivered,
          createdAt: now.subtract(const Duration(days: 9, hours: 20)),
          eta: now.subtract(const Duration(days: 2, hours: 12)),
          events: [
            _shipmentEvent(
              code: OrderShipmentEventCode.labelCreated,
              timestamp: now.subtract(const Duration(days: 9, hours: 20)),
              location: 'Tokyo Export Facility',
              note: 'Shipment information received.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.pickedUp,
              timestamp: now.subtract(const Duration(days: 9, hours: 6)),
              location: 'Tokyo',
              note: 'Picked up by DHL courier.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.inTransit,
              timestamp: now.subtract(const Duration(days: 8, hours: 18)),
              location: 'Hong Kong Hub',
              note: 'Departed facility.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.customsClearance,
              timestamp: now.subtract(const Duration(days: 7, hours: 22)),
              location: 'Los Angeles, CA',
              note: 'Cleared customs.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.arrivedHub,
              timestamp: now.subtract(const Duration(days: 6, hours: 12)),
              location: 'San Francisco, CA',
              note: 'Arrived at destination facility.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.outForDelivery,
              timestamp: now.subtract(const Duration(days: 2, hours: 19)),
              location: 'San Jose, CA',
              note: 'With courier for delivery.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.delivered,
              timestamp: now.subtract(const Duration(days: 2, hours: 12)),
              location: 'San Jose, CA',
              note: 'Delivered. Signed by K. Suzuki.',
            ),
          ],
        ),
      ],
      'hf-202403-010': [
        _shipment(
          id: 'hf-202403-010-shp1',
          carrier: OrderShipmentCarrier.sagawa,
          service: '飛脚宅配便',
          trackingNumber: 'SGW5566778899',
          status: OrderShipmentStatus.inTransit,
          createdAt: now.subtract(const Duration(days: 6, hours: 8)),
          eta: now.add(const Duration(days: 1, hours: 6)),
          events: [
            _shipmentEvent(
              code: OrderShipmentEventCode.labelCreated,
              timestamp: now.subtract(const Duration(days: 6, hours: 8)),
              location: '京都市 下京区',
              note: '送り状を発行しました。',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.pickedUp,
              timestamp: now.subtract(const Duration(days: 5, hours: 20)),
              location: '京都市 下京区',
              note: '荷物を集荷しました。',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.inTransit,
              timestamp: now.subtract(const Duration(days: 3, hours: 12)),
              location: '名古屋中継センター',
              note: '輸送中です。',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.arrivedHub,
              timestamp: now.subtract(const Duration(days: 2, hours: 6)),
              location: '大田区 羽田センター',
              note: '配達店に到着しました。',
            ),
          ],
        ),
      ],
      'hf-202403-009': [
        _shipment(
          id: 'hf-202403-009-shp1',
          carrier: OrderShipmentCarrier.jppost,
          service: 'ゆうパック',
          trackingNumber: 'JP9933445566',
          status: OrderShipmentStatus.delivered,
          createdAt: now.subtract(const Duration(days: 35, hours: 5)),
          eta: now.subtract(const Duration(days: 25, hours: 2)),
          events: [
            _shipmentEvent(
              code: OrderShipmentEventCode.labelCreated,
              timestamp: now.subtract(const Duration(days: 35, hours: 5)),
              location: '新宿区 高田馬場支店',
              note: '引受',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.inTransit,
              timestamp: now.subtract(const Duration(days: 33, hours: 8)),
              location: '新東京郵便局',
              note: '通過',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.arrivedHub,
              timestamp: now.subtract(const Duration(days: 30, hours: 6)),
              location: '大阪北郵便局',
              note: '到着',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.outForDelivery,
              timestamp: now.subtract(const Duration(days: 25, hours: 8)),
              location: '大阪市 北区',
              note: 'お届け中',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.delivered,
              timestamp: now.subtract(const Duration(days: 25, hours: 2)),
              location: '大阪市 北区',
              note: 'お届け済み',
            ),
          ],
        ),
      ],
      'hf-202402-008': [
        _shipment(
          id: 'hf-202402-008-shp1',
          carrier: OrderShipmentCarrier.fedex,
          service: 'International Priority',
          trackingNumber: 'FDX7788990011',
          status: OrderShipmentStatus.delivered,
          createdAt: now.subtract(const Duration(days: 48)),
          eta: now.subtract(const Duration(days: 36)),
          events: [
            _shipmentEvent(
              code: OrderShipmentEventCode.labelCreated,
              timestamp: now.subtract(const Duration(days: 48)),
              location: 'Osaka Export Center',
              note: 'Shipment information sent to FedEx.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.pickedUp,
              timestamp: now.subtract(const Duration(days: 47, hours: 18)),
              location: 'Osaka',
              note: 'Package picked up.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.inTransit,
              timestamp: now.subtract(const Duration(days: 46, hours: 12)),
              location: 'Incheon Hub',
              note: 'Departed FedEx location.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.customsClearance,
              timestamp: now.subtract(const Duration(days: 44, hours: 6)),
              location: 'Seattle, WA',
              note: 'Cleared customs. Duties paid.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.arrivedHub,
              timestamp: now.subtract(const Duration(days: 40, hours: 18)),
              location: 'Portland, OR',
              note: 'At local FedEx facility.',
            ),
            _shipmentEvent(
              code: OrderShipmentEventCode.delivered,
              timestamp: now.subtract(const Duration(days: 36)),
              location: 'Portland, OR',
              note: 'Delivered at front door.',
            ),
          ],
        ),
      ],
    };

    return {
      for (final entry in shipments.entries)
        entry.key.toLowerCase(): List<OrderShipment>.unmodifiable(entry.value),
    };
  }

  OrderShipment _shipment({
    required String id,
    required OrderShipmentCarrier carrier,
    required OrderShipmentStatus status,
    required DateTime createdAt,
    required List<OrderShipmentEvent> events,
    String? service,
    String? trackingNumber,
    DateTime? eta,
    String? labelUrl,
    List<String> documents = const <String>[],
    DateTime? updatedAt,
  }) {
    final sortedEvents = List<OrderShipmentEvent>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final fallbackUpdatedAt = sortedEvents.isNotEmpty
        ? sortedEvents.last.timestamp
        : createdAt;
    return OrderShipment(
      id: id,
      carrier: carrier,
      status: status,
      createdAt: createdAt,
      service: service,
      trackingNumber: trackingNumber,
      eta: eta,
      labelUrl: labelUrl,
      documents: List<String>.unmodifiable(documents),
      events: List<OrderShipmentEvent>.unmodifiable(sortedEvents),
      updatedAt: updatedAt ?? fallbackUpdatedAt,
    );
  }

  OrderShipmentEvent _shipmentEvent({
    required OrderShipmentEventCode code,
    required DateTime timestamp,
    String? location,
    String? note,
  }) {
    return OrderShipmentEvent(
      timestamp: timestamp,
      code: code,
      location: location,
      note: note,
    );
  }

  Map<String, List<ProductionEvent>> _buildSeedProductionEvents(DateTime base) {
    final now = base;
    final seeds = <String, List<ProductionEvent>>{
      'hf-202404-018': _buildProductionEvents(
        stages: [
          _event(
            idSuffix: 'queued',
            type: ProductionEventType.queued,
            createdAt: now.subtract(const Duration(hours: 6)),
            note: 'Order entered production queue.',
          ),
        ],
      ),
      'hf-202404-017': _buildProductionEvents(
        stages: [
          _event(
            idSuffix: 'queued',
            type: ProductionEventType.queued,
            createdAt: now.subtract(const Duration(days: 2, hours: 4)),
            note: 'Awaiting artisan assignment.',
          ),
          _event(
            idSuffix: 'engraving',
            type: ProductionEventType.engraving,
            createdAt: now.subtract(const Duration(days: 2, hours: 2)),
            duration: const Duration(hours: 3, minutes: 20),
            station: 'Engraving-2',
            operatorRef: 'artisan-amy',
            note: 'Custom logo alignment verified.',
          ),
        ],
      ),
      'hf-202404-016': _buildProductionEvents(
        stages: [
          _event(
            idSuffix: 'queued',
            type: ProductionEventType.queued,
            createdAt: now.subtract(const Duration(days: 4, hours: 2)),
            note: 'Queued for production.',
          ),
          _event(
            idSuffix: 'engraving',
            type: ProductionEventType.engraving,
            createdAt: now.subtract(const Duration(days: 3, hours: 19)),
            duration: const Duration(hours: 2, minutes: 45),
            station: 'Engraving-1',
            operatorRef: 'artisan-hori',
            note: 'Kanji crest engraving in progress.',
          ),
          _event(
            idSuffix: 'polishing',
            type: ProductionEventType.polishing,
            createdAt: now.subtract(const Duration(days: 3, hours: 14)),
            duration: const Duration(hours: 1, minutes: 30),
            station: 'Polish-3',
            operatorRef: 'artisan-kato',
            note: 'Fine polishing for satin finish.',
          ),
          _event(
            idSuffix: 'qc',
            type: ProductionEventType.qc,
            createdAt: now.subtract(const Duration(days: 3, hours: 6)),
            duration: const Duration(hours: 1),
            station: 'QC-Line',
            operatorRef: 'qc-sato',
            note: 'Detected micro chip near base; sending for rework.',
            qcResult: 'needs_rework',
            qcDefects: const ['Surface chip near base'],
          ),
          _event(
            idSuffix: 'rework',
            type: ProductionEventType.rework,
            createdAt: now.subtract(const Duration(days: 2, hours: 18)),
            duration: const Duration(hours: 5, minutes: 30),
            station: 'Rework-1',
            operatorRef: 'artisan-kato',
            note: 'Chip patched; waiting for QC confirmation.',
          ),
          _event(
            idSuffix: 'on-hold',
            type: ProductionEventType.onHold,
            createdAt: now.subtract(const Duration(hours: 12)),
            note: 'Holding for client approval on revised engraving.',
          ),
        ],
      ),
      'hf-202404-015': _buildProductionEvents(
        stages: [
          _event(
            idSuffix: 'queued',
            type: ProductionEventType.queued,
            createdAt: now.subtract(const Duration(days: 5, hours: 6)),
          ),
          _event(
            idSuffix: 'engraving',
            type: ProductionEventType.engraving,
            createdAt: now.subtract(const Duration(days: 5, hours: 2)),
            station: 'Engraving-3',
            operatorRef: 'artisan-suzu',
            duration: const Duration(hours: 3),
          ),
          _event(
            idSuffix: 'polishing',
            type: ProductionEventType.polishing,
            createdAt: now.subtract(const Duration(days: 4, hours: 20)),
            duration: const Duration(hours: 1, minutes: 10),
          ),
          _event(
            idSuffix: 'qc',
            type: ProductionEventType.qc,
            createdAt: now.subtract(const Duration(days: 4, hours: 16)),
            duration: const Duration(hours: 1),
            qcResult: 'pass',
          ),
          _event(
            idSuffix: 'packed',
            type: ProductionEventType.packed,
            createdAt: now.subtract(const Duration(days: 4, hours: 12)),
            note: 'Packaged with silk wrap and certificate.',
          ),
        ],
      ),
      'hf-202404-014': _buildProductionEvents(
        stages: [
          _event(
            idSuffix: 'queued',
            type: ProductionEventType.queued,
            createdAt: now.subtract(const Duration(days: 6, hours: 6)),
          ),
          _event(
            idSuffix: 'engraving',
            type: ProductionEventType.engraving,
            createdAt: now.subtract(const Duration(days: 6, hours: 3)),
            station: 'Engraving-3',
            operatorRef: 'artisan-suzu',
            duration: const Duration(hours: 2, minutes: 20),
          ),
          _event(
            idSuffix: 'polishing',
            type: ProductionEventType.polishing,
            createdAt: now.subtract(const Duration(days: 5, hours: 20)),
            duration: const Duration(hours: 1, minutes: 15),
          ),
          _event(
            idSuffix: 'qc',
            type: ProductionEventType.qc,
            createdAt: now.subtract(const Duration(days: 5, hours: 16)),
            duration: const Duration(hours: 1),
            qcResult: 'pass',
          ),
          _event(
            idSuffix: 'packed',
            type: ProductionEventType.packed,
            createdAt: now.subtract(const Duration(days: 5, hours: 12)),
          ),
        ],
      ),
    };
    return {
      for (final entry in seeds.entries) entry.key.toLowerCase(): entry.value,
    };
  }

  List<ProductionEvent> _buildProductionEvents({
    required List<ProductionEvent> stages,
  }) {
    return List<ProductionEvent>.unmodifiable(stages);
  }

  ProductionEvent _event({
    required String idSuffix,
    required ProductionEventType type,
    required DateTime createdAt,
    Duration? duration,
    String? station,
    String? operatorRef,
    String? note,
    String? qcResult,
    List<String>? qcDefects,
  }) {
    return ProductionEvent(
      id: '$idSuffix-${createdAt.millisecondsSinceEpoch}',
      type: type,
      createdAt: createdAt,
      durationSec: duration?.inSeconds,
      station: station,
      operatorRef: operatorRef,
      note: note,
      qcResult: qcResult,
      qcDefects: qcDefects ?? const <String>[],
    );
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
    const shippingAddress = OrderAddress(
      recipient: '佐藤 太郎',
      line1: '東京都渋谷区道玄坂 1-12-1',
      line2: 'マークシティ ウエスト 22F',
      city: '渋谷区',
      state: '東京都',
      postalCode: '150-0043',
      country: '日本',
      phone: '03-4520-1234',
    );
    const billingAddress = OrderAddress(
      recipient: '佐藤 太郎',
      line1: '東京都港区南青山 2-11-17',
      city: '港区',
      state: '東京都',
      postalCode: '107-0062',
      country: '日本',
      phone: '03-4520-5678',
    );
    const contact = OrderContact(
      email: 'taro.sato@example.com',
      phone: '090-1234-5678',
    );
    return Order(
      id: id,
      orderNumber: number,
      userRef: 'user/demo',
      status: status,
      currency: 'JPY',
      totals: totals,
      lineItems: <OrderLineItem>[lineItem],
      shippingAddress: shippingAddress,
      billingAddress: billingAddress,
      contact: contact,
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
