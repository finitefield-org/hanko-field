import '../../../core/api/core_api.dart';
import '../domain/seal_generation.dart';

final _defaultSealGenerationRepository = SealGenerationRepository(
  HankoApiClient(baseUri: Uri.parse(defaultHankoApiBaseUrl)),
);

Future<SealGenerationResult> generateSealDesignsWithDefaultApi(
  SealGenerationRequest request,
) {
  return _defaultSealGenerationRepository.generateSealDesigns(request);
}

class SealGenerationRepository {
  const SealGenerationRepository(this._apiClient);

  final HankoApiClient _apiClient;

  Future<SealGenerationResult> generateSealDesigns(
    SealGenerationRequest request,
  ) async {
    final json = await _apiClient.postJson(
      '/v1/seal-designs/generate',
      SealGenerationRequestDto.fromDomain(request).toJson(),
    );
    return SealGenerationResponseDto.fromJson(json).toDomain(request);
  }
}

class SealGenerationRequestDto {
  const SealGenerationRequestDto({
    required this.inputName,
    required this.kanji,
    required this.shape,
    required this.style,
    required this.strokeWeight,
    required this.balance,
    required this.variantCount,
  });

  factory SealGenerationRequestDto.fromDomain(SealGenerationRequest request) {
    return SealGenerationRequestDto(
      inputName: request.inputName,
      kanji: request.candidate.kanji,
      shape: request.style.shape.apiValue,
      style: request.style.style.apiValue,
      strokeWeight: request.style.strokeWeight.apiValue,
      balance: request.style.balance.apiValue,
      variantCount: 3,
    );
  }

  final String inputName;
  final String kanji;
  final String shape;
  final String style;
  final String strokeWeight;
  final String balance;
  final int variantCount;

  JsonMap toJson() {
    return {
      'input_name': inputName,
      'kanji': kanji,
      'shape': shape,
      'style': style,
      'stroke_weight': strokeWeight,
      'balance': balance,
      'variant_count': variantCount,
      'generation_rules': const {
        'max_characters': 2,
        'avoid_complex_characters': true,
        'engraving_friendly': true,
        'avoid_thin_lines': true,
        'avoid_decorative_details': true,
        'plain_background': true,
      },
    };
  }
}

class SealGenerationResponseDto {
  const SealGenerationResponseDto({
    required this.requestId,
    required this.variants,
  });

  factory SealGenerationResponseDto.fromJson(JsonMap json) {
    return SealGenerationResponseDto(
      requestId: readString(json, 'request_id'),
      variants: readJsonList(json, 'variants')
          .map(
            (value) =>
                SealDesignVariantDto.fromJson(asJsonMap(value, 'seal variant')),
          )
          .toList(growable: false),
    );
  }

  final String requestId;
  final List<SealDesignVariantDto> variants;

  SealGenerationResult toDomain(SealGenerationRequest request) {
    return SealGenerationResult(
      request: request,
      requestId: requestId,
      variants: variants
          .map((variant) => variant.toDomain())
          .toList(growable: false),
    );
  }
}

class SealDesignVariantDto {
  const SealDesignVariantDto({
    required this.id,
    required this.storagePath,
    required this.downloadUrl,
    required this.label,
    required this.width,
    required this.height,
    required this.recipe,
  });

  factory SealDesignVariantDto.fromJson(JsonMap json) {
    return SealDesignVariantDto(
      id: readString(json, 'id'),
      storagePath: readString(json, 'storage_path'),
      downloadUrl: readString(json, 'download_url'),
      label: readString(json, 'label'),
      width: readInt(json, 'width', defaultValue: 1024),
      height: readInt(json, 'height', defaultValue: 1024),
      recipe: SealDesignRecipeDto.fromOptionalJson(json['recipe']),
    );
  }

  final String id;
  final String storagePath;
  final String downloadUrl;
  final String label;
  final int width;
  final int height;
  final SealDesignRecipeDto? recipe;

  SealDesignVariant toDomain() {
    return SealDesignVariant(
      id: id,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      label: label,
      width: width,
      height: height,
      recipe: recipe?.toDomain(),
    );
  }
}

class SealDesignRecipeDto {
  const SealDesignRecipeDto({
    required this.fontProfile,
    required this.impression,
    required this.weight,
    required this.spacing,
    required this.texture,
    required this.frame,
  });

  factory SealDesignRecipeDto.fromJson(JsonMap json) {
    return SealDesignRecipeDto(
      fontProfile: readString(json, 'font_profile'),
      impression: readString(json, 'impression'),
      weight: readString(json, 'weight'),
      spacing: readString(json, 'spacing'),
      texture: readString(json, 'texture'),
      frame: readString(json, 'frame'),
    );
  }

  static SealDesignRecipeDto? fromOptionalJson(Object? value) {
    if (value == null) {
      return null;
    }
    return SealDesignRecipeDto.fromJson(asJsonMap(value, 'seal recipe'));
  }

  final String fontProfile;
  final String impression;
  final String weight;
  final String spacing;
  final String texture;
  final String frame;

  SealDesignRecipe toDomain() {
    return SealDesignRecipe(
      fontProfile: fontProfile,
      impression: impression,
      weight: weight,
      spacing: spacing,
      texture: texture,
      frame: frame,
    );
  }
}
