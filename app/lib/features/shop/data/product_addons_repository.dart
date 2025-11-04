import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/catalog.dart';
import 'package:app/features/shop/domain/product_addons.dart';

abstract class ProductAddonsRepository {
  Future<ProductAddons> fetchAddons({
    required String productId,
    required ExperienceGate experience,
  });
}

class FakeProductAddonsRepository implements ProductAddonsRepository {
  const FakeProductAddonsRepository();

  @override
  Future<ProductAddons> fetchAddons({
    required String productId,
    required ExperienceGate experience,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final map = experience.isInternational
        ? _internationalAddons
        : _domesticAddons;
    final addons = map[productId];
    if (addons == null) {
      throw StateError('No add-ons configured for product "$productId".');
    }
    return addons;
  }

  static ProductAddon _addon({
    required String id,
    required String name,
    required String description,
    required ProductAddonCategory category,
    required int amount,
    required String currency,
    required String imageUrl,
    String? badge,
    bool isRecommended = false,
    bool isDefaultSelected = false,
  }) {
    return ProductAddon(
      id: id,
      name: name,
      description: description,
      category: category,
      price: CatalogMoney(amount: amount, currency: currency),
      imageUrl: imageUrl,
      badge: badge,
      isRecommended: isRecommended,
      isDefaultSelected: isDefaultSelected,
    );
  }

  static ProductAddonGroup _group({
    required ProductAddonCategory category,
    required String label,
    required List<ProductAddon> addons,
    String? helper,
  }) {
    return ProductAddonGroup(
      category: category,
      displayLabel: label,
      helperText: helper,
      addons: addons,
    );
  }

  static ProductAddonRecommendation _recommendation({
    required String id,
    required String title,
    required String description,
    required List<String> addonIds,
    required int amount,
    required String currency,
    String? badge,
  }) {
    return ProductAddonRecommendation(
      id: id,
      title: title,
      description: description,
      addonIds: addonIds,
      estimatedTotal: CatalogMoney(amount: amount, currency: currency),
      badge: badge,
    );
  }

  static final Map<String, ProductAddons> _domesticAddons = {
    'seal-2024': ProductAddons(
      productId: 'seal-2024',
      groups: [
        _group(
          category: ProductAddonCategory.caseAccessory,
          label: '印鑑ケース',
          helper: '日常使いに最適なケースを追加して持ち運びも安心に。',
          addons: [
            _addon(
              id: 'case-ultra-suede',
              name: 'ウルトラスエードケース',
              description: '超極細繊維で印材をしっかり保護します。',
              category: ProductAddonCategory.caseAccessory,
              amount: 4800,
              currency: 'JPY',
              imageUrl:
                  'https://images.unsplash.com/photo-1524592094714-0f0654e20314?w=600',
              badge: '人気',
              isRecommended: true,
              isDefaultSelected: true,
            ),
            _addon(
              id: 'case-lacquered',
              name: '越前漆ケース',
              description: '本漆仕上げの伝統工芸ケース。贈答用にも最適。',
              category: ProductAddonCategory.caseAccessory,
              amount: 7200,
              currency: 'JPY',
              imageUrl:
                  'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=600',
            ),
          ],
        ),
        _group(
          category: ProductAddonCategory.storageBox,
          label: '保管用桐箱',
          helper: '湿度調整に優れた桐箱で長期保存も安心です。',
          addons: [
            _addon(
              id: 'box-kiri-classic',
              name: '桐箱（焼印入り）',
              description: '焼印ロゴ入りのスタンダード桐箱セット。',
              category: ProductAddonCategory.storageBox,
              amount: 3600,
              currency: 'JPY',
              imageUrl:
                  'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=600',
              isDefaultSelected: true,
            ),
            _addon(
              id: 'box-tea-finish',
              name: '桐箱（煎茶仕上げ）',
              description: '茶葉で燻した深みのある色合い。和風ギフトに。',
              category: ProductAddonCategory.storageBox,
              amount: 5400,
              currency: 'JPY',
              imageUrl:
                  'https://images.unsplash.com/photo-1460518451285-97b6aa326961?w=600',
              badge: '限定',
              isRecommended: true,
            ),
          ],
        ),
        _group(
          category: ProductAddonCategory.ink,
          label: '朱肉・補充インク',
          helper: '鮮明な印影を保つための朱肉と補充インク。',
          addons: [
            _addon(
              id: 'ink-vermillion-premium',
              name: '朱肉プレミアム',
              description: '顔料多めで滲みにくいワークフロー向け朱肉。',
              category: ProductAddonCategory.ink,
              amount: 2800,
              currency: 'JPY',
              imageUrl:
                  'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?w=600',
              isRecommended: true,
            ),
            _addon(
              id: 'ink-refill-pack',
              name: '朱肉補充インク（2本）',
              description: '約6ヶ月分の補充インク。キャップ付きで携帯も安心。',
              category: ProductAddonCategory.ink,
              amount: 2200,
              currency: 'JPY',
              imageUrl:
                  'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=600',
            ),
          ],
        ),
      ],
      recommendations: [
        _recommendation(
          id: 'ceremony-ready',
          title: '式典おすすめセット',
          description: 'ケース・桐箱・朱肉で贈答にも使えるフルセット。',
          addonIds: [
            'case-ultra-suede',
            'box-kiri-classic',
            'ink-vermillion-premium',
          ],
          amount: 11200,
          currency: 'JPY',
          badge: '¥1,200 セーブ',
        ),
      ],
    ),
    'echizen-case': ProductAddons(
      productId: 'echizen-case',
      groups: [
        _group(
          category: ProductAddonCategory.storageBox,
          label: '保管用桐箱',
          addons: [
            _addon(
              id: 'box-limited-indigo',
              name: '藍染め桐箱',
              description: '越前和紙と同じ藍染めで仕上げた限定桐箱。',
              category: ProductAddonCategory.storageBox,
              amount: 6800,
              currency: 'JPY',
              imageUrl:
                  'https://images.unsplash.com/photo-1473186505569-9c61870c11f9?w=600',
              badge: '新作',
              isRecommended: true,
            ),
          ],
        ),
        _group(
          category: ProductAddonCategory.ink,
          label: '朱肉・メンテナンス',
          addons: [
            _addon(
              id: 'ink-craft-mini',
              name: 'クラフト朱肉ミニ',
              description: '工房監修の朱肉ミニサイズ。旅行用として人気。',
              category: ProductAddonCategory.ink,
              amount: 1800,
              currency: 'JPY',
              imageUrl:
                  'https://images.unsplash.com/photo-1484639726803-87c1860a5abf?w=600',
            ),
          ],
        ),
      ],
      recommendations: [
        _recommendation(
          id: 'gift-upgrade',
          title: 'ギフト仕上げ推奨',
          description: '藍染め桐箱と朱肉でプレミアムギフト仕様に。',
          addonIds: ['box-limited-indigo', 'ink-craft-mini'],
          amount: 8600,
          currency: 'JPY',
        ),
      ],
    ),
  };

  static final Map<String, ProductAddons> _internationalAddons = {
    'signature-kit': ProductAddons(
      productId: 'signature-kit',
      groups: [
        _group(
          category: ProductAddonCategory.caseAccessory,
          label: 'Travel Case',
          helper: 'Protect your seal during travel with padded cases.',
          addons: [
            _addon(
              id: 'case-travel-zip',
              name: 'Zip Travel Case',
              description: 'Compact vegan leather case with elastic holders.',
              category: ProductAddonCategory.caseAccessory,
              amount: 58,
              currency: 'USD',
              imageUrl:
                  'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=600',
              badge: 'Most popular',
              isRecommended: true,
              isDefaultSelected: true,
            ),
            _addon(
              id: 'case-carbon',
              name: 'Carbon Fiber Pouch',
              description: 'Feather-light shell with microfiber interior.',
              category: ProductAddonCategory.caseAccessory,
              amount: 86,
              currency: 'USD',
              imageUrl:
                  'https://images.unsplash.com/photo-1534375971785-5c1826f7399f?w=600',
            ),
          ],
        ),
        _group(
          category: ProductAddonCategory.storageBox,
          label: 'Collector Boxes',
          helper:
              'Store multiple seals and ink pads in humidity-balanced boxes.',
          addons: [
            _addon(
              id: 'box-traveler',
              name: 'Traveler Storage Box',
              description: 'Lightweight hinoki cedar with magnetic closure.',
              category: ProductAddonCategory.storageBox,
              amount: 74,
              currency: 'USD',
              imageUrl:
                  'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=600',
              isRecommended: true,
            ),
            _addon(
              id: 'box-display',
              name: 'Display Stand Box',
              description: 'Glass-top display to showcase up to 3 seals.',
              category: ProductAddonCategory.storageBox,
              amount: 129,
              currency: 'USD',
              imageUrl:
                  'https://images.unsplash.com/photo-1503602642458-232111445657?w=600',
            ),
          ],
        ),
        _group(
          category: ProductAddonCategory.ink,
          label: 'Ink & Refills',
          addons: [
            _addon(
              id: 'ink-crimson',
              name: 'Crimson Gel Ink',
              description: 'Cold-weather stable gel ink with vivid impression.',
              category: ProductAddonCategory.ink,
              amount: 32,
              currency: 'USD',
              imageUrl:
                  'https://images.unsplash.com/photo-1616628188505-4040e1b24b80?w=600',
              isRecommended: true,
            ),
            _addon(
              id: 'ink-cartridge-pack',
              name: 'Refill Cartridge Pack',
              description:
                  'Three replacement cartridges with spill-proof caps.',
              category: ProductAddonCategory.ink,
              amount: 26,
              currency: 'USD',
              imageUrl:
                  'https://images.unsplash.com/photo-1524592094714-0f0654e20314?w=600',
            ),
          ],
        ),
      ],
      recommendations: [
        _recommendation(
          id: 'travel-bundle',
          title: 'Global Traveler Bundle',
          description: 'Everything you need for business trips abroad.',
          addonIds: ['case-travel-zip', 'box-traveler', 'ink-crimson'],
          amount: 164,
          currency: 'USD',
          badge: 'Save \$15',
        ),
      ],
    ),
    'cultural-set': ProductAddons(
      productId: 'cultural-set',
      groups: [
        _group(
          category: ProductAddonCategory.caseAccessory,
          label: 'Presentation Cases',
          addons: [
            _addon(
              id: 'case-kimono',
              name: 'Kimono Brocade Case',
              description: 'Hand-woven brocade inspired by Kyoto textiles.',
              category: ProductAddonCategory.caseAccessory,
              amount: 96,
              currency: 'USD',
              imageUrl:
                  'https://images.unsplash.com/photo-1524594154908-edd07315521b?w=600',
              badge: 'Limited run',
              isRecommended: true,
            ),
          ],
        ),
      ],
      recommendations: const [],
    ),
  };
}
