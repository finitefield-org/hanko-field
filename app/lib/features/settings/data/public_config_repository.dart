import '../../../core/api/core_api.dart';
import '../domain/public_config.dart';

class PublicConfigRepository {
  const PublicConfigRepository(this._apiClient);

  final HankoApiClient _apiClient;

  Future<PublicConfig> fetchPublicConfig() async {
    final json = await _apiClient.getJson('/v1/config/public');
    return PublicConfigDto.fromJson(json).toDomain();
  }
}

class PublicConfigDto {
  const PublicConfigDto({
    required this.supportedLocales,
    required this.defaultLocale,
    required this.defaultCurrency,
    required this.currencyByLocale,
  });

  factory PublicConfigDto.fromJson(JsonMap json) {
    return PublicConfigDto(
      supportedLocales: readStringList(json, 'supported_locales'),
      defaultLocale: readString(json, 'default_locale'),
      defaultCurrency: readString(json, 'default_currency'),
      currencyByLocale: readStringMap(json, 'currency_by_locale'),
    );
  }

  final List<String> supportedLocales;
  final String defaultLocale;
  final String defaultCurrency;
  final Map<String, String> currencyByLocale;

  PublicConfig toDomain() {
    return PublicConfig(
      supportedLocales: supportedLocales,
      defaultLocale: defaultLocale,
      defaultCurrency: defaultCurrency,
      currencyByLocale: currencyByLocale,
    );
  }
}
