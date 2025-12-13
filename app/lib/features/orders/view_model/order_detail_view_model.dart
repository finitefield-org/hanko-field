// ignore_for_file: public_member_api_docs

import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/data/repositories/order_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

class OrderDetailViewModel extends AsyncProvider<Order> {
  OrderDetailViewModel({required this.orderId})
    : super.args((orderId,), autoDispose: true);

  final String orderId;

  late final cancelMut = mutation<Order>(#cancel);
  late final reorderMut = mutation<Order>(#reorder);
  late final requestInvoiceMut = mutation<void>(#requestInvoice);

  @override
  Future<Order> build(Ref ref) async {
    final repository = ref.watch(orderRepositoryProvider);
    return repository.getOrder(orderId);
  }

  Call<Order> cancel({String? reason}) => mutate(cancelMut, (ref) async {
    final repository = ref.watch(orderRepositoryProvider);
    final updated = await repository.cancelOrder(orderId, reason: reason);
    ref.state = AsyncData(updated);
    return updated;
  }, concurrency: Concurrency.dropLatest);

  Call<void> requestInvoice() => mutate(requestInvoiceMut, (ref) async {
    final repository = ref.watch(orderRepositoryProvider);
    await repository.requestInvoice(orderId);
  }, concurrency: Concurrency.dropLatest);

  Call<Order> reorder() => mutate(reorderMut, (ref) async {
    final repository = ref.watch(orderRepositoryProvider);
    return repository.reorder(orderId);
  }, concurrency: Concurrency.dropLatest);
}
