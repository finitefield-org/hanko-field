import 'dart:collection';

import 'package:flutter/foundation.dart';

enum CheckoutShippingRegion { domestic, international }

enum CheckoutShippingSpeed { economy, standard, express }

enum CheckoutShippingAdvisoryLevel { info, warning }

@immutable
class CheckoutShippingOption {
  CheckoutShippingOption({
    required this.id,
    required this.label,
    required this.summary,
    required this.estimatedDelivery,
    required this.price,
    required this.currency,
    required this.region,
    required this.speed,
    List<String> perks = const <String>[],
    this.carrier,
    this.badge,
    this.isRecommended = false,
  }) : perks = UnmodifiableListView<String>(perks);

  final String id;
  final String label;
  final String summary;
  final String estimatedDelivery;
  final double price;
  final String currency;
  final CheckoutShippingRegion region;
  final CheckoutShippingSpeed speed;
  final UnmodifiableListView<String> perks;
  final String? carrier;
  final String? badge;
  final bool isRecommended;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    summary,
    estimatedDelivery,
    price,
    currency,
    region,
    speed,
    Object.hashAll(perks),
    carrier,
    badge,
    isRecommended,
  );

  @override
  bool operator ==(Object other) {
    return other is CheckoutShippingOption &&
        other.id == id &&
        other.label == label &&
        other.summary == summary &&
        other.estimatedDelivery == estimatedDelivery &&
        other.price == price &&
        other.currency == currency &&
        other.region == region &&
        other.speed == speed &&
        listEquals(other.perks, perks) &&
        other.carrier == carrier &&
        other.badge == badge &&
        other.isRecommended == isRecommended;
  }
}

@immutable
class CheckoutShippingAdvisory {
  const CheckoutShippingAdvisory({
    required this.title,
    required this.message,
    this.level = CheckoutShippingAdvisoryLevel.info,
  });

  final String title;
  final String message;
  final CheckoutShippingAdvisoryLevel level;
}

@immutable
class CheckoutShippingOptionsData {
  CheckoutShippingOptionsData({
    required List<CheckoutShippingOption> options,
    this.selectedOptionId,
    this.advisory,
  }) : options = UnmodifiableListView<CheckoutShippingOption>(options);

  final UnmodifiableListView<CheckoutShippingOption> options;
  final String? selectedOptionId;
  final CheckoutShippingAdvisory? advisory;

  CheckoutShippingOption? get selectedOption {
    for (final option in options) {
      if (option.id == selectedOptionId) {
        return option;
      }
    }
    return null;
  }

  bool get hasOptions => options.isNotEmpty;
}
