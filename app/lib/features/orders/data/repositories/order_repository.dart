// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/orders/data/dtos/order_dtos.dart';
import 'package:app/features/orders/data/models/order_invoice_models.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

abstract class OrderRepository {
  static const fallback = Scope<OrderRepository>.required('order.repository');

  Future<Page<Order>> listOrders({OrderStatus? status, String? pageToken});

  Future<Order> getOrder(String orderId);

  Future<Order> cancelOrder(String orderId, {String? reason});

  Future<void> requestInvoice(String orderId);

  Future<OrderInvoice> getInvoice(String orderId);

  Future<List<int>> downloadInvoicePdf(String orderId);

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
  static const Duration _invoiceFulfillmentDelay = Duration(seconds: 2);

  bool _seeded = false;
  late List<Order> _orders;
  late final LocalCacheKey _cacheKey = LocalCacheKeys.orders(
    userId: _gates.isAuthenticated ? 'current' : 'guest',
  );

  LocalCacheKey _invoiceKey(String orderId) => LocalCacheKeys.orderInvoice(
    orderId: orderId,
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
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;

    final now = DateTime.now();
    final issuedAt = order.paidAt != null
        ? now.add(_invoiceFulfillmentDelay)
        : null;
    final invoiceNumber = _invoiceNumberFor(order: order, issuedAt: now);

    await _cache.write(
      _invoiceKey(orderId).value,
      <String, Object?>{
        'orderId': orderId,
        'invoiceNumber': invoiceNumber,
        'requestedAt': now.toIso8601String(),
        'issuedAt': issuedAt?.toIso8601String(),
      },
      policy: CachePolicies.orders,
      tags: _invoiceKey(orderId).tags,
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  @override
  Future<OrderInvoice> getInvoice(String orderId) async {
    await _ensureSeeded();
    final order = await getOrder(orderId);
    final hit = await _cache.read(_invoiceKey(orderId).value);

    final issuedAtRaw = hit?.value['issuedAt'];
    final issuedAt = issuedAtRaw is String
        ? DateTime.tryParse(issuedAtRaw)
        : null;
    final now = DateTime.now();

    final isAvailable =
        order.paidAt != null &&
        order.status != OrderStatus.canceled &&
        (issuedAt == null || !now.isBefore(issuedAt));

    final invoiceNumber =
        (hit?.value['invoiceNumber'] as String?) ??
        _invoiceNumberFor(order: order, issuedAt: issuedAt ?? order.paidAt);

    return OrderInvoice(
      orderId: orderId,
      invoiceNumber: invoiceNumber,
      status: isAvailable
          ? OrderInvoiceStatus.available
          : OrderInvoiceStatus.pending,
      taxStatus: OrderInvoiceTaxStatus.taxable,
      issuedAt: isAvailable ? (issuedAt ?? order.paidAt) : null,
      downloadUrl: null,
    );
  }

  @override
  Future<List<int>> downloadInvoicePdf(String orderId) async {
    final invoice = await getInvoice(orderId);
    if (invoice.status != OrderInvoiceStatus.available) {
      throw StateError('Invoice is not available yet');
    }

    final order = await getOrder(orderId);
    final issuedAt = invoice.issuedAt ?? DateTime.now();
    final doc = pw.Document(
      creator: 'Hanko Field',
      title: invoice.invoiceNumber,
      author: 'Hanko Field',
    );

    final headerStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
    );
    final labelStyle = const pw.TextStyle(
      fontSize: 10,
      color: PdfColors.grey700,
    );
    final valueStyle = const pw.TextStyle(fontSize: 12);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) {
          return [
            pw.Text(
              _gates.prefersEnglish ? 'Invoice' : '領収書',
              style: headerStyle,
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _gates.prefersEnglish ? 'Invoice number' : '領収書番号',
                      style: labelStyle,
                    ),
                    pw.Text(invoice.invoiceNumber, style: valueStyle),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      _gates.prefersEnglish ? 'Order number' : '注文番号',
                      style: labelStyle,
                    ),
                    pw.Text(order.orderNumber, style: valueStyle),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      _gates.prefersEnglish ? 'Issued at' : '発行日',
                      style: labelStyle,
                    ),
                    pw.Text(_formatDate(issuedAt), style: valueStyle),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _gates.prefersEnglish ? 'Total' : '合計',
                      style: labelStyle,
                    ),
                    pw.Text(
                      _formatMoney(
                        order.totals.total,
                        currency: order.currency,
                      ),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              _gates.prefersEnglish ? 'Line items' : '明細',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(5),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _gates.prefersEnglish ? 'Item' : '商品',
                        style: labelStyle,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _gates.prefersEnglish ? 'Qty' : '数量',
                        style: labelStyle,
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _gates.prefersEnglish ? 'Amount' : '金額',
                        style: labelStyle,
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                ...order.lineItems.map((item) {
                  final name = item.name ?? item.sku;
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(name, style: valueStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${item.quantity}',
                          style: valueStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _formatMoney(item.total, currency: order.currency),
                          style: valueStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _totalsRow(
                    label: _gates.prefersEnglish ? 'Subtotal' : '小計',
                    value: _formatMoney(
                      order.totals.subtotal,
                      currency: order.currency,
                    ),
                  ),
                  if (order.totals.discount != 0)
                    _totalsRow(
                      label: _gates.prefersEnglish ? 'Discount' : '値引き',
                      value: _formatMoney(
                        -order.totals.discount,
                        currency: order.currency,
                      ),
                    ),
                  _totalsRow(
                    label: _gates.prefersEnglish ? 'Tax' : '消費税',
                    value: _formatMoney(
                      order.totals.tax,
                      currency: order.currency,
                    ),
                  ),
                  _totalsRow(
                    label: _gates.prefersEnglish ? 'Shipping' : '送料',
                    value: _formatMoney(
                      order.totals.shipping,
                      currency: order.currency,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey600),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          _gates.prefersEnglish ? 'Total' : '合計',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          _formatMoney(
                            order.totals.total,
                            currency: order.currency,
                          ),
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              _gates.prefersEnglish
                  ? 'Thank you for your purchase.'
                  : 'ご購入ありがとうございました。',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ];
        },
      ),
    );

    return doc.save();
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

      final cachedOrders = raw
          .whereType<Map<Object?, Object?>>()
          .map(
            (e) => OrderDto.fromJson(Map<String, Object?>.from(e)).toDomain(),
          )
          .toList();

      var migrated = false;
      final hydrated = cachedOrders.map((order) {
        if (order.status == OrderStatus.canceled) return order;
        if (order.status.index < OrderStatus.readyToShip.index) return order;
        if (order.shipments.isNotEmpty) return order;

        final seed = _stableRandomSeed(order.id ?? order.orderNumber);
        final shipments = _seedShipments(
          status: order.status,
          createdAt: order.createdAt,
          shippedAt: order.shippedAt,
          deliveredAt: order.deliveredAt,
          random: Random(seed),
        );
        if (shipments.isEmpty) return order;
        migrated = true;
        return order.copyWith(shipments: shipments);
      }).toList();

      _orders = hydrated;
      if (migrated) {
        await _persist();
      }
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

      final fulfillment = _seedFulfillment(
        status: status,
        createdAt: createdAt,
        shippedAt: shippedAt,
        deliveredAt: deliveredAt,
        canceledAt: canceledAt,
        random: random,
      );

      final production = _seedProductionInfo(status: status, random: random);

      final productionEvents = _seedProductionEvents(
        status: status,
        createdAt: createdAt,
        paidAt: paidAt,
        shippedAt: shippedAt,
        deliveredAt: deliveredAt,
        canceledAt: canceledAt,
        random: random,
        prefersEnglish: _gates.prefersEnglish,
      );

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
        fulfillment: fulfillment,
        production: production,
        canceledAt: canceledAt,
        cancelReason: status == OrderStatus.canceled
            ? (_gates.prefersEnglish ? 'Changed my mind' : '都合によりキャンセル')
            : null,
        payments: const [],
        shipments: _seedShipments(
          status: status,
          createdAt: createdAt,
          shippedAt: shippedAt,
          deliveredAt: deliveredAt,
          random: random,
        ),
        productionEvents: productionEvents,
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

  OrderFulfillment? _seedFulfillment({
    required OrderStatus status,
    required DateTime createdAt,
    required DateTime? shippedAt,
    required DateTime? deliveredAt,
    required DateTime? canceledAt,
    required Random random,
  }) {
    if (status == OrderStatus.pendingPayment) return null;
    if (status == OrderStatus.canceled && canceledAt == null) return null;

    final estimatedShipDate = createdAt.add(
      Duration(days: random.nextInt(5) + 2),
    );
    final estimatedDeliveryDate = estimatedShipDate.add(
      Duration(days: random.nextInt(4) + 1),
    );

    return OrderFulfillment(
      requestedAt: createdAt,
      estimatedShipDate: shippedAt ?? estimatedShipDate,
      estimatedDeliveryDate: deliveredAt ?? estimatedDeliveryDate,
    );
  }

  OrderProductionInfo? _seedProductionInfo({
    required OrderStatus status,
    required Random random,
  }) {
    if (status.index < OrderStatus.inProduction.index ||
        status == OrderStatus.canceled) {
      return null;
    }

    final stationNumber = (random.nextInt(6) + 1).toString().padLeft(2, '0');
    return OrderProductionInfo(
      queueRef: 'queues/standard',
      assignedStation: 'ST-$stationNumber',
      operatorRef: 'ops/${random.nextInt(90) + 10}',
    );
  }

  List<ProductionEvent> _seedProductionEvents({
    required OrderStatus status,
    required DateTime createdAt,
    required DateTime? paidAt,
    required DateTime? shippedAt,
    required DateTime? deliveredAt,
    required DateTime? canceledAt,
    required Random random,
    required bool prefersEnglish,
  }) {
    if (status == OrderStatus.pendingPayment) return const [];

    final base = paidAt ?? createdAt;
    final queuedAt = base.add(Duration(hours: random.nextInt(6) + 1));
    final engravingAt = queuedAt.add(Duration(hours: random.nextInt(20) + 6));
    final polishingAt = engravingAt.add(
      Duration(hours: random.nextInt(18) + 4),
    );
    final qcAt = polishingAt.add(Duration(hours: random.nextInt(10) + 2));
    final packedAt = qcAt.add(Duration(hours: random.nextInt(12) + 2));

    final qcFailed = random.nextInt(12) == 0;
    final qc = ProductionQcInfo(
      result: qcFailed ? 'fail' : 'pass',
      defects: qcFailed
          ? [
              prefersEnglish ? 'surface scratch' : '表面キズ',
              prefersEnglish ? 'edge roughness' : '縁の粗さ',
            ]
          : const [],
    );

    final events = <ProductionEvent>[
      ProductionEvent(type: ProductionEventType.queued, createdAt: queuedAt),
    ];

    if (status.index >= OrderStatus.inProduction.index &&
        status != OrderStatus.canceled) {
      events.addAll([
        ProductionEvent(
          type: ProductionEventType.engraving,
          createdAt: engravingAt,
          station: prefersEnglish ? 'Engraver' : '彫刻機',
        ),
        ProductionEvent(
          type: ProductionEventType.polishing,
          createdAt: polishingAt,
          station: prefersEnglish ? 'Finishing' : '研磨',
        ),
        ProductionEvent(
          type: ProductionEventType.qc,
          createdAt: qcAt,
          station: prefersEnglish ? 'QC' : '検品',
          qc: qc,
        ),
      ]);

      if (qcFailed) {
        final reworkAt = qcAt.add(Duration(hours: random.nextInt(8) + 2));
        final recheckAt = reworkAt.add(Duration(hours: random.nextInt(8) + 2));
        events.addAll([
          ProductionEvent(
            type: ProductionEventType.rework,
            createdAt: reworkAt,
            note: prefersEnglish
                ? 'Rework triggered after QC'
                : '検品の結果、再加工になりました',
          ),
          ProductionEvent(
            type: ProductionEventType.qc,
            createdAt: recheckAt,
            station: prefersEnglish ? 'QC' : '検品',
            qc: const ProductionQcInfo(result: 'pass'),
          ),
        ]);
      }
    }

    if (status.index >= OrderStatus.readyToShip.index &&
        status != OrderStatus.canceled) {
      events.add(
        ProductionEvent(
          type: ProductionEventType.packed,
          createdAt: packedAt,
          station: prefersEnglish ? 'Packing' : '梱包',
        ),
      );
    }

    if (status == OrderStatus.canceled && canceledAt != null) {
      events.add(
        ProductionEvent(
          type: ProductionEventType.canceled,
          createdAt: canceledAt,
          note: prefersEnglish ? 'Order canceled' : '注文がキャンセルされました',
        ),
      );
    }

    events.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return events;
  }

  int _stableRandomSeed(String value) {
    return value.hashCode & 0x7fffffff;
  }

  List<OrderShipment> _seedShipments({
    required OrderStatus status,
    required DateTime createdAt,
    required DateTime? shippedAt,
    required DateTime? deliveredAt,
    required Random random,
  }) {
    if (status.index < OrderStatus.readyToShip.index ||
        status == OrderStatus.canceled) {
      return const [];
    }

    final carrier = ShipmentCarrier
        .values[random.nextInt(ShipmentCarrier.values.length - 1)];
    final trackingNumber = 'TRK${(random.nextInt(900000000) + 100000000)}';
    final base =
        shippedAt ?? createdAt.add(Duration(days: random.nextInt(5) + 2));
    final eta = deliveredAt ?? base.add(Duration(days: random.nextInt(4) + 1));
    final localeCity = _gates.prefersEnglish ? 'Tokyo' : '東京都';

    final shipmentStatus = switch (status) {
      OrderStatus.readyToShip => ShipmentStatus.labelCreated,
      OrderStatus.shipped => ShipmentStatus.inTransit,
      OrderStatus.delivered => ShipmentStatus.delivered,
      _ => ShipmentStatus.inTransit,
    };

    final events = <ShipmentEvent>[
      ShipmentEvent(
        timestamp: base.subtract(const Duration(hours: 6)),
        code: ShipmentEventCode.labelCreated,
        location: localeCity,
      ),
    ];

    if (status.index >= OrderStatus.shipped.index) {
      events.add(
        ShipmentEvent(
          timestamp: base.subtract(const Duration(hours: 2)),
          code: ShipmentEventCode.pickedUp,
          location: localeCity,
        ),
      );
      events.add(
        ShipmentEvent(
          timestamp: base.add(const Duration(hours: 8)),
          code: ShipmentEventCode.inTransit,
          location: _gates.prefersEnglish ? 'Sort facility' : '仕分けセンター',
        ),
      );
      events.add(
        ShipmentEvent(
          timestamp: base.add(const Duration(days: 1, hours: 4)),
          code: ShipmentEventCode.arrivedHub,
          location: _gates.prefersEnglish ? 'Regional hub' : '地域拠点',
        ),
      );
    }

    if (status == OrderStatus.delivered) {
      events.add(
        ShipmentEvent(
          timestamp: eta.subtract(const Duration(hours: 5)),
          code: ShipmentEventCode.outForDelivery,
          location: _gates.prefersEnglish ? 'Local depot' : '配達拠点',
        ),
      );
      events.add(
        ShipmentEvent(
          timestamp: eta,
          code: ShipmentEventCode.delivered,
          location: _gates.prefersEnglish ? 'Destination' : 'お届け先',
        ),
      );
    }

    final sorted = List<ShipmentEvent>.of(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return [
      OrderShipment(
        id: 'shp_${createdAt.millisecondsSinceEpoch}',
        carrier: carrier,
        service: _gates.prefersEnglish ? 'Standard' : '通常便',
        trackingNumber: trackingNumber,
        status: shipmentStatus,
        eta: eta,
        createdAt: base,
        updatedAt: sorted.last.timestamp,
        events: sorted,
      ),
    ];
  }

  String _invoiceNumberFor({required Order order, DateTime? issuedAt}) {
    final y = (issuedAt ?? DateTime.now()).year;
    return 'INV-$y-${order.orderNumber}';
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatMoney(int amount, {required String currency}) {
    final digits = amount.abs().toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    final prefix = currency.toUpperCase() == 'JPY' ? '¥' : '$currency ';
    final sign = amount < 0 ? '-' : '';
    return '$sign$prefix$formatted';
  }

  pw.Widget _totalsRow({required String label, required String value}) {
    return pw.Container(
      width: 220,
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
