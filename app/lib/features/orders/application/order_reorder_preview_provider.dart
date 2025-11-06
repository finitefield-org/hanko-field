import 'package:app/core/domain/entities/order_reorder.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final orderReorderPreviewProvider = FutureProvider.autoDispose
    .family<OrderReorderPreview, String>((ref, orderId) async {
      final repository = ref.watch(orderRepositoryProvider);
      return repository.fetchReorderPreview(orderId);
    });
