import 'package:app/core/domain/repositories/order_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/orders/data/fake_order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return FakeOrderRepository(cache: cache);
});
