// ignore_for_file: public_member_api_docs

import 'package:collection/collection.dart';

enum OrderStatus {
  draft,
  pendingPayment,
  paid,
  inProduction,
  readyToShip,
  shipped,
  delivered,
  canceled,
}

extension OrderStatusX on OrderStatus {
  String toJson() => switch (this) {
    OrderStatus.draft => 'draft',
    OrderStatus.pendingPayment => 'pending_payment',
    OrderStatus.paid => 'paid',
    OrderStatus.inProduction => 'in_production',
    OrderStatus.readyToShip => 'ready_to_ship',
    OrderStatus.shipped => 'shipped',
    OrderStatus.delivered => 'delivered',
    OrderStatus.canceled => 'canceled',
  };

  static OrderStatus fromJson(String value) {
    switch (value) {
      case 'draft':
        return OrderStatus.draft;
      case 'pending_payment':
        return OrderStatus.pendingPayment;
      case 'paid':
        return OrderStatus.paid;
      case 'in_production':
        return OrderStatus.inProduction;
      case 'ready_to_ship':
        return OrderStatus.readyToShip;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'canceled':
        return OrderStatus.canceled;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported order status');
  }
}

class OrderTotals {
  const OrderTotals({
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

  OrderTotals copyWith({
    int? subtotal,
    int? discount,
    int? shipping,
    int? tax,
    int? total,
    int? fees,
  }) {
    return OrderTotals(
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      shipping: shipping ?? this.shipping,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      fees: fees ?? this.fees,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is OrderTotals &&
            other.subtotal == subtotal &&
            other.discount == discount &&
            other.shipping == shipping &&
            other.tax == tax &&
            other.total == total &&
            other.fees == fees);
  }

  @override
  int get hashCode =>
      Object.hash(subtotal, discount, shipping, tax, total, fees);
}

class OrderPromotionSnapshot {
  const OrderPromotionSnapshot({
    required this.code,
    required this.applied,
    this.discountAmount,
  });

  final String code;
  final bool applied;
  final int? discountAmount;

  OrderPromotionSnapshot copyWith({
    String? code,
    bool? applied,
    int? discountAmount,
  }) {
    return OrderPromotionSnapshot(
      code: code ?? this.code,
      applied: applied ?? this.applied,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is OrderPromotionSnapshot &&
            other.code == code &&
            other.applied == applied &&
            other.discountAmount == discountAmount);
  }

  @override
  int get hashCode => Object.hash(code, applied, discountAmount);
}

class OrderLineItem {
  const OrderLineItem({
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

  OrderLineItem copyWith({
    String? id,
    String? productRef,
    String? designRef,
    Map<String, Object?>? designSnapshot,
    String? sku,
    String? name,
    Map<String, Object?>? options,
    int? quantity,
    int? unitPrice,
    int? total,
  }) {
    return OrderLineItem(
      id: id ?? this.id,
      productRef: productRef ?? this.productRef,
      designRef: designRef ?? this.designRef,
      designSnapshot: designSnapshot ?? this.designSnapshot,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      options: options ?? this.options,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
    );
  }

  @override
  bool operator ==(Object other) {
    const deepEq = DeepCollectionEquality();
    return identical(this, other) ||
        (other is OrderLineItem &&
            other.id == id &&
            other.productRef == productRef &&
            other.designRef == designRef &&
            deepEq.equals(other.designSnapshot, designSnapshot) &&
            other.sku == sku &&
            other.name == name &&
            deepEq.equals(other.options, options) &&
            other.quantity == quantity &&
            other.unitPrice == unitPrice &&
            other.total == total);
  }

  @override
  int get hashCode {
    const deepEq = DeepCollectionEquality();
    return Object.hash(
      id,
      productRef,
      designRef,
      deepEq.hash(designSnapshot),
      sku,
      name,
      deepEq.hash(options),
      quantity,
      unitPrice,
      total,
    );
  }
}

class OrderAddress {
  const OrderAddress({
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

  OrderAddress copyWith({
    String? recipient,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? phone,
  }) {
    return OrderAddress(
      recipient: recipient ?? this.recipient,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      phone: phone ?? this.phone,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is OrderAddress &&
            other.recipient == recipient &&
            other.line1 == line1 &&
            other.line2 == line2 &&
            other.city == city &&
            other.state == state &&
            other.postalCode == postalCode &&
            other.country == country &&
            other.phone == phone);
  }

  @override
  int get hashCode => Object.hash(
    recipient,
    line1,
    line2,
    city,
    state,
    postalCode,
    country,
    phone,
  );
}

class OrderContact {
  const OrderContact({this.email, this.phone});

  final String? email;
  final String? phone;

  OrderContact copyWith({String? email, String? phone}) {
    return OrderContact(email: email ?? this.email, phone: phone ?? this.phone);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is OrderContact && other.email == email && other.phone == phone);
  }

  @override
  int get hashCode => Object.hash(email, phone);
}

class OrderFulfillment {
  const OrderFulfillment({
    this.requestedAt,
    this.estimatedShipDate,
    this.estimatedDeliveryDate,
  });

  final DateTime? requestedAt;
  final DateTime? estimatedShipDate;
  final DateTime? estimatedDeliveryDate;

  OrderFulfillment copyWith({
    DateTime? requestedAt,
    DateTime? estimatedShipDate,
    DateTime? estimatedDeliveryDate,
  }) {
    return OrderFulfillment(
      requestedAt: requestedAt ?? this.requestedAt,
      estimatedShipDate: estimatedShipDate ?? this.estimatedShipDate,
      estimatedDeliveryDate:
          estimatedDeliveryDate ?? this.estimatedDeliveryDate,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is OrderFulfillment &&
            other.requestedAt == requestedAt &&
            other.estimatedShipDate == estimatedShipDate &&
            other.estimatedDeliveryDate == estimatedDeliveryDate);
  }

  @override
  int get hashCode =>
      Object.hash(requestedAt, estimatedShipDate, estimatedDeliveryDate);
}

class OrderProductionInfo {
  const OrderProductionInfo({
    this.queueRef,
    this.assignedStation,
    this.operatorRef,
  });

  final String? queueRef;
  final String? assignedStation;
  final String? operatorRef;

  OrderProductionInfo copyWith({
    String? queueRef,
    String? assignedStation,
    String? operatorRef,
  }) {
    return OrderProductionInfo(
      queueRef: queueRef ?? this.queueRef,
      assignedStation: assignedStation ?? this.assignedStation,
      operatorRef: operatorRef ?? this.operatorRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is OrderProductionInfo &&
            other.queueRef == queueRef &&
            other.assignedStation == assignedStation &&
            other.operatorRef == operatorRef);
  }

  @override
  int get hashCode => Object.hash(queueRef, assignedStation, operatorRef);
}

class OrderFlags {
  const OrderFlags({this.manualReview, this.gift});

  final bool? manualReview;
  final bool? gift;

  OrderFlags copyWith({bool? manualReview, bool? gift}) {
    return OrderFlags(
      manualReview: manualReview ?? this.manualReview,
      gift: gift ?? this.gift,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is OrderFlags &&
            other.manualReview == manualReview &&
            other.gift == gift);
  }

  @override
  int get hashCode => Object.hash(manualReview, gift);
}

class OrderAudit {
  const OrderAudit({this.createdBy, this.updatedBy});

  final String? createdBy;
  final String? updatedBy;

  OrderAudit copyWith({String? createdBy, String? updatedBy}) {
    return OrderAudit(
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is OrderAudit &&
            other.createdBy == createdBy &&
            other.updatedBy == updatedBy);
  }

  @override
  int get hashCode => Object.hash(createdBy, updatedBy);
}

enum PaymentProvider { stripe, paypal, other }

extension PaymentProviderX on PaymentProvider {
  String toJson() => switch (this) {
    PaymentProvider.stripe => 'stripe',
    PaymentProvider.paypal => 'paypal',
    PaymentProvider.other => 'other',
  };

  static PaymentProvider fromJson(String value) {
    switch (value) {
      case 'stripe':
        return PaymentProvider.stripe;
      case 'paypal':
        return PaymentProvider.paypal;
      case 'other':
        return PaymentProvider.other;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported provider');
  }
}

enum PaymentMethodType { card, wallet, bank, other }

extension PaymentMethodTypeX on PaymentMethodType {
  String toJson() => switch (this) {
    PaymentMethodType.card => 'card',
    PaymentMethodType.wallet => 'wallet',
    PaymentMethodType.bank => 'bank',
    PaymentMethodType.other => 'other',
  };

  static PaymentMethodType fromJson(String value) {
    switch (value) {
      case 'card':
        return PaymentMethodType.card;
      case 'wallet':
        return PaymentMethodType.wallet;
      case 'bank':
        return PaymentMethodType.bank;
      case 'other':
        return PaymentMethodType.other;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported method type');
  }
}

enum PaymentStatus {
  requiresAction,
  authorized,
  succeeded,
  failed,
  refunded,
  partiallyRefunded,
  canceled,
}

extension PaymentStatusX on PaymentStatus {
  String toJson() => switch (this) {
    PaymentStatus.requiresAction => 'requires_action',
    PaymentStatus.authorized => 'authorized',
    PaymentStatus.succeeded => 'succeeded',
    PaymentStatus.failed => 'failed',
    PaymentStatus.refunded => 'refunded',
    PaymentStatus.partiallyRefunded => 'partially_refunded',
    PaymentStatus.canceled => 'canceled',
  };

  static PaymentStatus fromJson(String value) {
    switch (value) {
      case 'requires_action':
        return PaymentStatus.requiresAction;
      case 'authorized':
        return PaymentStatus.authorized;
      case 'succeeded':
        return PaymentStatus.succeeded;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'partially_refunded':
        return PaymentStatus.partiallyRefunded;
      case 'canceled':
        return PaymentStatus.canceled;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported payment status');
  }
}

class PaymentCaptureInfo {
  const PaymentCaptureInfo({this.captured, this.capturedAt});

  final bool? captured;
  final DateTime? capturedAt;

  PaymentCaptureInfo copyWith({bool? captured, DateTime? capturedAt}) {
    return PaymentCaptureInfo(
      captured: captured ?? this.captured,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PaymentCaptureInfo &&
            other.captured == captured &&
            other.capturedAt == capturedAt);
  }

  @override
  int get hashCode => Object.hash(captured, capturedAt);
}

class PaymentMethodSnapshot {
  const PaymentMethodSnapshot({
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

  PaymentMethodSnapshot copyWith({
    PaymentMethodType? type,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
  }) {
    return PaymentMethodSnapshot(
      type: type ?? this.type,
      brand: brand ?? this.brand,
      last4: last4 ?? this.last4,
      expMonth: expMonth ?? this.expMonth,
      expYear: expYear ?? this.expYear,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PaymentMethodSnapshot &&
            other.type == type &&
            other.brand == brand &&
            other.last4 == last4 &&
            other.expMonth == expMonth &&
            other.expYear == expYear);
  }

  @override
  int get hashCode => Object.hash(type, brand, last4, expMonth, expYear);
}

class PaymentError {
  const PaymentError({this.code, this.message});

  final String? code;
  final String? message;

  PaymentError copyWith({String? code, String? message}) {
    return PaymentError(
      code: code ?? this.code,
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PaymentError &&
            other.code == code &&
            other.message == message);
  }

  @override
  int get hashCode => Object.hash(code, message);
}

class OrderPayment {
  const OrderPayment({
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
  final PaymentCaptureInfo? capture;
  final PaymentMethodSnapshot? method;
  final OrderAddress? billingAddress;
  final PaymentError? error;
  final Map<String, Object?>? raw;
  final String? idempotencyKey;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? settledAt;
  final DateTime? refundedAt;

  OrderPayment copyWith({
    String? id,
    PaymentProvider? provider,
    PaymentStatus? status,
    String? intentId,
    String? chargeId,
    int? amount,
    String? currency,
    PaymentCaptureInfo? capture,
    PaymentMethodSnapshot? method,
    OrderAddress? billingAddress,
    PaymentError? error,
    Map<String, Object?>? raw,
    String? idempotencyKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? settledAt,
    DateTime? refundedAt,
  }) {
    return OrderPayment(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      status: status ?? this.status,
      intentId: intentId ?? this.intentId,
      chargeId: chargeId ?? this.chargeId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      capture: capture ?? this.capture,
      method: method ?? this.method,
      billingAddress: billingAddress ?? this.billingAddress,
      error: error ?? this.error,
      raw: raw ?? this.raw,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settledAt: settledAt ?? this.settledAt,
      refundedAt: refundedAt ?? this.refundedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const deepEq = DeepCollectionEquality();
    return identical(this, other) ||
        (other is OrderPayment &&
            other.id == id &&
            other.provider == provider &&
            other.status == status &&
            other.intentId == intentId &&
            other.chargeId == chargeId &&
            other.amount == amount &&
            other.currency == currency &&
            other.capture == capture &&
            other.method == method &&
            other.billingAddress == billingAddress &&
            other.error == error &&
            deepEq.equals(other.raw, raw) &&
            other.idempotencyKey == idempotencyKey &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.settledAt == settledAt &&
            other.refundedAt == refundedAt);
  }

  @override
  int get hashCode {
    const deepEq = DeepCollectionEquality();
    return Object.hash(
      id,
      provider,
      status,
      intentId,
      chargeId,
      amount,
      currency,
      capture,
      method,
      billingAddress,
      error,
      deepEq.hash(raw),
      idempotencyKey,
      createdAt,
      updatedAt,
      settledAt,
      refundedAt,
    );
  }
}

enum ShipmentCarrier { jppost, yamato, sagawa, dhl, ups, fedex, other }

extension ShipmentCarrierX on ShipmentCarrier {
  String toJson() => switch (this) {
    ShipmentCarrier.jppost => 'JPPOST',
    ShipmentCarrier.yamato => 'YAMATO',
    ShipmentCarrier.sagawa => 'SAGAWA',
    ShipmentCarrier.dhl => 'DHL',
    ShipmentCarrier.ups => 'UPS',
    ShipmentCarrier.fedex => 'FEDEX',
    ShipmentCarrier.other => 'OTHER',
  };

  static ShipmentCarrier fromJson(String value) {
    switch (value) {
      case 'JPPOST':
        return ShipmentCarrier.jppost;
      case 'YAMATO':
        return ShipmentCarrier.yamato;
      case 'SAGAWA':
        return ShipmentCarrier.sagawa;
      case 'DHL':
        return ShipmentCarrier.dhl;
      case 'UPS':
        return ShipmentCarrier.ups;
      case 'FEDEX':
        return ShipmentCarrier.fedex;
      case 'OTHER':
        return ShipmentCarrier.other;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported shipment carrier');
  }
}

enum ShipmentStatus {
  labelCreated,
  inTransit,
  outForDelivery,
  delivered,
  exception,
  cancelled,
}

extension ShipmentStatusX on ShipmentStatus {
  String toJson() => switch (this) {
    ShipmentStatus.labelCreated => 'label_created',
    ShipmentStatus.inTransit => 'in_transit',
    ShipmentStatus.outForDelivery => 'out_for_delivery',
    ShipmentStatus.delivered => 'delivered',
    ShipmentStatus.exception => 'exception',
    ShipmentStatus.cancelled => 'cancelled',
  };

  static ShipmentStatus fromJson(String value) {
    switch (value) {
      case 'label_created':
        return ShipmentStatus.labelCreated;
      case 'in_transit':
        return ShipmentStatus.inTransit;
      case 'out_for_delivery':
        return ShipmentStatus.outForDelivery;
      case 'delivered':
        return ShipmentStatus.delivered;
      case 'exception':
        return ShipmentStatus.exception;
      case 'cancelled':
        return ShipmentStatus.cancelled;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported shipment status');
  }
}

enum ShipmentEventCode {
  labelCreated,
  pickedUp,
  inTransit,
  arrivedHub,
  customsClearance,
  outForDelivery,
  delivered,
  exception,
  returnToSender,
}

extension ShipmentEventCodeX on ShipmentEventCode {
  String toJson() => switch (this) {
    ShipmentEventCode.labelCreated => 'label_created',
    ShipmentEventCode.pickedUp => 'picked_up',
    ShipmentEventCode.inTransit => 'in_transit',
    ShipmentEventCode.arrivedHub => 'arrived_hub',
    ShipmentEventCode.customsClearance => 'customs_clearance',
    ShipmentEventCode.outForDelivery => 'out_for_delivery',
    ShipmentEventCode.delivered => 'delivered',
    ShipmentEventCode.exception => 'exception',
    ShipmentEventCode.returnToSender => 'return_to_sender',
  };

  static ShipmentEventCode fromJson(String value) {
    switch (value) {
      case 'label_created':
        return ShipmentEventCode.labelCreated;
      case 'picked_up':
        return ShipmentEventCode.pickedUp;
      case 'in_transit':
        return ShipmentEventCode.inTransit;
      case 'arrived_hub':
        return ShipmentEventCode.arrivedHub;
      case 'customs_clearance':
        return ShipmentEventCode.customsClearance;
      case 'out_for_delivery':
        return ShipmentEventCode.outForDelivery;
      case 'delivered':
        return ShipmentEventCode.delivered;
      case 'exception':
        return ShipmentEventCode.exception;
      case 'return_to_sender':
        return ShipmentEventCode.returnToSender;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unsupported shipment event code',
    );
  }
}

class ShipmentEvent {
  const ShipmentEvent({
    required this.timestamp,
    required this.code,
    this.location,
    this.note,
  });

  final DateTime timestamp;
  final ShipmentEventCode code;
  final String? location;
  final String? note;

  ShipmentEvent copyWith({
    DateTime? timestamp,
    ShipmentEventCode? code,
    String? location,
    String? note,
  }) {
    return ShipmentEvent(
      timestamp: timestamp ?? this.timestamp,
      code: code ?? this.code,
      location: location ?? this.location,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ShipmentEvent &&
            other.timestamp == timestamp &&
            other.code == code &&
            other.location == location &&
            other.note == note);
  }

  @override
  int get hashCode => Object.hash(timestamp, code, location, note);
}

class OrderShipment {
  const OrderShipment({
    required this.carrier,
    required this.status,
    required this.createdAt,
    this.id,
    this.service,
    this.trackingNumber,
    this.eta,
    this.labelUrl,
    this.documents = const <String>[],
    this.events = const <ShipmentEvent>[],
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
  final List<ShipmentEvent> events;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OrderShipment copyWith({
    String? id,
    ShipmentCarrier? carrier,
    String? service,
    String? trackingNumber,
    ShipmentStatus? status,
    DateTime? eta,
    String? labelUrl,
    List<String>? documents,
    List<ShipmentEvent>? events,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderShipment(
      id: id ?? this.id,
      carrier: carrier ?? this.carrier,
      service: service ?? this.service,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      status: status ?? this.status,
      eta: eta ?? this.eta,
      labelUrl: labelUrl ?? this.labelUrl,
      documents: documents ?? this.documents,
      events: events ?? this.events,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    const eventEq = ListEquality<ShipmentEvent>();
    return identical(this, other) ||
        (other is OrderShipment &&
            other.id == id &&
            other.carrier == carrier &&
            other.service == service &&
            other.trackingNumber == trackingNumber &&
            other.status == status &&
            other.eta == eta &&
            other.labelUrl == labelUrl &&
            listEq.equals(other.documents, documents) &&
            eventEq.equals(other.events, events) &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    carrier,
    service,
    trackingNumber,
    status,
    eta,
    labelUrl,
    const ListEquality<String>().hash(documents),
    const ListEquality<ShipmentEvent>().hash(events),
    createdAt,
    updatedAt,
  ]);
}

enum ProductionEventType {
  queued,
  engraving,
  polishing,
  qc,
  packed,
  onHold,
  rework,
  canceled,
}

extension ProductionEventTypeX on ProductionEventType {
  String toJson() => switch (this) {
    ProductionEventType.queued => 'queued',
    ProductionEventType.engraving => 'engraving',
    ProductionEventType.polishing => 'polishing',
    ProductionEventType.qc => 'qc',
    ProductionEventType.packed => 'packed',
    ProductionEventType.onHold => 'on_hold',
    ProductionEventType.rework => 'rework',
    ProductionEventType.canceled => 'canceled',
  };

  static ProductionEventType fromJson(String value) {
    switch (value) {
      case 'queued':
        return ProductionEventType.queued;
      case 'engraving':
        return ProductionEventType.engraving;
      case 'polishing':
        return ProductionEventType.polishing;
      case 'qc':
        return ProductionEventType.qc;
      case 'packed':
        return ProductionEventType.packed;
      case 'on_hold':
        return ProductionEventType.onHold;
      case 'rework':
        return ProductionEventType.rework;
      case 'canceled':
        return ProductionEventType.canceled;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported production event');
  }
}

class ProductionQcInfo {
  const ProductionQcInfo({this.result, this.defects = const <String>[]});

  final String? result;
  final List<String> defects;

  ProductionQcInfo copyWith({String? result, List<String>? defects}) {
    return ProductionQcInfo(
      result: result ?? this.result,
      defects: defects ?? this.defects,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is ProductionQcInfo &&
            other.result == result &&
            listEq.equals(other.defects, defects));
  }

  @override
  int get hashCode =>
      Object.hash(result, const ListEquality<String>().hash(defects));
}

class ProductionEvent {
  const ProductionEvent({
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
  final ProductionQcInfo? qc;

  ProductionEvent copyWith({
    ProductionEventType? type,
    DateTime? createdAt,
    String? station,
    String? operatorRef,
    int? durationSec,
    String? note,
    String? photoUrl,
    ProductionQcInfo? qc,
  }) {
    return ProductionEvent(
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      station: station ?? this.station,
      operatorRef: operatorRef ?? this.operatorRef,
      durationSec: durationSec ?? this.durationSec,
      note: note ?? this.note,
      photoUrl: photoUrl ?? this.photoUrl,
      qc: qc ?? this.qc,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ProductionEvent &&
            other.type == type &&
            other.createdAt == createdAt &&
            other.station == station &&
            other.operatorRef == operatorRef &&
            other.durationSec == durationSec &&
            other.note == note &&
            other.photoUrl == photoUrl &&
            other.qc == qc);
  }

  @override
  int get hashCode => Object.hash(
    type,
    createdAt,
    station,
    operatorRef,
    durationSec,
    note,
    photoUrl,
    qc,
  );
}

class Order {
  const Order({
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
    this.payments = const <OrderPayment>[],
    this.shipments = const <OrderShipment>[],
    this.productionEvents = const <ProductionEvent>[],
  });

  final String? id;
  final String orderNumber;
  final String userRef;
  final String? cartRef;
  final OrderStatus status;
  final String currency;
  final OrderTotals totals;
  final OrderPromotionSnapshot? promotion;
  final List<OrderLineItem> lineItems;
  final OrderAddress shippingAddress;
  final OrderAddress? billingAddress;
  final OrderContact? contact;
  final OrderFulfillment? fulfillment;
  final OrderProductionInfo? production;
  final Map<String, Object?>? notes;
  final OrderFlags? flags;
  final OrderAudit? audit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? placedAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? canceledAt;
  final String? cancelReason;
  final Map<String, Object?>? metadata;
  final List<OrderPayment> payments;
  final List<OrderShipment> shipments;
  final List<ProductionEvent> productionEvents;

  Order copyWith({
    String? id,
    String? orderNumber,
    String? userRef,
    String? cartRef,
    OrderStatus? status,
    String? currency,
    OrderTotals? totals,
    OrderPromotionSnapshot? promotion,
    List<OrderLineItem>? lineItems,
    OrderAddress? shippingAddress,
    OrderAddress? billingAddress,
    OrderContact? contact,
    OrderFulfillment? fulfillment,
    OrderProductionInfo? production,
    Map<String, Object?>? notes,
    OrderFlags? flags,
    OrderAudit? audit,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? placedAt,
    DateTime? paidAt,
    DateTime? shippedAt,
    DateTime? deliveredAt,
    DateTime? canceledAt,
    String? cancelReason,
    Map<String, Object?>? metadata,
    List<OrderPayment>? payments,
    List<OrderShipment>? shipments,
    List<ProductionEvent>? productionEvents,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      userRef: userRef ?? this.userRef,
      cartRef: cartRef ?? this.cartRef,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      totals: totals ?? this.totals,
      promotion: promotion ?? this.promotion,
      lineItems: lineItems ?? this.lineItems,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      billingAddress: billingAddress ?? this.billingAddress,
      contact: contact ?? this.contact,
      fulfillment: fulfillment ?? this.fulfillment,
      production: production ?? this.production,
      notes: notes ?? this.notes,
      flags: flags ?? this.flags,
      audit: audit ?? this.audit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      placedAt: placedAt ?? this.placedAt,
      paidAt: paidAt ?? this.paidAt,
      shippedAt: shippedAt ?? this.shippedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      canceledAt: canceledAt ?? this.canceledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      metadata: metadata ?? this.metadata,
      payments: payments ?? this.payments,
      shipments: shipments ?? this.shipments,
      productionEvents: productionEvents ?? this.productionEvents,
    );
  }

  @override
  bool operator ==(Object other) {
    const lineEq = ListEquality<OrderLineItem>();
    const paymentEq = ListEquality<OrderPayment>();
    const shipmentEq = ListEquality<OrderShipment>();
    const prodEq = ListEquality<ProductionEvent>();
    const deepEq = DeepCollectionEquality();
    return identical(this, other) ||
        (other is Order &&
            other.id == id &&
            other.orderNumber == orderNumber &&
            other.userRef == userRef &&
            other.cartRef == cartRef &&
            other.status == status &&
            other.currency == currency &&
            other.totals == totals &&
            other.promotion == promotion &&
            lineEq.equals(other.lineItems, lineItems) &&
            other.shippingAddress == shippingAddress &&
            other.billingAddress == billingAddress &&
            other.contact == contact &&
            other.fulfillment == fulfillment &&
            other.production == production &&
            deepEq.equals(other.notes, notes) &&
            other.flags == flags &&
            other.audit == audit &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.placedAt == placedAt &&
            other.paidAt == paidAt &&
            other.shippedAt == shippedAt &&
            other.deliveredAt == deliveredAt &&
            other.canceledAt == canceledAt &&
            other.cancelReason == cancelReason &&
            deepEq.equals(other.metadata, metadata) &&
            paymentEq.equals(other.payments, payments) &&
            shipmentEq.equals(other.shipments, shipments) &&
            prodEq.equals(other.productionEvents, productionEvents));
  }

  @override
  int get hashCode {
    const deepEq = DeepCollectionEquality();
    return Object.hashAll([
      id,
      orderNumber,
      userRef,
      cartRef,
      status,
      currency,
      totals,
      promotion,
      const ListEquality<OrderLineItem>().hash(lineItems),
      shippingAddress,
      billingAddress,
      contact,
      fulfillment,
      production,
      deepEq.hash(notes),
      flags,
      audit,
      createdAt,
      updatedAt,
      placedAt,
      paidAt,
      shippedAt,
      deliveredAt,
      canceledAt,
      cancelReason,
      deepEq.hash(metadata),
      const ListEquality<OrderPayment>().hash(payments),
      const ListEquality<OrderShipment>().hash(shipments),
      const ListEquality<ProductionEvent>().hash(productionEvents),
    ]);
  }
}
