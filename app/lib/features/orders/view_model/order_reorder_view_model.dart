// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/model/value_objects.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/data/repositories/order_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum ReorderLineIssue { none, outOfStock, priceChanged }

class OrderReorderLine {
  const OrderReorderLine({
    required this.id,
    required this.item,
    required this.isSelected,
    required this.unitPriceNow,
    required this.issue,
  });

  final String id;
  final OrderLineItem item;
  final bool isSelected;
  final Money unitPriceNow;
  final ReorderLineIssue issue;

  Money get unitPriceWas =>
      Money(amount: item.unitPrice, currency: unitPriceNow.currency);

  OrderReorderLine copyWith({bool? isSelected}) {
    return OrderReorderLine(
      id: id,
      item: item,
      isSelected: isSelected ?? this.isSelected,
      unitPriceNow: unitPriceNow,
      issue: issue,
    );
  }
}

class OrderReorderState {
  const OrderReorderState({required this.order, required this.lines});

  final Order order;
  final List<OrderReorderLine> lines;

  bool get hasOutOfStock =>
      lines.any((line) => line.issue == ReorderLineIssue.outOfStock);

  bool get hasPriceChanges =>
      lines.any((line) => line.issue == ReorderLineIssue.priceChanged);

  int get selectableCount =>
      lines.where((line) => line.issue != ReorderLineIssue.outOfStock).length;

  int get selectedCount => lines.where((line) => line.isSelected).length;
}

class OrderReorderViewModel extends AsyncProvider<OrderReorderState> {
  OrderReorderViewModel({required this.orderId})
    : super.args((orderId,), autoDispose: true);

  final String orderId;

  late final toggleLineMut = mutation<OrderReorderState>(#toggleLine);

  @override
  Future<OrderReorderState> build(
    Ref<AsyncValue<OrderReorderState>> ref,
  ) async {
    final repository = ref.watch(orderRepositoryProvider);
    final order = await repository.getOrder(orderId);
    final currency = order.currency.isEmpty ? 'JPY' : order.currency;

    final lines = <OrderReorderLine>[
      for (var index = 0; index < order.lineItems.length; index++)
        _toReorderLine(
          currency: currency,
          order: order,
          item: order.lineItems[index],
          index: index,
        ),
    ];

    return OrderReorderState(order: order, lines: lines);
  }

  Call<OrderReorderState, AsyncValue<OrderReorderState>> toggleLine(
    String lineId,
  ) => mutate(toggleLineMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) throw StateError('Reorder state not loaded');

    final updatedLines = current.lines.map((line) {
      if (line.id != lineId) return line;
      if (line.issue == ReorderLineIssue.outOfStock) return line;
      return line.copyWith(isSelected: !line.isSelected);
    }).toList();

    final updated = OrderReorderState(
      order: current.order,
      lines: updatedLines,
    );
    ref.state = AsyncData(updated);
    return updated;
  }, concurrency: Concurrency.dropLatest);
}

List<CartLineItem> buildCartLinesFromReorder(
  OrderReorderState state,
  AppExperienceGates gates,
) {
  final en = gates.prefersEnglish;

  return state.lines.where((line) => line.isSelected).map((line) {
    final item = line.item;
    final snapshotLabel = (item.designSnapshot?['label'] as String?)?.trim();
    final title = (item.name?.trim().isNotEmpty == true)
        ? item.name!.trim()
        : (en ? 'Hanko item' : '印鑑');

    final variantLabel = item.sku.isEmpty ? (en ? 'Variant' : '仕様') : item.sku;
    final designLabel = snapshotLabel == null || snapshotLabel.isEmpty
        ? null
        : (en ? 'Design: $snapshotLabel' : 'デザイン：$snapshotLabel');

    final compareAt = line.issue == ReorderLineIssue.priceChanged
        ? Money(amount: item.unitPrice, currency: line.unitPriceNow.currency)
        : null;

    return CartLineItem(
      id: 'reorder-${state.order.id ?? state.order.orderNumber}-${line.id}',
      title: title,
      variantLabel: variantLabel,
      thumbnailUrl:
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=640&q=60',
      basePrice: line.unitPriceNow,
      compareAtPrice: compareAt,
      quantity: max(1, item.quantity),
      addonOptions: const [],
      selectedAddonIds: const <String>{},
      leadTimeMinDays: gates.isJapanRegion ? 2 : 5,
      leadTimeMaxDays: gates.isJapanRegion ? 4 : 9,
      designLabel: designLabel,
      note: en
          ? 'Reordered from ${state.order.orderNumber}'
          : '再注文：${state.order.orderNumber}',
      ribbon: line.issue == ReorderLineIssue.priceChanged
          ? (en ? 'Updated price' : '価格更新')
          : (en ? 'Reorder' : '再注文'),
    );
  }).toList();
}

OrderReorderLine _toReorderLine({
  required String currency,
  required Order order,
  required OrderLineItem item,
  required int index,
}) {
  final key =
      '${order.id ?? order.orderNumber}|${item.productRef}|${item.sku}|$index';
  final seed = _stableHash32(key);
  final random = Random(seed);

  final outOfStock = seed % 11 == 0;
  final priceChanged = !outOfStock && seed % 9 == 0;

  final original = Money(amount: item.unitPrice, currency: currency);

  Money priceNow = original;
  if (priceChanged) {
    final deltaPct = random.nextBool() ? 0.08 : -0.05;
    final updated = max(0, (item.unitPrice * (1 + deltaPct)).round());
    priceNow = Money(amount: updated, currency: currency);
  }

  return OrderReorderLine(
    id: 'line-$index',
    item: item,
    isSelected: !outOfStock,
    unitPriceNow: priceNow,
    issue: outOfStock
        ? ReorderLineIssue.outOfStock
        : (priceChanged
              ? ReorderLineIssue.priceChanged
              : ReorderLineIssue.none),
  );
}

int _stableHash32(String input) {
  const int offset = 0x811C9DC5;
  const int prime = 0x01000193;
  var hash = offset;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * prime) & 0xFFFFFFFF;
  }
  return hash;
}
