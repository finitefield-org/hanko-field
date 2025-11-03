import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/features/shop/domain/shop_home_content.dart';
import 'package:flutter/material.dart';

abstract class ShopHomeRepository {
  Future<List<ShopCategory>> fetchCategories({
    required ExperienceGate experience,
  });

  Future<List<ShopPromotion>> fetchPromotions({
    required ExperienceGate experience,
  });

  Future<List<ShopMaterialRecommendation>> fetchRecommendedMaterials({
    required ExperienceGate experience,
  });

  Future<List<ShopGuideLink>> fetchGuideLinks({
    required ExperienceGate experience,
  });
}

class FakeShopHomeRepository implements ShopHomeRepository {
  const FakeShopHomeRepository();

  @override
  Future<List<ShopCategory>> fetchCategories({
    required ExperienceGate experience,
  }) async {
    await _simulateLatency();
    if (experience.isDomestic) {
      return _domesticCategories(experience);
    }
    return _internationalCategories(experience);
  }

  @override
  Future<List<ShopPromotion>> fetchPromotions({
    required ExperienceGate experience,
  }) async {
    await _simulateLatency();
    if (experience.isDomestic) {
      return _domesticPromotions(experience);
    }
    return _internationalPromotions(experience);
  }

  @override
  Future<List<ShopMaterialRecommendation>> fetchRecommendedMaterials({
    required ExperienceGate experience,
  }) async {
    await _simulateLatency();
    if (experience.isDomestic) {
      return _domesticMaterials(experience);
    }
    return _internationalMaterials(experience);
  }

  @override
  Future<List<ShopGuideLink>> fetchGuideLinks({
    required ExperienceGate experience,
  }) async {
    await _simulateLatency();
    if (experience.isDomestic) {
      return _domesticGuides();
    }
    return _internationalGuides();
  }

  List<ShopCategory> _domesticCategories(ExperienceGate experience) {
    return [
      ShopCategory(
        id: 'japanese-hardwood',
        title: '国産柘（つげ）',
        description: '朱肉との相性が良く、銀行印に人気の硬木素材。',
        imageUrl:
            'https://images.unsplash.com/photo-1523419409543-0c1df022bdd1?w=800',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'materials', identifier: 'tsuge'),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopCategory(
        id: 'horn',
        title: '黒水牛',
        description: '艶のある仕上がりで実印にも選ばれる定番。',
        imageUrl:
            'https://images.unsplash.com/photo-1472289065668-ce650ac443d2?w=800',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'materials', identifier: 'kuro-sui'),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopCategory(
        id: 'titanium',
        title: 'チタン',
        description: '耐久性・耐摩耗性に優れた現代的な素材。',
        imageUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=800',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'materials', identifier: 'titanium'),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopCategory(
        id: 'handcrafted-case',
        title: '越前和紙ケース',
        description: '伝統工芸士が作るケースで贈り物にも最適。',
        imageUrl:
            'https://images.unsplash.com/photo-1521579773717-291064d5739d?w=800',
        destination: ShopDestination(
          route: ShopDetailRoute(
            entity: 'products',
            identifier: 'echizen-case',
          ),
          overrideTab: AppTab.shop,
        ),
      ),
    ];
  }

  List<ShopCategory> _internationalCategories(ExperienceGate experience) {
    return [
      ShopCategory(
        id: 'international-favorites',
        title: 'Popular Abroad',
        description: 'Lightweight seals designed for international shipping.',
        imageUrl:
            'https://images.unsplash.com/photo-1520256862855-398228c41684?w=800',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'products', identifier: 'intl-kit'),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopCategory(
        id: 'travel-friendly',
        title: 'Travel-Friendly Seals',
        description: 'Compact cases and durable materials for frequent flyers.',
        imageUrl:
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'materials', identifier: 'resin-air'),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopCategory(
        id: 'cultural-series',
        title: 'Cultural Series',
        description: 'Kanji inspired designs with bilingual guides included.',
        imageUrl:
            'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=800',
        destination: ShopDestination(
          route: ShopDetailRoute(
            entity: 'products',
            identifier: 'cultural-set',
          ),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopCategory(
        id: 'signature-kits',
        title: 'Signature Kits',
        description: 'Everything you need to stamp abroad with confidence.',
        imageUrl:
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
        destination: ShopDestination(
          route: ShopDetailRoute(
            entity: 'products',
            identifier: 'signature-kit',
          ),
          overrideTab: AppTab.shop,
        ),
      ),
    ];
  }

  List<ShopPromotion> _domesticPromotions(ExperienceGate experience) {
    return [
      ShopPromotion(
        id: 'new-year-campaign',
        headline: '新春限定セット',
        subheading: '干支モチーフ入り朱肉と印鑑をセットで 15% オフ。',
        imageUrl:
            'https://images.unsplash.com/photo-1512427691650-1e0c7a98a111?w=1200',
        ctaLabel: 'セットを見る',
        badgeLabel: '期間限定',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'products', identifier: 'seal-2024'),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopPromotion(
        id: 'titanium-upgrade',
        headline: 'チタンアップグレード',
        subheading: '既存の印影データで即日製作。${experience.currencySymbol}8,800〜。',
        imageUrl:
            'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?w=1200',
        ctaLabel: 'アップグレードする',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'materials', identifier: 'titanium'),
          overrideTab: AppTab.shop,
        ),
      ),
    ];
  }

  List<ShopPromotion> _internationalPromotions(ExperienceGate experience) {
    return [
      ShopPromotion(
        id: 'intl-shipping',
        headline: 'Global Shipping Bundle',
        subheading:
            'Tracking updates in English and customs-ready documentation included.',
        imageUrl:
            'https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?w=1200',
        ctaLabel: 'View bundle',
        badgeLabel: 'New',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'products', identifier: 'intl-kit'),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopPromotion(
        id: 'cultural-guide',
        headline: 'Kanji Culture Guide',
        subheading:
            'Learn etiquette with bilingual materials included in every purchase.',
        imageUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1200',
        ctaLabel: 'Read guide',
        destination: ShopDestination(
          route: GuidesRoute(
            sectionSegments: const ['culture', 'kanji-etiquette'],
          ),
        ),
      ),
    ];
  }

  List<ShopMaterialRecommendation> _domesticMaterials(
    ExperienceGate experience,
  ) {
    return [
      ShopMaterialRecommendation(
        id: 'onyx-black',
        name: '黒耀石',
        description: '硬度が高くキメが細かい。公的登録にも安心の一本。',
        origin: '長野県産',
        hardness: 'HRA 90',
        imageUrl:
            'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800',
        priceLabel: '${experience.currencySymbol}12,000',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'materials', identifier: 'onyx-black'),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopMaterialRecommendation(
        id: 'premium-horn',
        name: '最高級黒水牛',
        description: '芯持ち角のみ使用。滑らかな押し心地と深い光沢。',
        origin: 'ベトナム産原料／日本仕上げ',
        hardness: 'HRA 85',
        imageUrl:
            'https://images.unsplash.com/photo-1503389152951-9f343605f61e?w=800',
        priceLabel: '${experience.currencySymbol}18,500',
        destination: ShopDestination(
          route: ShopDetailRoute(
            entity: 'materials',
            identifier: 'premium-horn',
          ),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopMaterialRecommendation(
        id: 'hybrid-titanium',
        name: 'ハイブリッドチタン',
        description: '軽量化と耐摩耗性を両立。長期利用でも歪みを抑制。',
        origin: '国内加工',
        hardness: 'HV 320',
        imageUrl:
            'https://images.unsplash.com/photo-1503602642458-232111445657?w=800',
        priceLabel: '${experience.currencySymbol}22,000',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'materials', identifier: 'hybrid-ti'),
          overrideTab: AppTab.shop,
        ),
      ),
    ];
  }

  List<ShopMaterialRecommendation> _internationalMaterials(
    ExperienceGate experience,
  ) {
    return [
      ShopMaterialRecommendation(
        id: 'global-acrylic',
        name: 'Global Acrylic',
        description:
            'Ultra-lightweight acrylic with reinforced edges for secure transport.',
        origin: 'Made in Japan',
        hardness: 'HV 150',
        imageUrl:
            'https://images.unsplash.com/photo-1448932223592-d1fc686e76ea?w=800',
        priceLabel: '${experience.currencySymbol}89',
        destination: ShopDestination(
          route: ShopDetailRoute(entity: 'materials', identifier: 'global-ac'),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopMaterialRecommendation(
        id: 'cosmo-steel',
        name: 'Cosmo Steel',
        description:
            'Precision milled stainless steel core with anti-slip engraving.',
        origin: 'Machined in Niigata',
        hardness: 'HRC 60',
        imageUrl:
            'https://images.unsplash.com/photo-1477686998080-3aa9da91e081?w=800',
        priceLabel: '${experience.currencySymbol}145',
        destination: ShopDestination(
          route: ShopDetailRoute(
            entity: 'materials',
            identifier: 'cosmo-steel',
          ),
          overrideTab: AppTab.shop,
        ),
      ),
      ShopMaterialRecommendation(
        id: 'heritage-kit',
        name: 'Heritage Gift Kit',
        description:
            'Includes bilingual care instructions and cultural etiquette guide.',
        origin: 'Tokyo Workshop',
        hardness: 'N/A',
        imageUrl:
            'https://images.unsplash.com/photo-1461695008884-25175c8a2601?w=800',
        priceLabel: '${experience.currencySymbol}210',
        destination: ShopDestination(
          route: ShopDetailRoute(
            entity: 'products',
            identifier: 'heritage-kit',
          ),
          overrideTab: AppTab.shop,
        ),
      ),
    ];
  }

  List<ShopGuideLink> _domesticGuides() {
    return [
      ShopGuideLink(
        id: 'inkan-basics',
        label: '印鑑の基礎知識',
        description: '用途別の選び方と法律上の注意点。',
        icon: Icons.menu_book_outlined,
        destination: ShopDestination(
          route: GuidesRoute(
            sectionSegments: const ['culture', 'inkan-basics'],
          ),
        ),
      ),
      ShopGuideLink(
        id: 'material-care',
        label: '素材別お手入れ',
        description: '朱肉の選び方と保管方法。',
        icon: Icons.brush_outlined,
        destination: ShopDestination(
          route: GuidesRoute(sectionSegments: const ['howto', 'material-care']),
        ),
      ),
      ShopGuideLink(
        id: 'registration-flow',
        label: '印鑑登録フロー',
        description: '自治体ごとの必要書類を解説。',
        icon: Icons.assignment_outlined,
        destination: ShopDestination(
          route: GuidesRoute(sectionSegments: const ['policy', 'registration']),
        ),
      ),
    ];
  }

  List<ShopGuideLink> _internationalGuides() {
    return [
      ShopGuideLink(
        id: 'how-to-stamp',
        label: 'How to stamp abroad',
        description: 'Video walkthrough and printable checklist.',
        icon: Icons.ondemand_video_outlined,
        destination: ShopDestination(
          route: GuidesRoute(
            sectionSegments: const ['howto', 'overseas-stamp'],
          ),
        ),
      ),
      ShopGuideLink(
        id: 'kanji-etiquette',
        label: 'Kanji etiquette',
        description: 'Understand meanings and when to use each seal.',
        icon: Icons.public_outlined,
        destination: ShopDestination(
          route: GuidesRoute(
            sectionSegments: const ['culture', 'kanji-etiquette'],
          ),
        ),
      ),
      ShopGuideLink(
        id: 'shipping-tracking',
        label: 'Shipping & tracking',
        description: 'Customs prep and delivery notifications explained.',
        icon: Icons.local_shipping_outlined,
        destination: ShopDestination(
          route: GuidesRoute(
            sectionSegments: const ['howto', 'shipping-tracking'],
          ),
        ),
      ),
    ];
  }
}

Future<void> _simulateLatency() async {
  await Future<void>.delayed(const Duration(milliseconds: 240));
}
