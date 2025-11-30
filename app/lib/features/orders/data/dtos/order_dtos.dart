// ignore_for_file: public_member_api_docs

import 'package:app/core/utils/json_utils.dart';
import 'package:app/features/orders/data/models/order_models.dart';

class OrderTotalsDto {
  const OrderTotalsDto({
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.tax,
    required this.total,
    this.fees = 0,
  });

  final int subtotal;
  final int discount;
  final int shipping;
  final int tax;
  final int total;
  final int fees;

  factory OrderTotalsDto.fromJson(Map<String, Object?> json) {
    return OrderTotalsDto(
      subtotal: (json['subtotal'] as num).toInt(),
      discount: (json['discount'] as num).toInt(),
      shipping: (json['shipping'] as num).toInt(),
      tax: (json['tax'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      fees: (json['fees'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'subtotal': subtotal,
    'discount': discount,
    'shipping': shipping,
    'tax': tax,
    'total': total,
    'fees': fees,
  };

  OrderTotals toDomain() {
    return OrderTotals(
      subtotal: subtotal,
      discount: discount,
      shipping: shipping,
      tax: tax,
      total: total,
      fees: fees,
    );
  }

  static OrderTotalsDto fromDomain(OrderTotals totals) {
    return OrderTotalsDto(
      subtotal: totals.subtotal,
      discount: totals.discount,
      shipping: totals.shipping,
      tax: totals.tax,
      total: totals.total,
      fees: totals.fees,
    );
  }
}

class OrderPromotionDto {
  const OrderPromotionDto({
    required this.code,
    required this.applied,
    this.discountAmount,
  });

  final String code;
  final bool applied;
  final int? discountAmount;

  factory OrderPromotionDto.fromJson(Map<String, Object?> json) {
    return OrderPromotionDto(
      code: json['code'] as String,
      applied: json['applied'] as bool? ?? false,
      discountAmount: (json['discountAmount'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'applied': applied,
    'discountAmount': discountAmount,
  };

  OrderPromotionSnapshot toDomain() {
    return OrderPromotionSnapshot(
      code: code,
      applied: applied,
      discountAmount: discountAmount,
    );
  }

  static OrderPromotionDto fromDomain(OrderPromotionSnapshot snapshot) {
    return OrderPromotionDto(
      code: snapshot.code,
      applied: snapshot.applied,
      discountAmount: snapshot.discountAmount,
    );
  }
}

class OrderLineItemDto {
  const OrderLineItemDto({
    required this.productRef,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.id,
    this.designRef,
    this.designSnapshot,
    this.name,
    this.options,
  });

  final String? id;
  final String productRef;
  final String? designRef;
  final Map<String, Object?>? designSnapshot;
  final String sku;
  final String? name;
  final Map<String, Object?>? options;
  final int quantity;
  final int unitPrice;
  final int total;

  factory OrderLineItemDto.fromJson(Map<String, Object?> json, {String? id}) {
    return OrderLineItemDto(
      id: id,
      productRef: json['productRef'] as String,
      designRef: json['designRef'] as String?,
      designSnapshot: asMap(json['designSnapshot']),
      sku: json['sku'] as String,
      name: json['name'] as String?,
      options: asMap(json['options']),
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'productRef': productRef,
    'designRef': designRef,
    'designSnapshot': designSnapshot,
    'sku': sku,
    'name': name,
    'options': options,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'total': total,
  };

  OrderLineItem toDomain() {
    return OrderLineItem(
      id: id,
      productRef: productRef,
      designRef: designRef,
      designSnapshot: designSnapshot,
      sku: sku,
      name: name,
      options: options,
      quantity: quantity,
      unitPrice: unitPrice,
      total: total,
    );
  }

  static OrderLineItemDto fromDomain(OrderLineItem item) {
    return OrderLineItemDto(
      id: item.id,
      productRef: item.productRef,
      designRef: item.designRef,
      designSnapshot: item.designSnapshot,
      sku: item.sku,
      name: item.name,
      options: item.options,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      total: item.total,
    );
  }
}

class OrderAddressDto {
  const OrderAddressDto({
    required this.recipient,
    required this.line1,
    required this.city,
    required this.postalCode,
    required this.country,
    this.line2,
    this.state,
    this.phone,
  });

  final String recipient;
  final String line1;
  final String? line2;
  final String city;
  final String? state;
  final String postalCode;
  final String country;
  final String? phone;

  factory OrderAddressDto.fromJson(Map<String, Object?> json) {
    return OrderAddressDto(
      recipient: json['recipient'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String,
      country: json['country'] as String,
      phone: json['phone'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'recipient': recipient,
    'line1': line1,
    'line2': line2,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'country': country,
    'phone': phone,
  };

  OrderAddress toDomain() {
    return OrderAddress(
      recipient: recipient,
      line1: line1,
      line2: line2,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      phone: phone,
    );
  }

  static OrderAddressDto fromDomain(OrderAddress address) {
    return OrderAddressDto(
      recipient: address.recipient,
      line1: address.line1,
      line2: address.line2,
      city: address.city,
      state: address.state,
      postalCode: address.postalCode,
      country: address.country,
      phone: address.phone,
    );
  }
}

class OrderContactDto {
  const OrderContactDto({this.email, this.phone});

  final String? email;
  final String? phone;

  factory OrderContactDto.fromJson(Map<String, Object?> json) {
    return OrderContactDto(
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'email': email,
    'phone': phone,
  };

  OrderContact toDomain() => OrderContact(email: email, phone: phone);

  static OrderContactDto fromDomain(OrderContact contact) {
    return OrderContactDto(email: contact.email, phone: contact.phone);
  }
}

class OrderFulfillmentDto {
  const OrderFulfillmentDto({
    this.requestedAt,
    this.estimatedShipDate,
    this.estimatedDeliveryDate,
  });

  final DateTime? requestedAt;
  final DateTime? estimatedShipDate;
  final DateTime? estimatedDeliveryDate;

  factory OrderFulfillmentDto.fromJson(Map<String, Object?> json) {
    return OrderFulfillmentDto(
      requestedAt: parseDateTime(json['requestedAt']),
      estimatedShipDate: parseDateTime(json['estimatedShipDate']),
      estimatedDeliveryDate: parseDateTime(json['estimatedDeliveryDate']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'requestedAt': requestedAt?.toIso8601String(),
    'estimatedShipDate': estimatedShipDate?.toIso8601String(),
    'estimatedDeliveryDate': estimatedDeliveryDate?.toIso8601String(),
  };

  OrderFulfillment toDomain() {
    return OrderFulfillment(
      requestedAt: requestedAt,
      estimatedShipDate: estimatedShipDate,
      estimatedDeliveryDate: estimatedDeliveryDate,
    );
  }

  static OrderFulfillmentDto fromDomain(OrderFulfillment fulfillment) {
    return OrderFulfillmentDto(
      requestedAt: fulfillment.requestedAt,
      estimatedShipDate: fulfillment.estimatedShipDate,
      estimatedDeliveryDate: fulfillment.estimatedDeliveryDate,
    );
  }
}

class OrderProductionInfoDto {
  const OrderProductionInfoDto({
    this.queueRef,
    this.assignedStation,
    this.operatorRef,
  });

  final String? queueRef;
  final String? assignedStation;
  final String? operatorRef;

  factory OrderProductionInfoDto.fromJson(Map<String, Object?> json) {
    return OrderProductionInfoDto(
      queueRef: json['queueRef'] as String?,
      assignedStation: json['assignedStation'] as String?,
      operatorRef: json['operatorRef'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'queueRef': queueRef,
    'assignedStation': assignedStation,
    'operatorRef': operatorRef,
  };

  OrderProductionInfo toDomain() {
    return OrderProductionInfo(
      queueRef: queueRef,
      assignedStation: assignedStation,
      operatorRef: operatorRef,
    );
  }

  static OrderProductionInfoDto fromDomain(OrderProductionInfo info) {
    return OrderProductionInfoDto(
      queueRef: info.queueRef,
      assignedStation: info.assignedStation,
      operatorRef: info.operatorRef,
    );
  }
}

class OrderFlagsDto {
  const OrderFlagsDto({this.manualReview, this.gift});

  final bool? manualReview;
  final bool? gift;

  factory OrderFlagsDto.fromJson(Map<String, Object?> json) {
    return OrderFlagsDto(
      manualReview: json['manualReview'] as bool?,
      gift: json['gift'] as bool?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'manualReview': manualReview,
    'gift': gift,
  };

  OrderFlags toDomain() => OrderFlags(manualReview: manualReview, gift: gift);

  static OrderFlagsDto fromDomain(OrderFlags flags) {
    return OrderFlagsDto(manualReview: flags.manualReview, gift: flags.gift);
  }
}

class OrderAuditDto {
  const OrderAuditDto({this.createdBy, this.updatedBy});

  final String? createdBy;
  final String? updatedBy;

  factory OrderAuditDto.fromJson(Map<String, Object?> json) {
    return OrderAuditDto(
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'createdBy': createdBy,
    'updatedBy': updatedBy,
  };

  OrderAudit toDomain() =>
      OrderAudit(createdBy: createdBy, updatedBy: updatedBy);

  static OrderAuditDto fromDomain(OrderAudit audit) {
    return OrderAuditDto(
      createdBy: audit.createdBy,
      updatedBy: audit.updatedBy,
    );
  }
}

class PaymentCaptureInfoDto {
  const PaymentCaptureInfoDto({this.captured, this.capturedAt});

  final bool? captured;
  final DateTime? capturedAt;

  factory PaymentCaptureInfoDto.fromJson(Map<String, Object?> json) {
    return PaymentCaptureInfoDto(
      captured: json['captured'] as bool?,
      capturedAt: parseDateTime(json['capturedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'captured': captured,
    'capturedAt': capturedAt?.toIso8601String(),
  };

  PaymentCaptureInfo toDomain() =>
      PaymentCaptureInfo(captured: captured, capturedAt: capturedAt);

  static PaymentCaptureInfoDto fromDomain(PaymentCaptureInfo capture) {
    return PaymentCaptureInfoDto(
      captured: capture.captured,
      capturedAt: capture.capturedAt,
    );
  }
}

class PaymentMethodSnapshotDto {
  const PaymentMethodSnapshotDto({
    required this.type,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
  });

  final PaymentMethodType type;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;

  factory PaymentMethodSnapshotDto.fromJson(Map<String, Object?> json) {
    return PaymentMethodSnapshotDto(
      type: PaymentMethodTypeX.fromJson(json['type'] as String),
      brand: json['brand'] as String?,
      last4: json['last4'] as String?,
      expMonth: (json['expMonth'] as num?)?.toInt(),
      expYear: (json['expYear'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.toJson(),
    'brand': brand,
    'last4': last4,
    'expMonth': expMonth,
    'expYear': expYear,
  };

  PaymentMethodSnapshot toDomain() {
    return PaymentMethodSnapshot(
      type: type,
      brand: brand,
      last4: last4,
      expMonth: expMonth,
      expYear: expYear,
    );
  }

  static PaymentMethodSnapshotDto fromDomain(PaymentMethodSnapshot method) {
    return PaymentMethodSnapshotDto(
      type: method.type,
      brand: method.brand,
      last4: method.last4,
      expMonth: method.expMonth,
      expYear: method.expYear,
    );
  }
}

class PaymentErrorDto {
  const PaymentErrorDto({this.code, this.message});

  final String? code;
  final String? message;

  factory PaymentErrorDto.fromJson(Map<String, Object?> json) {
    return PaymentErrorDto(
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
  };

  PaymentError toDomain() => PaymentError(code: code, message: message);

  static PaymentErrorDto fromDomain(PaymentError error) {
    return PaymentErrorDto(code: error.code, message: error.message);
  }
}

class OrderPaymentDto {
  const OrderPaymentDto({
    required this.provider,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.id,
    this.intentId,
    this.chargeId,
    this.capture,
    this.method,
    this.billingAddress,
    this.error,
    this.raw,
    this.idempotencyKey,
    this.updatedAt,
    this.settledAt,
    this.refundedAt,
  });

  final String? id;
  final PaymentProvider provider;
  final PaymentStatus status;
  final String? intentId;
  final String? chargeId;
  final int amount;
  final String currency;
  final PaymentCaptureInfoDto? capture;
  final PaymentMethodSnapshotDto? method;
  final OrderAddressDto? billingAddress;
  final PaymentErrorDto? error;
  final Map<String, Object?>? raw;
  final String? idempotencyKey;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? settledAt;
  final DateTime? refundedAt;

  factory OrderPaymentDto.fromJson(Map<String, Object?> json, {String? id}) {
    return OrderPaymentDto(
      id: id,
      provider: PaymentProviderX.fromJson(json['provider'] as String),
      status: PaymentStatusX.fromJson(json['status'] as String),
      intentId: json['intentId'] as String?,
      chargeId: json['chargeId'] as String?,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      capture: json['capture'] != null
          ? PaymentCaptureInfoDto.fromJson(
              Map<String, Object?>.from(json['capture'] as Map),
            )
          : null,
      method: json['method'] != null
          ? PaymentMethodSnapshotDto.fromJson(
              Map<String, Object?>.from(json['method'] as Map),
            )
          : null,
      billingAddress: json['billingAddress'] != null
          ? OrderAddressDto.fromJson(
              Map<String, Object?>.from(json['billingAddress'] as Map),
            )
          : null,
      error: json['error'] != null
          ? PaymentErrorDto.fromJson(
              Map<String, Object?>.from(json['error'] as Map),
            )
          : null,
      raw: asMap(json['raw']),
      idempotencyKey: json['idempotencyKey'] as String?,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: parseDateTime(json['updatedAt']),
      settledAt: parseDateTime(json['settledAt']),
      refundedAt: parseDateTime(json['refundedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'provider': provider.toJson(),
    'status': status.toJson(),
    'intentId': intentId,
    'chargeId': chargeId,
    'amount': amount,
    'currency': currency,
    'capture': capture?.toJson(),
    'method': method?.toJson(),
    'billingAddress': billingAddress?.toJson(),
    'error': error?.toJson(),
    'raw': raw,
    'idempotencyKey': idempotencyKey,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'settledAt': settledAt?.toIso8601String(),
    'refundedAt': refundedAt?.toIso8601String(),
  };

  OrderPayment toDomain() {
    return OrderPayment(
      id: id,
      provider: provider,
      status: status,
      intentId: intentId,
      chargeId: chargeId,
      amount: amount,
      currency: currency,
      capture: capture?.toDomain(),
      method: method?.toDomain(),
      billingAddress: billingAddress?.toDomain(),
      error: error?.toDomain(),
      raw: raw,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      updatedAt: updatedAt,
      settledAt: settledAt,
      refundedAt: refundedAt,
    );
  }

  static OrderPaymentDto fromDomain(OrderPayment payment) {
    return OrderPaymentDto(
      id: payment.id,
      provider: payment.provider,
      status: payment.status,
      intentId: payment.intentId,
      chargeId: payment.chargeId,
      amount: payment.amount,
      currency: payment.currency,
      capture: payment.capture != null
          ? PaymentCaptureInfoDto.fromDomain(payment.capture!)
          : null,
      method: payment.method != null
          ? PaymentMethodSnapshotDto.fromDomain(payment.method!)
          : null,
      billingAddress: payment.billingAddress != null
          ? OrderAddressDto.fromDomain(payment.billingAddress!)
          : null,
      error: payment.error != null
          ? PaymentErrorDto.fromDomain(payment.error!)
          : null,
      raw: payment.raw,
      idempotencyKey: payment.idempotencyKey,
      createdAt: payment.createdAt,
      updatedAt: payment.updatedAt,
      settledAt: payment.settledAt,
      refundedAt: payment.refundedAt,
    );
  }
}

class ShipmentEventDto {
  const ShipmentEventDto({
    required this.timestamp,
    required this.code,
    this.location,
    this.note,
  });

  final DateTime timestamp;
  final ShipmentEventCode code;
  final String? location;
  final String? note;

  factory ShipmentEventDto.fromJson(Map<String, Object?> json) {
    return ShipmentEventDto(
      timestamp:
          parseDateTime(json['ts']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      code: ShipmentEventCodeX.fromJson(json['code'] as String),
      location: json['location'] as String?,
      note: json['note'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'ts': timestamp.toIso8601String(),
    'code': code.toJson(),
    'location': location,
    'note': note,
  };

  ShipmentEvent toDomain() {
    return ShipmentEvent(
      timestamp: timestamp,
      code: code,
      location: location,
      note: note,
    );
  }

  static ShipmentEventDto fromDomain(ShipmentEvent event) {
    return ShipmentEventDto(
      timestamp: event.timestamp,
      code: event.code,
      location: event.location,
      note: event.note,
    );
  }
}

class OrderShipmentDto {
  const OrderShipmentDto({
    required this.carrier,
    required this.status,
    required this.createdAt,
    this.id,
    this.service,
    this.trackingNumber,
    this.eta,
    this.labelUrl,
    this.documents = const <String>[],
    this.events = const <ShipmentEventDto>[],
    this.updatedAt,
  });

  final String? id;
  final ShipmentCarrier carrier;
  final String? service;
  final String? trackingNumber;
  final ShipmentStatus status;
  final DateTime? eta;
  final String? labelUrl;
  final List<String> documents;
  final List<ShipmentEventDto> events;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory OrderShipmentDto.fromJson(Map<String, Object?> json, {String? id}) {
    return OrderShipmentDto(
      id: id,
      carrier: ShipmentCarrierX.fromJson(json['carrier'] as String),
      service: json['service'] as String?,
      trackingNumber: json['trackingNumber'] as String?,
      status: ShipmentStatusX.fromJson(json['status'] as String),
      eta: parseDateTime(json['eta']),
      labelUrl: json['labelUrl'] as String?,
      documents:
          (json['documents'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      events:
          (json['events'] as List?)
              ?.map(
                (e) => ShipmentEventDto.fromJson(
                  Map<String, Object?>.from(e as Map),
                ),
              )
              .toList() ??
          const <ShipmentEventDto>[],
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'carrier': carrier.toJson(),
    'service': service,
    'trackingNumber': trackingNumber,
    'status': status.toJson(),
    'eta': eta?.toIso8601String(),
    'labelUrl': labelUrl,
    'documents': documents,
    'events': events.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  OrderShipment toDomain() {
    return OrderShipment(
      id: id,
      carrier: carrier,
      service: service,
      trackingNumber: trackingNumber,
      status: status,
      eta: eta,
      labelUrl: labelUrl,
      documents: documents,
      events: events.map((e) => e.toDomain()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static OrderShipmentDto fromDomain(OrderShipment shipment) {
    return OrderShipmentDto(
      id: shipment.id,
      carrier: shipment.carrier,
      service: shipment.service,
      trackingNumber: shipment.trackingNumber,
      status: shipment.status,
      eta: shipment.eta,
      labelUrl: shipment.labelUrl,
      documents: shipment.documents,
      events: shipment.events
          .map((e) => ShipmentEventDto.fromDomain(e))
          .toList(),
      createdAt: shipment.createdAt,
      updatedAt: shipment.updatedAt,
    );
  }
}

class ProductionQcInfoDto {
  const ProductionQcInfoDto({this.result, this.defects = const <String>[]});

  final String? result;
  final List<String> defects;

  factory ProductionQcInfoDto.fromJson(Map<String, Object?> json) {
    return ProductionQcInfoDto(
      result: json['result'] as String?,
      defects:
          (json['defects'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'result': result,
    'defects': defects,
  };

  ProductionQcInfo toDomain() =>
      ProductionQcInfo(result: result, defects: defects);

  static ProductionQcInfoDto fromDomain(ProductionQcInfo qc) {
    return ProductionQcInfoDto(result: qc.result, defects: qc.defects);
  }
}

class ProductionEventDto {
  const ProductionEventDto({
    required this.type,
    required this.createdAt,
    this.station,
    this.operatorRef,
    this.durationSec,
    this.note,
    this.photoUrl,
    this.qc,
  });

  final ProductionEventType type;
  final DateTime createdAt;
  final String? station;
  final String? operatorRef;
  final int? durationSec;
  final String? note;
  final String? photoUrl;
  final ProductionQcInfoDto? qc;

  factory ProductionEventDto.fromJson(Map<String, Object?> json, {String? id}) {
    return ProductionEventDto(
      type: ProductionEventTypeX.fromJson(json['type'] as String),
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      station: json['station'] as String?,
      operatorRef: json['operatorRef'] as String?,
      durationSec: (json['durationSec'] as num?)?.toInt(),
      note: json['note'] as String?,
      photoUrl: json['photoUrl'] as String?,
      qc: json['qc'] != null
          ? ProductionQcInfoDto.fromJson(
              Map<String, Object?>.from(json['qc'] as Map),
            )
          : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'station': station,
    'operatorRef': operatorRef,
    'durationSec': durationSec,
    'note': note,
    'photoUrl': photoUrl,
    'qc': qc?.toJson(),
  };

  ProductionEvent toDomain() {
    return ProductionEvent(
      type: type,
      createdAt: createdAt,
      station: station,
      operatorRef: operatorRef,
      durationSec: durationSec,
      note: note,
      photoUrl: photoUrl,
      qc: qc?.toDomain(),
    );
  }

  static ProductionEventDto fromDomain(ProductionEvent event) {
    return ProductionEventDto(
      type: event.type,
      createdAt: event.createdAt,
      station: event.station,
      operatorRef: event.operatorRef,
      durationSec: event.durationSec,
      note: event.note,
      photoUrl: event.photoUrl,
      qc: event.qc != null ? ProductionQcInfoDto.fromDomain(event.qc!) : null,
    );
  }
}

class OrderDto {
  const OrderDto({
    required this.orderNumber,
    required this.userRef,
    required this.status,
    required this.currency,
    required this.totals,
    required this.lineItems,
    required this.shippingAddress,
    required this.createdAt,
    required this.updatedAt,
    this.id,
    this.cartRef,
    this.promotion,
    this.billingAddress,
    this.contact,
    this.fulfillment,
    this.production,
    this.notes,
    this.flags,
    this.audit,
    this.placedAt,
    this.paidAt,
    this.shippedAt,
    this.deliveredAt,
    this.canceledAt,
    this.cancelReason,
    this.metadata,
    this.payments = const <OrderPaymentDto>[],
    this.shipments = const <OrderShipmentDto>[],
    this.productionEvents = const <ProductionEventDto>[],
  });

  final String? id;
  final String orderNumber;
  final String userRef;
  final String? cartRef;
  final OrderStatus status;
  final String currency;
  final OrderTotalsDto totals;
  final OrderPromotionDto? promotion;
  final List<OrderLineItemDto> lineItems;
  final OrderAddressDto shippingAddress;
  final OrderAddressDto? billingAddress;
  final OrderContactDto? contact;
  final OrderFulfillmentDto? fulfillment;
  final OrderProductionInfoDto? production;
  final Map<String, Object?>? notes;
  final OrderFlagsDto? flags;
  final OrderAuditDto? audit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? placedAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? canceledAt;
  final String? cancelReason;
  final Map<String, Object?>? metadata;
  final List<OrderPaymentDto> payments;
  final List<OrderShipmentDto> shipments;
  final List<ProductionEventDto> productionEvents;

  factory OrderDto.fromJson(Map<String, Object?> json, {String? id}) {
    return OrderDto(
      id: id,
      orderNumber: json['orderNumber'] as String,
      userRef: json['userRef'] as String,
      cartRef: json['cartRef'] as String?,
      status: OrderStatusX.fromJson(json['status'] as String),
      currency: json['currency'] as String,
      totals: OrderTotalsDto.fromJson(
        Map<String, Object?>.from(json['totals'] as Map),
      ),
      promotion: json['promotion'] != null
          ? OrderPromotionDto.fromJson(
              Map<String, Object?>.from(json['promotion'] as Map),
            )
          : null,
      lineItems: (json['lineItems'] as List)
          .map(
            (e) =>
                OrderLineItemDto.fromJson(Map<String, Object?>.from(e as Map)),
          )
          .toList(),
      shippingAddress: OrderAddressDto.fromJson(
        Map<String, Object?>.from(json['shippingAddress'] as Map),
      ),
      billingAddress: json['billingAddress'] != null
          ? OrderAddressDto.fromJson(
              Map<String, Object?>.from(json['billingAddress'] as Map),
            )
          : null,
      contact: json['contact'] != null
          ? OrderContactDto.fromJson(
              Map<String, Object?>.from(json['contact'] as Map),
            )
          : null,
      fulfillment: json['fulfillment'] != null
          ? OrderFulfillmentDto.fromJson(
              Map<String, Object?>.from(json['fulfillment'] as Map),
            )
          : null,
      production: json['production'] != null
          ? OrderProductionInfoDto.fromJson(
              Map<String, Object?>.from(json['production'] as Map),
            )
          : null,
      notes: asMap(json['notes']),
      flags: json['flags'] != null
          ? OrderFlagsDto.fromJson(
              Map<String, Object?>.from(json['flags'] as Map),
            )
          : null,
      audit: json['audit'] != null
          ? OrderAuditDto.fromJson(
              Map<String, Object?>.from(json['audit'] as Map),
            )
          : null,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseDateTime(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      placedAt: parseDateTime(json['placedAt']),
      paidAt: parseDateTime(json['paidAt']),
      shippedAt: parseDateTime(json['shippedAt']),
      deliveredAt: parseDateTime(json['deliveredAt']),
      canceledAt: parseDateTime(json['canceledAt']),
      cancelReason: json['cancelReason'] as String?,
      metadata: asMap(json['metadata']),
      payments:
          (json['payments'] as List?)
              ?.map(
                (e) => OrderPaymentDto.fromJson(
                  Map<String, Object?>.from(e as Map),
                ),
              )
              .toList() ??
          const <OrderPaymentDto>[],
      shipments:
          (json['shipments'] as List?)
              ?.map(
                (e) => OrderShipmentDto.fromJson(
                  Map<String, Object?>.from(e as Map),
                ),
              )
              .toList() ??
          const <OrderShipmentDto>[],
      productionEvents:
          (json['productionEvents'] as List?)
              ?.map(
                (e) => ProductionEventDto.fromJson(
                  Map<String, Object?>.from(e as Map),
                ),
              )
              .toList() ??
          const <ProductionEventDto>[],
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'orderNumber': orderNumber,
    'userRef': userRef,
    'cartRef': cartRef,
    'status': status.toJson(),
    'currency': currency,
    'totals': totals.toJson(),
    'promotion': promotion?.toJson(),
    'lineItems': lineItems.map((e) => e.toJson()).toList(),
    'shippingAddress': shippingAddress.toJson(),
    'billingAddress': billingAddress?.toJson(),
    'contact': contact?.toJson(),
    'fulfillment': fulfillment?.toJson(),
    'production': production?.toJson(),
    'notes': notes,
    'flags': flags?.toJson(),
    'audit': audit?.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'placedAt': placedAt?.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
    'shippedAt': shippedAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
    'canceledAt': canceledAt?.toIso8601String(),
    'cancelReason': cancelReason,
    'metadata': metadata,
    'payments': payments.map((e) => e.toJson()).toList(),
    'shipments': shipments.map((e) => e.toJson()).toList(),
    'productionEvents': productionEvents.map((e) => e.toJson()).toList(),
  };

  Order toDomain() {
    return Order(
      id: id,
      orderNumber: orderNumber,
      userRef: userRef,
      cartRef: cartRef,
      status: status,
      currency: currency,
      totals: totals.toDomain(),
      promotion: promotion?.toDomain(),
      lineItems: lineItems.map((e) => e.toDomain()).toList(),
      shippingAddress: shippingAddress.toDomain(),
      billingAddress: billingAddress?.toDomain(),
      contact: contact?.toDomain(),
      fulfillment: fulfillment?.toDomain(),
      production: production?.toDomain(),
      notes: notes,
      flags: flags?.toDomain(),
      audit: audit?.toDomain(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      placedAt: placedAt,
      paidAt: paidAt,
      shippedAt: shippedAt,
      deliveredAt: deliveredAt,
      canceledAt: canceledAt,
      cancelReason: cancelReason,
      metadata: metadata,
      payments: payments.map((e) => e.toDomain()).toList(),
      shipments: shipments.map((e) => e.toDomain()).toList(),
      productionEvents: productionEvents.map((e) => e.toDomain()).toList(),
    );
  }

  static OrderDto fromDomain(Order order) {
    return OrderDto(
      id: order.id,
      orderNumber: order.orderNumber,
      userRef: order.userRef,
      cartRef: order.cartRef,
      status: order.status,
      currency: order.currency,
      totals: OrderTotalsDto.fromDomain(order.totals),
      promotion: order.promotion != null
          ? OrderPromotionDto.fromDomain(order.promotion!)
          : null,
      lineItems: order.lineItems
          .map((e) => OrderLineItemDto.fromDomain(e))
          .toList(),
      shippingAddress: OrderAddressDto.fromDomain(order.shippingAddress),
      billingAddress: order.billingAddress != null
          ? OrderAddressDto.fromDomain(order.billingAddress!)
          : null,
      contact: order.contact != null
          ? OrderContactDto.fromDomain(order.contact!)
          : null,
      fulfillment: order.fulfillment != null
          ? OrderFulfillmentDto.fromDomain(order.fulfillment!)
          : null,
      production: order.production != null
          ? OrderProductionInfoDto.fromDomain(order.production!)
          : null,
      notes: order.notes,
      flags: order.flags != null
          ? OrderFlagsDto.fromDomain(order.flags!)
          : null,
      audit: order.audit != null
          ? OrderAuditDto.fromDomain(order.audit!)
          : null,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
      placedAt: order.placedAt,
      paidAt: order.paidAt,
      shippedAt: order.shippedAt,
      deliveredAt: order.deliveredAt,
      canceledAt: order.canceledAt,
      cancelReason: order.cancelReason,
      metadata: order.metadata,
      payments: order.payments
          .map((e) => OrderPaymentDto.fromDomain(e))
          .toList(),
      shipments: order.shipments
          .map((e) => OrderShipmentDto.fromDomain(e))
          .toList(),
      productionEvents: order.productionEvents
          .map((e) => ProductionEventDto.fromDomain(e))
          .toList(),
    );
  }
}
