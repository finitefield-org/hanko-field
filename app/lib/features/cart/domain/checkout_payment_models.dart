import 'package:app/core/domain/entities/user.dart';
import 'package:flutter/foundation.dart';

@immutable
class CheckoutPaymentMethodSummary {
  const CheckoutPaymentMethodSummary({
    required this.id,
    required this.provider,
    required this.methodType,
    required this.tokenStorageKey,
    required this.createdAt,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.billingName,
    this.updatedAt,
  });

  final String id;
  final PaymentProvider provider;
  final PaymentMethodType methodType;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final String? billingName;
  final String tokenStorageKey;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get hasExpiry => expMonth != null && expYear != null;

  bool get isExpired {
    if (!hasExpiry) {
      return false;
    }
    final normalizedExpiry = DateTime(expYear!, expMonth!, 1);
    final now = DateTime.now();
    final normalizedNow = DateTime(now.year, now.month, 1);
    return normalizedExpiry.isBefore(normalizedNow);
  }

  CheckoutPaymentMethodSummary copyWith({
    String? id,
    PaymentProvider? provider,
    PaymentMethodType? methodType,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
    String? billingName,
    String? tokenStorageKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CheckoutPaymentMethodSummary(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      methodType: methodType ?? this.methodType,
      brand: brand ?? this.brand,
      last4: last4 ?? this.last4,
      expMonth: expMonth ?? this.expMonth,
      expYear: expYear ?? this.expYear,
      billingName: billingName ?? this.billingName,
      tokenStorageKey: tokenStorageKey ?? this.tokenStorageKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    provider,
    methodType,
    brand,
    last4,
    expMonth,
    expYear,
    billingName,
    tokenStorageKey,
    createdAt,
    updatedAt,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CheckoutPaymentMethodSummary &&
        other.id == id &&
        other.provider == provider &&
        other.methodType == methodType &&
        other.brand == brand &&
        other.last4 == last4 &&
        other.expMonth == expMonth &&
        other.expYear == expYear &&
        other.billingName == billingName &&
        other.tokenStorageKey == tokenStorageKey &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }
}
