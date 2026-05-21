import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hankofield/core/api/core_api.dart';
import 'package:hankofield/features/design/design.dart';
import 'package:hankofield/features/order/order.dart';
import 'package:hankofield/features/settings/settings.dart';
import 'package:hankofield/features/stones/stones.dart';

void main() {
  test(
    'KanjiCandidatesRepository posts snake_case and maps candidates',
    () async {
      final transport = FakeTransport([
        HankoApiResponse(
          statusCode: 200,
          body: jsonEncode({
            'real_name': 'Michael',
            'reason_language': 'en',
            'gender': 'unspecified',
            'kanji_style': 'japanese',
            'candidates': [
              {
                'kanji': '美空',
                'reading': 'Misora',
                'meaning': 'Beautiful sky',
                'impression': ['Elegant', 'Gentle'],
                'reason': 'A graceful two-character option.',
                'character_count': 2,
                'stroke_complexity': 'medium',
                'engraving_suitability': 'high',
              },
            ],
          }),
        ),
      ]);
      final repo = KanjiCandidatesRepository(_client(transport));

      final result = await repo.generateCandidates(
        const KanjiCandidatesRequest(
          realName: 'Michael',
          reasonLanguage: 'en',
          count: 3,
        ),
      );

      expect(transport.singleRequest.method, 'POST');
      expect(transport.singleRequest.uri.path, '/v1/kanji-candidates');
      expect(transport.singleRequest.body?['real_name'], 'Michael');
      expect(transport.singleRequest.body?['kanji_style'], 'japanese');
      expect(result.candidates.single.kanji, '美空');
      expect(result.candidates.single.meaning, 'Beautiful sky');
      expect(result.candidates.single.characterCount, 2);
    },
  );

  test(
    'StoneListingsRepository maps list response into domain model',
    () async {
      final transport = FakeTransport([
        HankoApiResponse(
          statusCode: 200,
          body: jsonEncode({
            'locale': 'en',
            'currency': 'JPY',
            'stone_listings': [
              {
                'key': 'stone_listing_001',
                'listing_code': 'RQZ-0001',
                'material_key': 'rose_quartz',
                'size': '24x24x60 mm',
                'title': 'Soft Pink Rose Quartz Seal Stone',
                'description': 'A soft pink rose quartz seal stone.',
                'story': 'A one-of-a-kind piece.',
                'facets': {
                  'color_family': 'pink',
                  'color_tags': ['soft'],
                  'pattern_primary': 'plain',
                  'pattern_tags': ['clear'],
                  'stone_shape': 'square',
                  'translucency': 'semi_translucent',
                },
                'price': 18000,
                'status': 'published',
                'is_active': true,
                'photos': [
                  {
                    'asset_id': 'asset_001',
                    'asset_url': 'https://example.test/stone.png',
                    'alt': 'Rose quartz',
                    'sort_order': 1,
                    'is_primary': true,
                    'width': 1200,
                    'height': 900,
                  },
                ],
              },
            ],
          }),
        ),
      ]);
      final repo = StoneListingsRepository(_client(transport));

      final result = await repo.listStoneListings(
        const StoneListingsQuery(locale: 'en', colorFamily: 'pink'),
      );

      expect(transport.singleRequest.method, 'GET');
      expect(transport.singleRequest.uri.path, '/v1/stone-listings');
      expect(transport.singleRequest.uri.queryParameters['locale'], 'en');
      expect(
        transport.singleRequest.uri.queryParameters['color_family'],
        'pink',
      );
      expect(result.listings.single.id, 'stone_listing_001');
      expect(result.listings.single.price.amount, 18000);
      expect(result.listings.single.price.currency, 'JPY');
      expect(result.listings.single.isOrderable, isTrue);
    },
  );

  test('OrderRepository maps order and checkout responses', () async {
    final transport = FakeTransport([
      HankoApiResponse(
        statusCode: 201,
        body: jsonEncode({
          'order_id': 'ord_001',
          'order_no': 'HF-0001',
          'status': 'pending_payment',
          'payment_status': 'unpaid',
          'fulfillment_status': 'not_started',
          'pricing': {'total': 22000, 'currency': 'JPY'},
          'idempotent_replay': false,
        }),
      ),
      HankoApiResponse(
        statusCode: 201,
        body: jsonEncode({
          'order_id': 'ord_001',
          'session_id': 'cs_test_001',
          'checkout_url': 'https://checkout.stripe.test/session',
          'payment_intent_id': 'pi_test_001',
        }),
      ),
    ]);
    final repo = OrderRepository(_client(transport));

    final created = await repo.createOrder(_draft());
    final checkout = await repo.createCheckoutSession(
      const CheckoutSessionRequest(orderId: 'ord_001'),
    );

    expect(transport.requests.first.body?['idempotency_key'], 'idem_001');
    expect(transport.requests.first.body?['terms_agreed'], isTrue);
    expect(created.orderNo, 'HF-0001');
    expect(created.pricing.amount, 22000);
    expect(
      transport.requests.last.uri.path,
      '/v1/payments/stripe/checkout-session',
    );
    expect(checkout.sessionId, 'cs_test_001');
  });

  test('PublicConfigDto maps public config response', () {
    final config = PublicConfigDto.fromJson({
      'supported_locales': ['en', 'ja'],
      'default_locale': 'en',
      'default_currency': 'USD',
      'currency_by_locale': {'ja': 'JPY'},
    }).toDomain();

    expect(config.defaultLocale, 'en');
    expect(config.currencyForLocale('ja'), 'JPY');
    expect(config.currencyForLocale('en'), 'USD');
  });

  test('HankoApiClient maps API error envelope', () async {
    final transport = FakeTransport([
      HankoApiResponse(
        statusCode: 400,
        body: jsonEncode({
          'error': {
            'code': 'validation_error',
            'message': 'real_name is required',
          },
        }),
      ),
    ]);
    final client = _client(transport);

    await expectLater(
      client.postJson('/v1/kanji-candidates', const {}),
      throwsA(
        isA<HankoApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having((error) => error.code, 'code', 'validation_error'),
      ),
    );
  });
}

HankoApiClient _client(FakeTransport transport) {
  return HankoApiClient(
    baseUri: Uri.parse('https://api.example.test'),
    transport: transport,
  );
}

SealOrderDraft _draft() {
  return const SealOrderDraft(
    channel: 'app',
    locale: 'en',
    idempotencyKey: 'idem_001',
    termsAgreed: true,
    listingId: 'stone_listing_001',
    seal: SealOrderSeal(
      line1: '美空',
      line2: '',
      shape: 'square',
      fontKey: 'ai_generated_seal',
    ),
    shipping: SealOrderShipping(
      countryCode: 'JP',
      recipientName: 'Michael Smith',
      phone: '+81-90-0000-0000',
      postalCode: '100-0001',
      state: 'Tokyo',
      city: 'Chiyoda',
      addressLine1: '1-1',
      addressLine2: '',
    ),
    contact: SealOrderContact(
      email: 'michael@example.test',
      preferredLocale: 'en',
    ),
  );
}

class FakeTransport implements HankoApiTransport {
  FakeTransport(this._responses);

  final List<HankoApiResponse> _responses;
  final List<HankoApiRequest> requests = [];

  HankoApiRequest get singleRequest {
    expect(requests, hasLength(1));
    return requests.single;
  }

  @override
  Future<HankoApiResponse> send(HankoApiRequest request) async {
    requests.add(request);
    if (_responses.isEmpty) {
      fail('unexpected API request to ${request.uri}');
    }
    return _responses.removeAt(0);
  }
}
