// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/core/utils/json_utils.dart';
import 'package:app/features/promotions/data/models/promotion_models.dart';

class PromotionStackingDto {
  const PromotionStackingDto({
    this.combinable,
    this.withSalePrice,
    this.maxStack,
  });

  final bool? combinable;
  final bool? withSalePrice;
  final int? maxStack;

  factory PromotionStackingDto.fromJson(Map<String, Object?> json) {
    return PromotionStackingDto(
      combinable: json['combinable'] as bool?,
      withSalePrice: json['withSalePrice'] as bool?,
      maxStack: (json['maxStack'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'combinable': combinable,
    'withSalePrice': withSalePrice,
    'maxStack': maxStack,
  };

  PromotionStacking toDomain() {
    return PromotionStacking(
      combinable: combinable,
      withSalePrice: withSalePrice,
      maxStack: maxStack,
    );
  }

  static PromotionStackingDto fromDomain(PromotionStacking stacking) {
    return PromotionStackingDto(
      combinable: stacking.combinable,
      withSalePrice: stacking.withSalePrice,
      maxStack: stacking.maxStack,
    );
  }
}

class PromotionSizeConstraintDto {
  const PromotionSizeConstraintDto({this.min, this.max});

  final double? min;
  final double? max;

  factory PromotionSizeConstraintDto.fromJson(Map<String, Object?> json) {
    return PromotionSizeConstraintDto(
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{'min': min, 'max': max};

  PromotionSizeConstraint toDomain() =>
      PromotionSizeConstraint(min: min, max: max);

  static PromotionSizeConstraintDto fromDomain(
    PromotionSizeConstraint constraint,
  ) {
    return PromotionSizeConstraintDto(min: constraint.min, max: constraint.max);
  }
}

class PromotionConditionsDto {
  const PromotionConditionsDto({
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
  final PromotionSizeConstraintDto? sizeMmBetween;
  final List<String> productRefsIn;
  final List<String> materialRefsIn;
  final bool? newCustomerOnly;

  factory PromotionConditionsDto.fromJson(Map<String, Object?> json) {
    return PromotionConditionsDto(
      minSubtotal: (json['minSubtotal'] as num?)?.toInt(),
      countryIn:
          (json['countryIn'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      currencyIn:
          (json['currencyIn'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      shapeIn:
          (json['shapeIn'] as List?)
              ?.map((e) => SealShapeX.fromJson(e.toString()))
              .toList() ??
          const <SealShape>[],
      sizeMmBetween: json['sizeMmBetween'] != null
          ? PromotionSizeConstraintDto.fromJson(
              Map<String, Object?>.from(json['sizeMmBetween'] as Map),
            )
          : null,
      productRefsIn:
          (json['productRefsIn'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      materialRefsIn:
          (json['materialRefsIn'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      newCustomerOnly: json['newCustomerOnly'] as bool?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'minSubtotal': minSubtotal,
    'countryIn': countryIn,
    'currencyIn': currencyIn,
    'shapeIn': shapeIn.map((e) => e.toJson()).toList(),
    'sizeMmBetween': sizeMmBetween?.toJson(),
    'productRefsIn': productRefsIn,
    'materialRefsIn': materialRefsIn,
    'newCustomerOnly': newCustomerOnly,
  };

  PromotionConditions toDomain() {
    return PromotionConditions(
      minSubtotal: minSubtotal,
      countryIn: countryIn,
      currencyIn: currencyIn,
      shapeIn: shapeIn,
      sizeMmBetween: sizeMmBetween?.toDomain(),
      productRefsIn: productRefsIn,
      materialRefsIn: materialRefsIn,
      newCustomerOnly: newCustomerOnly,
    );
  }

  static PromotionConditionsDto fromDomain(PromotionConditions conditions) {
    return PromotionConditionsDto(
      minSubtotal: conditions.minSubtotal,
      countryIn: conditions.countryIn,
      currencyIn: conditions.currencyIn,
      shapeIn: conditions.shapeIn,
      sizeMmBetween: conditions.sizeMmBetween != null
          ? PromotionSizeConstraintDto.fromDomain(conditions.sizeMmBetween!)
          : null,
      productRefsIn: conditions.productRefsIn,
      materialRefsIn: conditions.materialRefsIn,
      newCustomerOnly: conditions.newCustomerOnly,
    );
  }
}

class PromotionDto {
  const PromotionDto({
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
  final PromotionStackingDto? stacking;
  final PromotionConditionsDto? conditions;
  final int usageLimit;
  final int usageCount;
  final int limitPerUser;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PromotionDto.fromJson(Map<String, Object?> json, {String? id}) {
    return PromotionDto(
      id: id,
      code: json['code'] as String,
      name: json['name'] as String?,
      kind: PromotionKindX.fromJson(json['kind'] as String),
      value: json['value'] as num,
      currency: json['currency'] as String?,
      startsAt:
          parseDateTime(json['startsAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endsAt:
          parseDateTime(json['endsAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isActive: json['isActive'] as bool? ?? false,
      stacking: json['stacking'] != null
          ? PromotionStackingDto.fromJson(
              Map<String, Object?>.from(json['stacking'] as Map),
            )
          : null,
      conditions: json['conditions'] != null
          ? PromotionConditionsDto.fromJson(
              Map<String, Object?>.from(json['conditions'] as Map),
            )
          : null,
      usageLimit: (json['usageLimit'] as num).toInt(),
      usageCount: (json['usageCount'] as num).toInt(),
      limitPerUser: (json['limitPerUser'] as num).toInt(),
      notes: json['notes'] as String?,
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'name': name,
    'kind': kind.toJson(),
    'value': value,
    'currency': currency,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'isActive': isActive,
    'stacking': stacking?.toJson(),
    'conditions': conditions?.toJson(),
    'usageLimit': usageLimit,
    'usageCount': usageCount,
    'limitPerUser': limitPerUser,
    'notes': notes,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Promotion toDomain() {
    return Promotion(
      id: id,
      code: code,
      name: name,
      kind: kind,
      value: value,
      currency: currency,
      startsAt: startsAt,
      endsAt: endsAt,
      isActive: isActive,
      stacking: stacking?.toDomain(),
      conditions: conditions?.toDomain(),
      usageLimit: usageLimit,
      usageCount: usageCount,
      limitPerUser: limitPerUser,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static PromotionDto fromDomain(Promotion promotion) {
    return PromotionDto(
      id: promotion.id,
      code: promotion.code,
      name: promotion.name,
      kind: promotion.kind,
      value: promotion.value,
      currency: promotion.currency,
      startsAt: promotion.startsAt,
      endsAt: promotion.endsAt,
      isActive: promotion.isActive,
      stacking: promotion.stacking != null
          ? PromotionStackingDto.fromDomain(promotion.stacking!)
          : null,
      conditions: promotion.conditions != null
          ? PromotionConditionsDto.fromDomain(promotion.conditions!)
          : null,
      usageLimit: promotion.usageLimit,
      usageCount: promotion.usageCount,
      limitPerUser: promotion.limitPerUser,
      notes: promotion.notes,
      createdAt: promotion.createdAt,
      updatedAt: promotion.updatedAt,
    );
  }
}

class PromotionValidationResultDto {
  const PromotionValidationResultDto({
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

  factory PromotionValidationResultDto.fromJson(Map<String, Object?> json) {
    return PromotionValidationResultDto(
      code: json['code'] as String,
      isValid: json['isValid'] as bool? ?? false,
      reason: json['reason'] as String?,
      discountAmount: (json['discountAmount'] as num?)?.toInt(),
      currency: json['currency'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'isValid': isValid,
    'reason': reason,
    'discountAmount': discountAmount,
    'currency': currency,
  };

  PromotionValidationResult toDomain() {
    return PromotionValidationResult(
      code: code,
      isValid: isValid,
      reason: reason,
      discountAmount: discountAmount,
      currency: currency,
    );
  }

  static PromotionValidationResultDto fromDomain(
    PromotionValidationResult result,
  ) {
    return PromotionValidationResultDto(
      code: result.code,
      isValid: result.isValid,
      reason: result.reason,
      discountAmount: result.discountAmount,
      currency: result.currency,
    );
  }
}
