// ignore_for_file: public_member_api_docs

enum OrderInvoiceStatus { pending, available }

enum OrderInvoiceTaxStatus { taxable, taxExempt }

class OrderInvoice {
  const OrderInvoice({
    required this.orderId,
    required this.invoiceNumber,
    required this.status,
    required this.taxStatus,
    this.issuedAt,
    this.downloadUrl,
  });

  final String orderId;
  final String invoiceNumber;
  final OrderInvoiceStatus status;
  final OrderInvoiceTaxStatus taxStatus;
  final DateTime? issuedAt;
  final Uri? downloadUrl;

  OrderInvoice copyWith({
    String? orderId,
    String? invoiceNumber,
    OrderInvoiceStatus? status,
    OrderInvoiceTaxStatus? taxStatus,
    DateTime? issuedAt,
    Uri? downloadUrl,
  }) {
    return OrderInvoice(
      orderId: orderId ?? this.orderId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      taxStatus: taxStatus ?? this.taxStatus,
      issuedAt: issuedAt ?? this.issuedAt,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }
}
