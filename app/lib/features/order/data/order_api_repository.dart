import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:miniriverpod/miniriverpod.dart';

import '../../../app/config/app_runtime_config.dart';
import '../domain/order_models.dart';

@immutable
class PublicConfigData {
  final List<String> supportedLocales;
  final String defaultLocale;
  final String defaultCurrency;
  final Map<String, String> currencyByLocale;

  const PublicConfigData({
    required this.supportedLocales,
    required this.defaultLocale,
    required this.defaultCurrency,
    required this.currencyByLocale,
  });
}

@immutable
class CatalogResponseData {
  final String locale;
  final String currency;
  final CatalogData catalog;

  const CatalogResponseData({
    required this.locale,
    required this.currency,
    required this.catalog,
  });
}

@immutable
class CreateOrderResultData {
  final String orderId;
  final int total;
  final String currency;

  const CreateOrderResultData({
    required this.orderId,
    required this.total,
    required this.currency,
  });
}

@immutable
class CreateCheckoutSessionResultData {
  final String orderId;
  final String sessionId;
  final String checkoutUrl;
  final String paymentIntentId;

  const CreateCheckoutSessionResultData({
    required this.orderId,
    required this.sessionId,
    required this.checkoutUrl,
    required this.paymentIntentId,
  });
}

class OrderApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  OrderApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'OrderApiException(status=$statusCode, code=$code, message=$message)';
  }
}

class OrderApiRepository {
  final AppRuntimeConfig runtimeConfig;
  final http.Client httpClient;

  const OrderApiRepository({
    required this.runtimeConfig,
    required this.httpClient,
  });

  Future<PublicConfigData> fetchPublicConfig() async {
    final payload = await _getJson('/v1/config/public');

    final supportedLocales = _asList(payload['supported_locales'])
        .map(_asString)
        .where((value) => value.isNotEmpty)
        .map((value) => value.toLowerCase())
        .toList(growable: false);

    final defaultLocale = _asString(payload['default_locale']).toLowerCase();
    final defaultCurrency = _asString(
      payload['default_currency'],
    ).toUpperCase();

    final currencyByLocale = <String, String>{};
    final rawCurrencyByLocale = _asMap(payload['currency_by_locale']);
    for (final entry in rawCurrencyByLocale.entries) {
      final locale = entry.key.trim().toLowerCase();
      final currency = _asString(entry.value).toUpperCase();
      if (locale.isNotEmpty && currency.isNotEmpty) {
        currencyByLocale[locale] = currency;
      }
    }

    return PublicConfigData(
      supportedLocales: supportedLocales,
      defaultLocale: defaultLocale,
      defaultCurrency: defaultCurrency,
      currencyByLocale: currencyByLocale,
    );
  }

  Future<CatalogResponseData> fetchCatalog({required String locale}) async {
    final payload = await _getJson('/v1/catalog', query: {'locale': locale});

    final resolvedLocale = _asString(payload['locale']).toLowerCase();
    final currency = _asString(payload['currency']).toUpperCase();

    final fonts = _asList(payload['fonts'])
        .map((entry) {
          final map = _asMap(entry);
          final rawKanjiStyle = _firstNonEmptyString([
            map['kanji_style'],
            map['style'],
          ]);
          return FontOption(
            key: _asString(map['key']),
            label: _asString(map['label']),
            family: _asString(map['font_family']),
            kanjiStyle: KanjiStyle.fromCode(rawKanjiStyle),
          );
        })
        .where((font) {
          return font.key.isNotEmpty &&
              font.label.isNotEmpty &&
              font.family.isNotEmpty;
        })
        .toList(growable: false);

    final stoneListings = _asList(payload['stone_listings'])
        .map((entry) {
          final map = _asMap(entry);
          final photos = _asList(
            map['photos'],
          ).map(_asMap).toList(growable: false);
          final primaryPhoto = _pickPrimaryPhoto(photos);
          final photoUrl = _resolvePhotoUrl(primaryPhoto);
          final supportedSealShapes = _asList(map['supported_seal_shapes'])
              .map((shape) => _asString(shape).toLowerCase())
              .where((shape) => shape.isNotEmpty)
              .toList(growable: false);

          return StoneListingOption(
            key: _asString(map['key']),
            listingCode: _asString(map['listing_code']),
            title: _asString(map['title']),
            description: _asString(map['description']),
            story: _asString(map['story']),
            supportedSealShapes: supportedSealShapes,
            price: _asInt(map['price']),
            photoUrl: photoUrl,
            photoAlt: _asString(primaryPhoto?['alt']),
            hasPhoto: photoUrl.isNotEmpty,
          );
        })
        .where((listing) {
          return listing.key.isNotEmpty && listing.title.isNotEmpty;
        })
        .toList(growable: false);

    final countries = _asList(payload['countries'])
        .map((entry) {
          final map = _asMap(entry);
          return CountryOption(
            code: _asString(map['code']).toUpperCase(),
            label: _asString(map['label']),
            shipping: _asInt(map['shipping_fee']),
          );
        })
        .where((country) {
          return country.code.isNotEmpty && country.label.isNotEmpty;
        })
        .toList(growable: false);

    return CatalogResponseData(
      locale: resolvedLocale,
      currency: currency,
      catalog: CatalogData(
        fonts: fonts,
        stoneListings: stoneListings,
        countries: countries,
      ),
    );
  }

  Future<List<KanjiCandidate>> generateKanjiCandidates({
    required String realName,
    required CandidateGender gender,
    required KanjiStyle style,
    required String reasonLanguage,
  }) async {
    final payload = await _postJson('/v1/kanji-candidates', {
      'real_name': realName,
      'reason_language': reasonLanguage,
      'gender': gender.code,
      'kanji_style': style.code,
    });

    final candidates = _asList(payload['candidates'])
        .map((entry) {
          final map = _asMap(entry);
          final kanji = _asString(map['kanji']);
          return KanjiCandidate(
            kanji: kanji,
            line1: kanji,
            line2: '',
            reading: _asString(map['reading']),
            reason: _asString(map['reason']),
          );
        })
        .where((candidate) {
          return candidate.kanji.isNotEmpty &&
              candidate.reading.isNotEmpty &&
              candidate.reason.isNotEmpty;
        })
        .toList(growable: false);

    return candidates;
  }

  Future<CreateOrderResultData> createOrder({
    required String locale,
    required String idempotencyKey,
    required bool termsAgreed,
    required String sealLine1,
    required String sealLine2,
    required SealShape shape,
    required String fontKey,
    required String listingId,
    required String countryCode,
    required String recipientName,
    required String phone,
    required String postalCode,
    required String state,
    required String city,
    required String addressLine1,
    required String addressLine2,
    required String email,
  }) async {
    final payload = await _postJson('/v1/orders', {
      'channel': 'app',
      'locale': locale,
      'idempotency_key': idempotencyKey,
      'terms_agreed': termsAgreed,
      'seal': {
        'line1': sealLine1,
        'line2': sealLine2,
        'shape': shape.code,
        'font_key': fontKey,
      },
      'listing_id': listingId,
      'shipping': {
        'country_code': countryCode,
        'recipient_name': recipientName,
        'phone': phone,
        'postal_code': postalCode,
        'state': state,
        'city': city,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
      },
      'contact': {'email': email, 'preferred_locale': locale},
    });

    final pricing = _asMap(payload['pricing']);
    return CreateOrderResultData(
      orderId: _asString(payload['order_id']),
      total: _asInt(pricing['total']),
      currency: _asString(pricing['currency']).toUpperCase(),
    );
  }

  Future<CreateCheckoutSessionResultData> createStripeCheckoutSession({
    required String orderId,
    required String customerEmail,
  }) async {
    final payload = await _postJson('/v1/payments/stripe/checkout-session', {
      'order_id': orderId,
      'customer_email': customerEmail,
    });

    return CreateCheckoutSessionResultData(
      orderId: _asString(payload['order_id']),
      sessionId: _asString(payload['session_id']),
      checkoutUrl: _asString(payload['checkout_url']),
      paymentIntentId: _asString(payload['payment_intent_id']),
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _buildUri(path, query: query);
    final response = await httpClient.get(uri, headers: _headers());
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _buildUri(path);
    final response = await httpClient.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decodeJsonResponse(response);
  }

  Map<String, String> _headers() {
    return {'accept': 'application/json', 'content-type': 'application/json'};
  }

  Uri _buildUri(String path, {Map<String, String>? query}) {
    final base = runtimeConfig.apiBaseUrl.trim();
    final normalizedBase = base.endsWith('/') ? base : '$base/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final baseUri = Uri.parse(normalizedBase);
    final uri = baseUri.resolve(normalizedPath);

    if (query == null || query.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    final status = response.statusCode;
    final text = response.body;

    Object? decoded;
    if (text.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        decoded = null;
      }
    }

    final payload = decoded is Map
        ? decoded.cast<String, dynamic>()
        : <String, dynamic>{};

    if (status >= 200 && status < 300) {
      return payload;
    }

    final error = _asMap(payload['error']);
    final code = _asString(error['code']).isEmpty
        ? 'http_error'
        : _asString(error['code']);
    final message = _asString(error['message']).isEmpty
        ? 'request failed with status $status'
        : _asString(error['message']);

    throw OrderApiException(statusCode: status, code: code, message: message);
  }
}

String _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = _asString(value);
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

final orderApiRepositoryProvider = Provider<OrderApiRepository>((ref) {
  final runtimeConfig = ref.watch(appRuntimeConfigProvider);
  final client = http.Client();
  ref.onDispose(client.close);

  return OrderApiRepository(runtimeConfig: runtimeConfig, httpClient: client);
});

Map<String, dynamic>? _pickPrimaryPhoto(List<Map<String, dynamic>> photos) {
  if (photos.isEmpty) {
    return null;
  }

  final primary = photos
      .where((photo) => _asBool(photo['is_primary']))
      .toList(growable: false);
  if (primary.isNotEmpty) {
    return primary.first;
  }

  return photos.first;
}

String _resolvePhotoUrl(Map<String, dynamic>? photo) {
  if (photo == null) {
    return '';
  }

  return _asString(photo['asset_url']).trim();
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(Object? value) {
  if (value is List) {
    return value;
  }
  return const [];
}

String _asString(Object? value) {
  if (value is String) {
    return value;
  }
  if (value == null) {
    return '';
  }
  return value.toString();
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

bool _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  if (value is num) {
    return value != 0;
  }
  return false;
}
