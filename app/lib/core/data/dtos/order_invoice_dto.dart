import 'package:app/core/domain/entities/order.dart';

OrderInvoiceStatus _parseInvoiceStatus(String value) {
  switch (value) {
    case 'draft':
      return OrderInvoiceStatus.draft;
    case 'issued':
      return OrderInvoiceStatus.issued;
    case 'sent':
      return OrderInvoiceStatus.sent;
    case 'paid':
      return OrderInvoiceStatus.paid;
    case 'void':
      return OrderInvoiceStatus.voided;
  }
  throw ArgumentError.value(value, 'value', 'Unknown OrderInvoiceStatus');
}

String _invoiceStatusToJson(OrderInvoiceStatus status) {
  switch (status) {
    case OrderInvoiceStatus.draft:
      return 'draft';
    case OrderInvoiceStatus.issued:
      return 'issued';
    case OrderInvoiceStatus.sent:
      return 'sent';
    case OrderInvoiceStatus.paid:
      return 'paid';
    case OrderInvoiceStatus.voided:
      return 'void';
  }
}

OrderInvoiceTaxStatus _parseInvoiceTaxStatus(String value) {
  switch (value) {
    case 'inclusive':
      return OrderInvoiceTaxStatus.inclusive;
    case 'exclusive':
      return OrderInvoiceTaxStatus.exclusive;
    case 'exempt':
      return OrderInvoiceTaxStatus.exempt;
  }
  throw ArgumentError.value(value, 'value', 'Unknown OrderInvoiceTaxStatus');
}

String _invoiceTaxStatusToJson(OrderInvoiceTaxStatus status) {
  switch (status) {
    case OrderInvoiceTaxStatus.inclusive:
      return 'inclusive';
    case OrderInvoiceTaxStatus.exclusive:
      return 'exclusive';
    case OrderInvoiceTaxStatus.exempt:
      return 'exempt';
  }
}

class OrderInvoiceLineItemDto {
  OrderInvoiceLineItemDto({required this.description, required this.amount});

  factory OrderInvoiceLineItemDto.fromJson(Map<String, dynamic> json) {
    return OrderInvoiceLineItemDto(
      description: json['description'] as String,
      amount: json['amount'] as int,
    );
  }

  factory OrderInvoiceLineItemDto.fromDomain(OrderInvoiceLineItem domain) {
    return OrderInvoiceLineItemDto(
      description: domain.description,
      amount: domain.amount,
    );
  }

  final String description;
  final int amount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'description': description, 'amount': amount};
  }

  OrderInvoiceLineItem toDomain() {
    return OrderInvoiceLineItem(description: description, amount: amount);
  }
}

class OrderInvoiceDto {
  OrderInvoiceDto({
    required this.id,
    required this.orderId,
    required this.invoiceNumber,
    required this.status,
    required this.taxStatus,
    required this.currency,
    required this.amount,
    required this.lineItems,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.sentAt,
    this.paidAt,
    this.voidedAt,
    this.taxAmount,
    this.pdfAssetRef,
    this.downloadUrl,
    this.metadata,
  });

  factory OrderInvoiceDto.fromJson(Map<String, dynamic> json) {
    return OrderInvoiceDto(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      status: _parseInvoiceStatus(json['status'] as String),
      taxStatus: _parseInvoiceTaxStatus(json['taxStatus'] as String),
      currency: json['currency'] as String,
      amount: json['amount'] as int,
      taxAmount: json['taxAmount'] as int?,
      lineItems: [
        for (final item in (json['lineItems'] as List<dynamic>? ?? const []))
          OrderInvoiceLineItemDto.fromJson(item as Map<String, dynamic>),
      ],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      sentAt: json['sentAt'] == null
          ? null
          : DateTime.parse(json['sentAt'] as String),
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
      voidedAt: json['voidedAt'] == null
          ? null
          : DateTime.parse(json['voidedAt'] as String),
      pdfAssetRef: json['pdfAssetRef'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }

  factory OrderInvoiceDto.fromDomain(OrderInvoice domain) {
    return OrderInvoiceDto(
      id: domain.id,
      orderId: domain.orderId,
      invoiceNumber: domain.invoiceNumber,
      status: domain.status,
      taxStatus: domain.taxStatus,
      currency: domain.currency,
      amount: domain.amount,
      taxAmount: domain.taxAmount,
      lineItems: [
        for (final item in domain.lineItems)
          OrderInvoiceLineItemDto.fromDomain(item),
      ],
      createdAt: domain.createdAt,
      updatedAt: domain.updatedAt,
      dueDate: domain.dueDate,
      sentAt: domain.sentAt,
      paidAt: domain.paidAt,
      voidedAt: domain.voidedAt,
      pdfAssetRef: domain.pdfAssetRef,
      downloadUrl: domain.downloadUrl,
      metadata: domain.metadata == null
          ? null
          : Map<String, dynamic>.from(domain.metadata!),
    );
  }

  final String id;
  final String orderId;
  final String invoiceNumber;
  final OrderInvoiceStatus status;
  final OrderInvoiceTaxStatus taxStatus;
  final String currency;
  final int amount;
  final int? taxAmount;
  final List<OrderInvoiceLineItemDto> lineItems;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final DateTime? sentAt;
  final DateTime? paidAt;
  final DateTime? voidedAt;
  final String? pdfAssetRef;
  final String? downloadUrl;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'orderId': orderId,
      'invoiceNumber': invoiceNumber,
      'status': _invoiceStatusToJson(status),
      'taxStatus': _invoiceTaxStatusToJson(taxStatus),
      'currency': currency,
      'amount': amount,
      'taxAmount': taxAmount,
      'lineItems': [for (final item in lineItems) item.toJson()],
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'voidedAt': voidedAt?.toIso8601String(),
      'pdfAssetRef': pdfAssetRef,
      'downloadUrl': downloadUrl,
      'metadata': metadata == null
          ? null
          : Map<String, dynamic>.from(metadata!),
    };
  }

  OrderInvoice toDomain() {
    return OrderInvoice(
      id: id,
      orderId: orderId,
      invoiceNumber: invoiceNumber,
      status: status,
      taxStatus: taxStatus,
      currency: currency,
      amount: amount,
      taxAmount: taxAmount,
      lineItems: [for (final item in lineItems) item.toDomain()],
      createdAt: createdAt,
      updatedAt: updatedAt,
      dueDate: dueDate,
      sentAt: sentAt,
      paidAt: paidAt,
      voidedAt: voidedAt,
      pdfAssetRef: pdfAssetRef,
      downloadUrl: downloadUrl,
      metadata: metadata == null ? null : Map<String, dynamic>.from(metadata!),
    );
  }
}
