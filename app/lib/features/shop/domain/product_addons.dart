import 'package:app/core/domain/entities/catalog.dart';
import 'package:flutter/foundation.dart';

/// オプションアクセサリのカテゴリ
enum ProductAddonCategory { caseAccessory, storageBox, ink }

@immutable
class ProductAddon {
  const ProductAddon({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.badge,
    this.isRecommended = false,
    this.isDefaultSelected = false,
  });

  final String id;
  final String name;
  final String description;
  final ProductAddonCategory category;
  final CatalogMoney price;
  final String imageUrl;
  final String? badge;
  final bool isRecommended;
  final bool isDefaultSelected;
}

@immutable
class ProductAddonGroup {
  ProductAddonGroup({
    required this.category,
    required this.displayLabel,
    required List<ProductAddon> addons,
    this.helperText,
  }) : addons = List.unmodifiable(addons);

  final ProductAddonCategory category;
  final String displayLabel;
  final String? helperText;
  final List<ProductAddon> addons;
}

@immutable
class ProductAddonRecommendation {
  ProductAddonRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required List<String> addonIds,
    required this.estimatedTotal,
    this.badge,
  }) : addonIds = List.unmodifiable(addonIds);

  final String id;
  final String title;
  final String description;
  final List<String> addonIds;
  final CatalogMoney estimatedTotal;
  final String? badge;
}

@immutable
class ProductAddons {
  ProductAddons({
    required this.productId,
    required List<ProductAddonGroup> groups,
    required List<ProductAddonRecommendation> recommendations,
  }) : groups = List.unmodifiable(groups),
       recommendations = List.unmodifiable(recommendations);

  final String productId;
  final List<ProductAddonGroup> groups;
  final List<ProductAddonRecommendation> recommendations;

  List<ProductAddon> get allAddons =>
      groups.expand((group) => group.addons).toList(growable: false);
}
