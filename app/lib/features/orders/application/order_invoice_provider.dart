import 'package:app/core/domain/entities/order.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final orderInvoiceProvider = FutureProvider.autoDispose
    .family<OrderInvoice, String>((ref, orderId) {
      final repository = ref.watch(orderRepositoryProvider);
      return repository.fetchInvoice(orderId);
    });
