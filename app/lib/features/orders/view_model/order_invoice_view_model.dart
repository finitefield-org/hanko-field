// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

import 'package:app/features/orders/data/models/order_invoice_models.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/data/repositories/order_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

class OrderInvoiceViewState {
  const OrderInvoiceViewState({
    required this.order,
    required this.invoice,
    required this.pdfBytes,
  });

  final Order order;
  final OrderInvoice invoice;
  final Uint8List? pdfBytes;
}

class OrderInvoiceViewModel extends AsyncProvider<OrderInvoiceViewState> {
  OrderInvoiceViewModel({required this.orderId})
    : super.args((orderId,), autoDispose: true);

  final String orderId;

  late final requestInvoiceMut = mutation<void>(#requestInvoice);

  @override
  Future<OrderInvoiceViewState> build(
    Ref<AsyncValue<OrderInvoiceViewState>> ref,
  ) async {
    final repository = ref.watch(orderRepositoryProvider);
    final order = await repository.getOrder(orderId);
    final invoice = await repository.getInvoice(orderId);
    final bytes = invoice.status == OrderInvoiceStatus.available
        ? Uint8List.fromList(await repository.downloadInvoicePdf(orderId))
        : null;

    return OrderInvoiceViewState(
      order: order,
      invoice: invoice,
      pdfBytes: bytes,
    );
  }

  Call<void, AsyncValue<OrderInvoiceViewState>> requestInvoice() =>
      mutate(requestInvoiceMut, (ref) async {
        final repository = ref.watch(orderRepositoryProvider);
        await repository.requestInvoice(orderId);
        final updated = await build(ref);
        ref.state = AsyncData(updated);
      }, concurrency: Concurrency.dropLatest);
}
