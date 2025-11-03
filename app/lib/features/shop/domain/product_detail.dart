import 'package:app/core/domain/entities/catalog.dart';
import 'package:flutter/foundation.dart';

@immutable
class ProductDetail {
  ProductDetail({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.baseProduct,
    required List<String> badges,
    required List<String> highlights,
    required List<ProductSpec> specs,
    required List<ProductVariantGroup> variantGroups,
    required List<ProductVariant> variants,
    required List<String> includedItems,
    this.careNote,
    this.shippingNote,
    this.requiresDesignSelection = false,
  }) : badges = List.unmodifiable(badges),
       highlights = List.unmodifiable(highlights),
       specs = List.unmodifiable(specs),
       variantGroups = List.unmodifiable(variantGroups),
       variants = List.unmodifiable(variants),
       includedItems = List.unmodifiable(includedItems);

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final CatalogProduct baseProduct;
  final List<String> badges;
  final List<String> highlights;
  final List<ProductSpec> specs;
  final List<ProductVariantGroup> variantGroups;
  final List<ProductVariant> variants;
  final List<String> includedItems;
  final String? careNote;
  final String? shippingNote;
  final bool requiresDesignSelection;

  ProductVariant? findVariantByOptions(Map<String, String> selections) {
    for (final variant in variants) {
      if (mapEquals(variant.optionSelections, selections) ||
          _matchesAllSelections(variant.optionSelections, selections)) {
        return variant;
      }
    }
    return null;
  }

  bool _matchesAllSelections(
    Map<String, String> variantSelections,
    Map<String, String> selections,
  ) {
    for (final entry in selections.entries) {
      final value = variantSelections[entry.key];
      if (value == null || value != entry.value) {
        return false;
      }
    }
    return true;
  }
}

@immutable
class ProductSpec {
  const ProductSpec({
    required this.label,
    required this.value,
    this.detail,
    this.iconName,
  });

  final String label;
  final String value;
  final String? detail;
  final String? iconName;
}

enum ProductVariantSelectionType { segmented, chip }

@immutable
class ProductVariantGroup {
  ProductVariantGroup({
    required this.id,
    required this.label,
    required List<ProductVariantOption> options,
    this.selectionType = ProductVariantSelectionType.segmented,
  }) : options = List.unmodifiable(options);

  final String id;
  final String label;
  final List<ProductVariantOption> options;
  final ProductVariantSelectionType selectionType;
}

@immutable
class ProductVariantOption {
  const ProductVariantOption({
    required this.id,
    required this.label,
    this.helperText,
  });

  final String id;
  final String label;
  final String? helperText;
}

enum ProductStockLevel { inStock, limited, backorder, preorder }

@immutable
class ProductStockStatus {
  const ProductStockStatus({
    required this.level,
    required this.label,
    this.detail,
    this.quantity,
  });

  final ProductStockLevel level;
  final String label;
  final String? detail;
  final int? quantity;
}

@immutable
class ProductPriceTier {
  const ProductPriceTier({
    required this.minQuantity,
    this.maxQuantity,
    required this.price,
    this.savingsLabel,
    this.note,
  });

  final int minQuantity;
  final int? maxQuantity;
  final CatalogMoney price;
  final String? savingsLabel;
  final String? note;
}

@immutable
class ProductVariant {
  ProductVariant({
    required this.id,
    required this.optionSelections,
    required this.displayLabel,
    required this.primaryImageUrl,
    required List<String> galleryImages,
    required this.price,
    required List<ProductPriceTier> pricingTiers,
    required this.stock,
    required this.leadTime,
    this.salePrice,
  }) : galleryImages = List.unmodifiable(galleryImages),
       pricingTiers = List.unmodifiable(pricingTiers);

  final String id;
  final Map<String, String> optionSelections;
  final String displayLabel;
  final String primaryImageUrl;
  final List<String> galleryImages;
  final CatalogMoney price;
  final CatalogSalePrice? salePrice;
  final List<ProductPriceTier> pricingTiers;
  final ProductStockStatus stock;
  final String leadTime;

  bool matchesSelections(Map<String, String> selections) {
    for (final entry in selections.entries) {
      final expected = optionSelections[entry.key];
      if (expected == null || expected != entry.value) {
        return false;
      }
    }
    return true;
  }
}
