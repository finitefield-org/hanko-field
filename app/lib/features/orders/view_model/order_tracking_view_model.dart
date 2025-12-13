// ignore_for_file: public_member_api_docs

import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/data/repositories/order_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

class OrderTrackingState {
  const OrderTrackingState({required this.order, required this.shipments});

  final Order order;
  final List<OrderShipment> shipments;

  OrderTrackingState copyWith({Order? order, List<OrderShipment>? shipments}) {
    return OrderTrackingState(
      order: order ?? this.order,
      shipments: shipments ?? this.shipments,
    );
  }
}

class OrderTrackingViewModel extends AsyncProvider<OrderTrackingState> {
  OrderTrackingViewModel({required this.orderId})
    : super.args((orderId,), autoDispose: true);

  final String orderId;

  late final refreshMut = mutation<void>(#refresh);

  @override
  Future<OrderTrackingState> build(Ref ref) async {
    final repository = ref.watch(orderRepositoryProvider);
    final order = await repository.getOrder(orderId);
    final shipments = await repository.listShipments(orderId);
    final sorted = List<OrderShipment>.of(shipments)
      ..sort((a, b) {
        final aTime = a.updatedAt ?? a.createdAt;
        final bTime = b.updatedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

    return OrderTrackingState(order: order, shipments: sorted);
  }

  Call<void> refresh() => mutate(refreshMut, (ref) async {
    final repository = ref.watch(orderRepositoryProvider);
    final order = await repository.getOrder(orderId);
    final shipments = await repository.listShipments(orderId);
    final sorted = List<OrderShipment>.of(shipments)
      ..sort((a, b) {
        final aTime = a.updatedAt ?? a.createdAt;
        final bTime = b.updatedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
    ref.state = AsyncData(OrderTrackingState(order: order, shipments: sorted));
  }, concurrency: Concurrency.restart);
}
