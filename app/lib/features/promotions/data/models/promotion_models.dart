// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:collection/collection.dart';

enum PromotionKind { percent, fixed }

extension PromotionKindX on PromotionKind {
  String toJson() => switch (this) {
    PromotionKind.percent => 'percent',
    PromotionKind.fixed => 'fixed',
  };

  static PromotionKind fromJson(String value) {
    switch (value) {
      case 'percent':
        return PromotionKind.percent;
      case 'fixed':
        return PromotionKind.fixed;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported promotion kind');
  }
}

class PromotionStacking {
  const PromotionStacking({this.combinable, this.withSalePrice, this.maxStack});

  final bool? combinable;
  final bool? withSalePrice;
  final int? maxStack;

  PromotionStacking copyWith({
    bool? combinable,
    bool? withSalePrice,
    int? maxStack,
  }) {
    return PromotionStacking(
      combinable: combinable ?? this.combinable,
      withSalePrice: withSalePrice ?? this.withSalePrice,
      maxStack: maxStack ?? this.maxStack,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PromotionStacking &&
            other.combinable == combinable &&
            other.withSalePrice == withSalePrice &&
            other.maxStack == maxStack);
  }

  @override
  int get hashCode => Object.hash(combinable, withSalePrice, maxStack);
}

class PromotionSizeConstraint {
  const PromotionSizeConstraint({this.min, this.max});

  final double? min;
  final double? max;

  PromotionSizeConstraint copyWith({double? min, double? max}) {
    return PromotionSizeConstraint(min: min ?? this.min, max: max ?? this.max);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PromotionSizeConstraint &&
            other.min == min &&
            other.max == max);
  }

  @override
  int get hashCode => Object.hash(min, max);
}

class PromotionConditions {
  const PromotionConditions({
    this.minSubtotal,
    this.countryIn = const <String>[],
    this.currencyIn = const <String>[],
    this.shapeIn = const <SealShape>[],
    this.sizeMmBetween,
    this.productRefsIn = const <String>[],
    this.materialRefsIn = const <String>[],
    this.newCustomerOnly,
  });

  final int? minSubtotal;
  final List<String> countryIn;
  final List<String> currencyIn;
  final List<SealShape> shapeIn;
  final PromotionSizeConstraint? sizeMmBetween;
  final List<String> productRefsIn;
  final List<String> materialRefsIn;
  final bool? newCustomerOnly;

  PromotionConditions copyWith({
    int? minSubtotal,
    List<String>? countryIn,
    List<String>? currencyIn,
    List<SealShape>? shapeIn,
    PromotionSizeConstraint? sizeMmBetween,
    List<String>? productRefsIn,
    List<String>? materialRefsIn,
    bool? newCustomerOnly,
  }) {
    return PromotionConditions(
      minSubtotal: minSubtotal ?? this.minSubtotal,
      countryIn: countryIn ?? this.countryIn,
      currencyIn: currencyIn ?? this.currencyIn,
      shapeIn: shapeIn ?? this.shapeIn,
      sizeMmBetween: sizeMmBetween ?? this.sizeMmBetween,
      productRefsIn: productRefsIn ?? this.productRefsIn,
      materialRefsIn: materialRefsIn ?? this.materialRefsIn,
      newCustomerOnly: newCustomerOnly ?? this.newCustomerOnly,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is PromotionConditions &&
            other.minSubtotal == minSubtotal &&
            listEq.equals(other.countryIn, countryIn) &&
            listEq.equals(other.currencyIn, currencyIn) &&
            const ListEquality<SealShape>().equals(other.shapeIn, shapeIn) &&
            other.sizeMmBetween == sizeMmBetween &&
            listEq.equals(other.productRefsIn, productRefsIn) &&
            listEq.equals(other.materialRefsIn, materialRefsIn) &&
            other.newCustomerOnly == newCustomerOnly);
  }

  @override
  int get hashCode => Object.hashAll([
    minSubtotal,
    const ListEquality<String>().hash(countryIn),
    const ListEquality<String>().hash(currencyIn),
    const ListEquality<SealShape>().hash(shapeIn),
    sizeMmBetween,
    const ListEquality<String>().hash(productRefsIn),
    const ListEquality<String>().hash(materialRefsIn),
    newCustomerOnly,
  ]);
}

class Promotion {
  const Promotion({
    required this.code,
    required this.kind,
    required this.value,
    required this.isActive,
    required this.startsAt,
    required this.endsAt,
    required this.usageLimit,
    required this.usageCount,
    required this.limitPerUser,
    this.id,
    this.name,
    this.currency,
    this.stacking,
    this.conditions,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String code;
  final String? name;
  final PromotionKind kind;
  final num value;
  final String? currency;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
  final PromotionStacking? stacking;
  final PromotionConditions? conditions;
  final int usageLimit;
  final int usageCount;
  final int limitPerUser;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Promotion copyWith({
    String? id,
    String? code,
    String? name,
    PromotionKind? kind,
    num? value,
    String? currency,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? isActive,
    PromotionStacking? stacking,
    PromotionConditions? conditions,
    int? usageLimit,
    int? usageCount,
    int? limitPerUser,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Promotion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      currency: currency ?? this.currency,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      isActive: isActive ?? this.isActive,
      stacking: stacking ?? this.stacking,
      conditions: conditions ?? this.conditions,
      usageLimit: usageLimit ?? this.usageLimit,
      usageCount: usageCount ?? this.usageCount,
      limitPerUser: limitPerUser ?? this.limitPerUser,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Promotion &&
            other.id == id &&
            other.code == code &&
            other.name == name &&
            other.kind == kind &&
            other.value == value &&
            other.currency == currency &&
            other.startsAt == startsAt &&
            other.endsAt == endsAt &&
            other.isActive == isActive &&
            other.stacking == stacking &&
            other.conditions == conditions &&
            other.usageLimit == usageLimit &&
            other.usageCount == usageCount &&
            other.limitPerUser == limitPerUser &&
            other.notes == notes &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    code,
    name,
    kind,
    value,
    currency,
    startsAt,
    endsAt,
    isActive,
    stacking,
    conditions,
    usageLimit,
    usageCount,
    limitPerUser,
    notes,
    createdAt,
    updatedAt,
  ]);
}

class PromotionValidationResult {
  const PromotionValidationResult({
    required this.code,
    required this.isValid,
    this.reason,
    this.discountAmount,
    this.currency,
  });

  final String code;
  final bool isValid;
  final String? reason;
  final int? discountAmount;
  final String? currency;

  PromotionValidationResult copyWith({
    String? code,
    bool? isValid,
    String? reason,
    int? discountAmount,
    String? currency,
  }) {
    return PromotionValidationResult(
      code: code ?? this.code,
      isValid: isValid ?? this.isValid,
      reason: reason ?? this.reason,
      discountAmount: discountAmount ?? this.discountAmount,
      currency: currency ?? this.currency,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PromotionValidationResult &&
            other.code == code &&
            other.isValid == isValid &&
            other.reason == reason &&
            other.discountAmount == discountAmount &&
            other.currency == currency);
  }

  @override
  int get hashCode =>
      Object.hash(code, isValid, reason, discountAmount, currency);
}
