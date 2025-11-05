import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/cart/domain/checkout_shipping_models.dart';
import 'package:flutter/foundation.dart';

const Object _promoErrorSentinel = Object();
const Object _shippingOptionSentinel = Object();

@immutable
class CartLine {
  const CartLine({
    required this.cache,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.optionChips,
    required this.addons,
    required this.unitPrice,
    required this.addonsTotal,
    required this.lineTotal,
    required this.currency,
    required this.estimatedLeadTime,
    required this.quantityWarning,
    this.lowStock = false,
  });

  final CartLineCache cache;
  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final List<String> optionChips;
  final List<CartAddon> addons;
  final double unitPrice;
  final double addonsTotal;
  final double lineTotal;
  final String currency;
  final String? estimatedLeadTime;
  final String? quantityWarning;
  final bool lowStock;

  String get id => cache.lineId;

  String get productId => cache.productId;

  int get quantity => cache.quantity;

  CartLine copyWith({
    CartLineCache? cache,
    String? title,
    String? subtitle,
    String? thumbnailUrl,
    List<String>? optionChips,
    List<CartAddon>? addons,
    double? unitPrice,
    double? addonsTotal,
    double? lineTotal,
    String? currency,
    String? estimatedLeadTime,
    String? quantityWarning,
    bool? lowStock,
  }) {
    return CartLine(
      cache: cache ?? this.cache,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      optionChips: optionChips ?? this.optionChips,
      addons: addons ?? this.addons,
      unitPrice: unitPrice ?? this.unitPrice,
      addonsTotal: addonsTotal ?? this.addonsTotal,
      lineTotal: lineTotal ?? this.lineTotal,
      currency: currency ?? this.currency,
      estimatedLeadTime: estimatedLeadTime ?? this.estimatedLeadTime,
      quantityWarning: quantityWarning ?? this.quantityWarning,
      lowStock: lowStock ?? this.lowStock,
    );
  }
}

@immutable
class CartAddon {
  const CartAddon({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    this.category,
  });

  final String id;
  final String name;
  final double price;
  final String currency;
  final String? category;
}

@immutable
class CartPromotion {
  const CartPromotion({
    required this.code,
    required this.summary,
    required this.savingsAmount,
    required this.currency,
    this.detail,
  });

  final String code;
  final String summary;
  final double savingsAmount;
  final String currency;
  final String? detail;
}

@immutable
class CartEstimate {
  const CartEstimate({
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.currency,
    required this.estimatedDelivery,
  });

  final double subtotal;
  final double discount;
  final double shipping;
  final double tax;
  final double total;
  final String currency;
  final String estimatedDelivery;
}

@immutable
class CartSnapshot {
  const CartSnapshot({
    required this.lines,
    required this.estimate,
    required this.currency,
    required this.experience,
    this.promotion,
    this.promoError,
    this.updatedAt,
    this.shippingOption,
  });

  final List<CartLine> lines;
  final CartEstimate estimate;
  final String currency;
  final ExperienceGate experience;
  final CartPromotion? promotion;
  final String? promoError;
  final DateTime? updatedAt;
  final CheckoutShippingOption? shippingOption;

  CartSnapshot copyWith({
    List<CartLine>? lines,
    CartEstimate? estimate,
    String? currency,
    ExperienceGate? experience,
    CartPromotion? promotion,
    Object? promoError = _promoErrorSentinel,
    DateTime? updatedAt,
    Object? shippingOption = _shippingOptionSentinel,
  }) {
    return CartSnapshot(
      lines: lines ?? this.lines,
      estimate: estimate ?? this.estimate,
      currency: currency ?? this.currency,
      experience: experience ?? this.experience,
      promotion: promotion ?? this.promotion,
      promoError: identical(promoError, _promoErrorSentinel)
          ? this.promoError
          : promoError as String?,
      updatedAt: updatedAt ?? this.updatedAt,
      shippingOption: identical(shippingOption, _shippingOptionSentinel)
          ? this.shippingOption
          : shippingOption as CheckoutShippingOption?,
    );
  }
}
