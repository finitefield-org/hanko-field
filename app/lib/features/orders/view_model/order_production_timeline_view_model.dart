// ignore_for_file: public_member_api_docs

import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/data/repositories/order_repository.dart';
import 'package:collection/collection.dart';
import 'package:miniriverpod/miniriverpod.dart';

class OrderProductionTimelineState {
  const OrderProductionTimelineState({
    required this.order,
    required this.events,
  });

  final Order order;
  final List<ProductionEvent> events;

  ProductionEvent? get latestEvent => events.lastOrNull;

  OrderProductionTimelineState copyWith({
    Order? order,
    List<ProductionEvent>? events,
  }) {
    return OrderProductionTimelineState(
      order: order ?? this.order,
      events: events ?? this.events,
    );
  }
}

class OrderProductionTimelineViewModel
    extends AsyncProvider<OrderProductionTimelineState> {
  OrderProductionTimelineViewModel({required this.orderId})
    : super.args((orderId,), autoDispose: true);

  final String orderId;

  late final refreshMut = mutation<void>(#refresh);

  @override
  Future<OrderProductionTimelineState> build(Ref ref) async {
    final repository = ref.watch(orderRepositoryProvider);
    final order = await repository.getOrder(orderId);
    final events = await repository.listProductionEvents(orderId);
    final sorted = List<ProductionEvent>.of(events)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return OrderProductionTimelineState(order: order, events: sorted);
  }

  Call<void> refresh() => mutate(refreshMut, (ref) async {
    final repository = ref.watch(orderRepositoryProvider);
    final order = await repository.getOrder(orderId);
    final events = await repository.listProductionEvents(orderId);
    final sorted = List<ProductionEvent>.of(events)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    ref.state = AsyncData(
      OrderProductionTimelineState(order: order, events: sorted),
    );
  }, concurrency: Concurrency.restart);
}
