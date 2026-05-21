import '../../../core/domain/money.dart';

class StoneListingsQuery {
  const StoneListingsQuery({
    this.locale,
    this.materialKey,
    this.colorFamily,
    this.patternPrimary,
    this.stoneShape,
    this.status,
  });

  final String? locale;
  final String? materialKey;
  final String? colorFamily;
  final String? patternPrimary;
  final String? stoneShape;
  final String? status;
}

class StoneListingsResult {
  const StoneListingsResult({
    required this.locale,
    required this.currency,
    required this.listings,
  });

  final String locale;
  final String currency;
  final List<StoneListing> listings;
}

class StoneListing {
  const StoneListing({
    required this.id,
    required this.code,
    required this.materialKey,
    required this.sizeLabel,
    required this.title,
    required this.description,
    required this.story,
    required this.facets,
    required this.price,
    required this.status,
    required this.isActive,
    required this.photos,
  });

  final String id;
  final String code;
  final String materialKey;
  final String sizeLabel;
  final String title;
  final String description;
  final String story;
  final StoneListingFacets facets;
  final Money price;
  final String status;
  final bool isActive;
  final List<StoneListingPhoto> photos;

  bool get isOrderable => isActive && status == 'published';
}

class StoneListingFacets {
  const StoneListingFacets({
    required this.colorFamily,
    required this.colorTags,
    required this.patternPrimary,
    required this.patternTags,
    required this.stoneShape,
    required this.translucency,
  });

  final String colorFamily;
  final List<String> colorTags;
  final String patternPrimary;
  final List<String> patternTags;
  final String stoneShape;
  final String translucency;
}

class StoneListingPhoto {
  const StoneListingPhoto({
    required this.assetId,
    required this.assetUrl,
    required this.alt,
    required this.isPrimary,
    required this.sortOrder,
    this.width,
    this.height,
  });

  final String assetId;
  final String assetUrl;
  final String alt;
  final bool isPrimary;
  final int sortOrder;
  final int? width;
  final int? height;
}
