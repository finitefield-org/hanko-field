import '../../../core/api/core_api.dart';
import '../../../core/domain/money.dart';
import '../domain/stone_listing.dart';

typedef StoneListingsLoader =
    Future<StoneListingsResult> Function(StoneListingsQuery query);

final _defaultStoneListingsRepository = StoneListingsRepository(
  HankoApiClient(baseUri: Uri.parse(defaultHankoApiBaseUrl)),
);

Future<StoneListingsResult> listStoneListingsWithDefaultApi(
  StoneListingsQuery query,
) {
  return _defaultStoneListingsRepository.listStoneListings(query);
}

class StoneListingsRepository {
  const StoneListingsRepository(this._apiClient);

  final HankoApiClient _apiClient;

  Future<StoneListingsResult> listStoneListings([
    StoneListingsQuery query = const StoneListingsQuery(),
  ]) async {
    final json = await _apiClient.getJson(
      '/v1/stone-listings',
      queryParameters: {
        'locale': query.locale,
        'material_key': query.materialKey,
        'color_family': query.colorFamily,
        'pattern_primary': query.patternPrimary,
        'stone_shape': query.stoneShape,
        'status': query.status,
      },
    );
    return StoneListingsResponseDto.fromJson(json).toDomain();
  }
}

class StoneListingsResponseDto {
  const StoneListingsResponseDto({
    required this.locale,
    required this.currency,
    required this.listings,
  });

  factory StoneListingsResponseDto.fromJson(JsonMap json) {
    return StoneListingsResponseDto(
      locale: readString(json, 'locale'),
      currency: readString(json, 'currency'),
      listings: readJsonList(json, 'stone_listings')
          .map(
            (value) =>
                StoneListingDto.fromJson(asJsonMap(value, 'stone listing')),
          )
          .toList(growable: false),
    );
  }

  final String locale;
  final String currency;
  final List<StoneListingDto> listings;

  StoneListingsResult toDomain() {
    return StoneListingsResult(
      locale: locale,
      currency: currency,
      listings: listings
          .map((listing) => listing.toDomain(defaultCurrency: currency))
          .toList(growable: false),
    );
  }
}

class StoneListingDto {
  const StoneListingDto({
    required this.id,
    required this.code,
    required this.materialKey,
    required this.materialLabel,
    required this.size,
    required this.title,
    required this.description,
    required this.story,
    required this.facets,
    required this.price,
    required this.status,
    required this.isActive,
    required this.isOrderable,
    required this.photos,
  });

  factory StoneListingDto.fromJson(JsonMap json) {
    final materialKey = readString(json, 'material_key');
    return StoneListingDto(
      id: readString(json, 'key', fallbackKey: 'id'),
      code: readString(json, 'listing_code', fallbackKey: 'code'),
      materialKey: materialKey,
      materialLabel: readString(
        json,
        'material_label',
        defaultValue: materialKey,
      ),
      size: _readSizeLabel(json['size']),
      title: readString(json, 'title'),
      description: readString(json, 'description'),
      story: readString(json, 'story'),
      facets: StoneListingFacetsDto.fromJson(
        asJsonMap(json['facets'], 'stone listing facets'),
      ),
      price: json['price'],
      status: readString(json, 'status'),
      isActive: readBool(json, 'is_active', defaultValue: true),
      isOrderable: json.containsKey('is_orderable')
          ? readBool(json, 'is_orderable')
          : null,
      photos: readJsonList(json, 'photos')
          .map(
            (value) => StoneListingPhotoDto.fromJson(
              asJsonMap(value, 'stone listing photo'),
            ),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String code;
  final String materialKey;
  final String materialLabel;
  final String size;
  final String title;
  final String description;
  final String story;
  final StoneListingFacetsDto facets;
  final Object? price;
  final String status;
  final bool isActive;
  final bool? isOrderable;
  final List<StoneListingPhotoDto> photos;

  StoneListing toDomain({required String defaultCurrency}) {
    return StoneListing(
      id: id,
      code: code,
      materialKey: materialKey,
      materialLabel: materialLabel,
      sizeLabel: size,
      title: title,
      description: description,
      story: story,
      facets: facets.toDomain(),
      price: _readMoney(price, defaultCurrency),
      status: status,
      isActive: isActive,
      isOrderable: isOrderable,
      photos: photos.map((photo) => photo.toDomain()).toList(growable: false),
    );
  }

  static String _readSizeLabel(Object? value) {
    if (value is String) {
      return value;
    }
    if (value is Map) {
      final json = asJsonMap(value, 'stone listing size');
      final width = readInt(json, 'width_mm');
      final height = readInt(json, 'height_mm');
      final depth = readInt(json, 'depth_mm');
      return '${width}x${height}x$depth mm';
    }
    if (value == null) {
      return '';
    }
    throw const FormatException('size must be a string or JSON object');
  }

  static Money _readMoney(Object? value, String defaultCurrency) {
    if (value is int) {
      return Money(amount: value, currency: defaultCurrency);
    }
    if (value is num) {
      return Money(amount: value.toInt(), currency: defaultCurrency);
    }
    if (value is Map) {
      final json = asJsonMap(value, 'stone listing price');
      return Money(
        amount: readInt(json, 'amount'),
        currency: readString(json, 'currency', defaultValue: defaultCurrency),
        display: readOptionalString(json, 'display'),
      );
    }
    throw const FormatException('price must be a number or JSON object');
  }
}

class StoneListingFacetsDto {
  const StoneListingFacetsDto({
    required this.colorFamily,
    required this.colorTags,
    required this.patternPrimary,
    required this.patternTags,
    required this.stoneShape,
    required this.translucency,
  });

  factory StoneListingFacetsDto.fromJson(JsonMap json) {
    return StoneListingFacetsDto(
      colorFamily: readString(json, 'color_family'),
      colorTags: readStringList(json, 'color_tags'),
      patternPrimary: readString(json, 'pattern_primary'),
      patternTags: readStringList(json, 'pattern_tags'),
      stoneShape: readString(json, 'stone_shape'),
      translucency: readString(json, 'translucency'),
    );
  }

  final String colorFamily;
  final List<String> colorTags;
  final String patternPrimary;
  final List<String> patternTags;
  final String stoneShape;
  final String translucency;

  StoneListingFacets toDomain() {
    return StoneListingFacets(
      colorFamily: colorFamily,
      colorTags: colorTags,
      patternPrimary: patternPrimary,
      patternTags: patternTags,
      stoneShape: stoneShape,
      translucency: translucency,
    );
  }
}

class StoneListingPhotoDto {
  const StoneListingPhotoDto({
    required this.assetId,
    required this.assetUrl,
    required this.alt,
    required this.isPrimary,
    required this.sortOrder,
    this.width,
    this.height,
  });

  factory StoneListingPhotoDto.fromJson(JsonMap json) {
    return StoneListingPhotoDto(
      assetId: readString(json, 'asset_id'),
      assetUrl: readString(json, 'asset_url'),
      alt: readString(json, 'alt'),
      isPrimary: readBool(json, 'is_primary'),
      sortOrder: readInt(json, 'sort_order'),
      width: json['width'] == null ? null : readInt(json, 'width'),
      height: json['height'] == null ? null : readInt(json, 'height'),
    );
  }

  final String assetId;
  final String assetUrl;
  final String alt;
  final bool isPrimary;
  final int sortOrder;
  final int? width;
  final int? height;

  StoneListingPhoto toDomain() {
    return StoneListingPhoto(
      assetId: assetId,
      assetUrl: assetUrl,
      alt: alt,
      isPrimary: isPrimary,
      sortOrder: sortOrder,
      width: width,
      height: height,
    );
  }
}
