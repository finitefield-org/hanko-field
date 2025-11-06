import 'package:app/core/domain/entities/order.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final orderDetailsProvider = FutureProvider.autoDispose.family<Order, String>((
  ref,
  orderId,
) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.fetchOrder(orderId);
});
