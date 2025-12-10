// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart'
    as catalog;
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.imageUrl,
    required this.targetRoute,
    this.accent,
    this.badge,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String imageUrl;
  final String targetRoute;
  final Color? accent;
  final String? badge;
}

class ShopPromotionHighlight {
  const ShopPromotionHighlight({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.imageUrl,
    required this.actionLabel,
    required this.targetRoute,
    this.code,
    this.discountPercent,
    this.limitedTime = false,
  });

  final String id;
  final String title;
  final String description;
  final String badge;
  final String imageUrl;
  final String actionLabel;
  final String targetRoute;
  final String? code;
  final int? discountPercent;
  final bool limitedTime;
}

class ShopMaterialHighlight {
  const ShopMaterialHighlight({
    required this.material,
    required this.tagline,
    required this.startingPrice,
    required this.leadTimeLabel,
    this.badge,
    this.recommendationReason,
  });

  final catalog.Material material;
  final String tagline;
  final Money startingPrice;
  final String leadTimeLabel;
  final String? badge;
  final String? recommendationReason;
}

class ShopGuideLink {
  const ShopGuideLink({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.targetRoute,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String targetRoute;
}

class ShopCategoriesProvider extends AsyncProvider<List<ShopCategory>> {
  ShopCategoriesProvider() : super.args(null, autoDispose: true);

  @override
  Future<List<ShopCategory>> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    return _seedCategories(gates);
  }
}

final shopCategoriesProvider = ShopCategoriesProvider();

class ShopPromotionsProvider
    extends AsyncProvider<List<ShopPromotionHighlight>> {
  ShopPromotionsProvider() : super.args(null, autoDispose: true);

  @override
  Future<List<ShopPromotionHighlight>> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final items = _seedPromotions(gates);
    items.shuffle(Random(gates.persona.index + 3));
    return items;
  }
}

final shopPromotionsProvider = ShopPromotionsProvider();

class ShopMaterialRecommendationsProvider
    extends AsyncProvider<List<ShopMaterialHighlight>> {
  ShopMaterialRecommendationsProvider() : super.args(null, autoDispose: true);

  @override
  Future<List<ShopMaterialHighlight>> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 170));
    return _seedMaterialPicks(gates);
  }
}

final shopMaterialRecommendationsProvider =
    ShopMaterialRecommendationsProvider();

class ShopGuideLinksProvider extends AsyncProvider<List<ShopGuideLink>> {
  ShopGuideLinksProvider() : super.args(null, autoDispose: true);

  @override
  Future<List<ShopGuideLink>> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    return _seedGuideLinks(gates);
  }
}

final shopGuideLinksProvider = ShopGuideLinksProvider();

List<ShopCategory> _seedCategories(AppExperienceGates gates) {
  final prefersEnglish = gates.prefersEnglish;

  return [
    ShopCategory(
      id: 'titanium',
      title: prefersEnglish ? 'Titanium' : 'チタン',
      description: prefersEnglish
          ? 'Durable, light, hypoallergenic'
          : '軽くて丈夫、金属アレルギー対応',
      icon: Icons.shield_outlined,
      imageUrl:
          'https://images.unsplash.com/photo-1439396087961-98bc12c21176?auto=format&fit=crop&w=1200&q=60',
      targetRoute: '/materials/titanium-matte',
      accent: const Color(0xFF9BB8D3),
      badge: prefersEnglish ? 'Popular' : '人気',
    ),
    ShopCategory(
      id: 'horn',
      title: prefersEnglish ? 'Buffalo horn' : '牛角',
      description: prefersEnglish ? 'Deep gloss, warm tone' : '深い艶と温かみのある色合い',
      icon: Icons.brightness_5_outlined,
      imageUrl:
          'https://images.unsplash.com/photo-1504595403659-9088ce801e29?auto=format&fit=crop&w=1200&q=60',
      targetRoute: '/materials/horn-premium',
      accent: const Color(0xFFD1A054),
      badge: prefersEnglish ? 'Traditional' : '定番',
    ),
    ShopCategory(
      id: 'wood',
      title: prefersEnglish ? 'Wood / Sakura' : '木材・さくら',
      description: prefersEnglish
          ? 'Soft touch, eco friendly'
          : 'やわらかい押し心地と環境配慮',
      icon: Icons.park_outlined,
      imageUrl:
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
      targetRoute: '/materials/sakura-wood',
      accent: const Color(0xFFC48B9F),
    ),
    ShopCategory(
      id: 'acrylic',
      title: prefersEnglish ? 'Acrylic / Color' : 'アクリル・カラー',
      description: prefersEnglish
          ? 'Transparent, playful colors'
          : '透明感とカラーバリエーション',
      icon: Icons.color_lens_outlined,
      imageUrl:
          'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=1200&q=60',
      targetRoute: '/materials/color-acrylic',
      accent: const Color(0xFF8BC8DB),
    ),
  ];
}

List<ShopPromotionHighlight> _seedPromotions(AppExperienceGates gates) {
  final prefersEnglish = gates.prefersEnglish;
  final intl = gates.emphasizeInternationalFlows;

  return [
    ShopPromotionHighlight(
      id: 'spring-bundle',
      badge: prefersEnglish ? 'Bundle' : 'まとめ買い',
      title: prefersEnglish ? 'Spring starter bundle' : '春のスターターセット',
      description: prefersEnglish
          ? 'Save on a full kit with case, ink, and free engraving tweaks.'
          : 'ケース・朱肉・深彫り調整がセットでお得。',
      imageUrl:
          'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=1200&q=60',
      actionLabel: prefersEnglish ? 'View bundle' : 'セットを見る',
      targetRoute: '/products/round-classic',
      code: 'SPRING24',
      discountPercent: 12,
    ),
    ShopPromotionHighlight(
      id: 'intl-fast-track',
      badge: prefersEnglish ? 'Fast lane' : '特急',
      title: prefersEnglish ? 'International fast track' : '海外配送優先',
      description: prefersEnglish
          ? 'DHL slot reservation with bilingual template support.'
          : 'DHL優先枠 + バイリンガルテンプレ付き。',
      imageUrl:
          'https://images.unsplash.com/photo-1541417904950-b855846fe074?auto=format&fit=crop&w=1200&q=60',
      actionLabel: prefersEnglish ? 'Reserve slot' : '枠を予約',
      targetRoute: '/checkout/shipping',
      code: intl ? 'INTLFAST' : 'SHIPFAST',
      discountPercent: intl ? 15 : 8,
      limitedTime: true,
    ),
    ShopPromotionHighlight(
      id: 'eco-upgrade',
      badge: prefersEnglish ? 'Eco' : '環境配慮',
      title: prefersEnglish ? 'Eco upgrade credit' : 'エコ素材アップグレード',
      description: prefersEnglish
          ? 'Switch to recycled titanium or FSC wood and earn points.'
          : 'リサイクルチタン/FSC材に変更でポイント付与。',
      imageUrl:
          'https://images.unsplash.com/photo-1473186578172-c141e6798cf4?auto=format&fit=crop&w=1200&q=60',
      actionLabel: prefersEnglish ? 'Apply credit' : '適用する',
      targetRoute: '/cart',
      code: 'ECOPOINT',
    ),
  ];
}

List<ShopMaterialHighlight> _seedMaterialPicks(AppExperienceGates gates) {
  final now = DateTime.now();
  final prefersEnglish = gates.prefersEnglish;
  final intl = gates.emphasizeInternationalFlows;

  final titanium = catalog.Material(
    id: 'titanium-matte',
    name: prefersEnglish ? 'Matte titanium' : 'マットチタン',
    type: catalog.MaterialType.titanium,
    finish: catalog.MaterialFinish.matte,
    color: 'Silver',
    hardness: 6.0,
    density: 4.5,
    careNotes: prefersEnglish
        ? 'Wipe after use; no rust, hypoallergenic.'
        : '使用後は軽く拭き取り。錆びず金属アレルギー対応。',
    photos: const [
      'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1000&q=60',
    ],
    sustainability: const catalog.Sustainability(
      certifications: ['Recycled 30%'],
      notes: 'Low waste machining',
    ),
    isActive: true,
    createdAt: now.subtract(const Duration(days: 190)),
  );

  final horn = catalog.Material(
    id: 'horn-premium',
    name: prefersEnglish ? 'Premium horn' : '本牛角 プレミアム',
    type: catalog.MaterialType.horn,
    finish: catalog.MaterialFinish.gloss,
    color: prefersEnglish ? 'Amber' : '琥珀色',
    hardness: 2.8,
    density: 1.3,
    careNotes: prefersEnglish ? 'Store dry; avoid heat.' : '高温を避け、乾いた場所で保管。',
    photos: const [
      'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1000&q=60',
    ],
    sustainability: const catalog.Sustainability(
      certifications: ['Responsible sourced'],
    ),
    isActive: true,
    createdAt: now.subtract(const Duration(days: 420)),
  );

  final wood = catalog.Material(
    id: 'sakura-wood',
    name: prefersEnglish ? 'Sakura wood' : 'さくら材',
    type: catalog.MaterialType.wood,
    finish: catalog.MaterialFinish.matte,
    color: prefersEnglish ? 'Natural pink' : '桜色',
    hardness: 2.1,
    density: 0.9,
    careNotes: prefersEnglish
        ? 'Avoid moisture; re-oil yearly.'
        : '湿気を避け、年に1度オイルで手入れ。',
    photos: const [
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1000&q=60',
    ],
    sustainability: const catalog.Sustainability(certifications: ['FSC']),
    isActive: true,
    createdAt: now.subtract(const Duration(days: 260)),
  );

  return [
    ShopMaterialHighlight(
      material: titanium,
      badge: prefersEnglish ? 'Fast shipping' : '短納期',
      tagline: prefersEnglish ? 'Clean edges, light feel' : 'シャープな印影と軽さ',
      startingPrice: const Money(amount: 11800, currency: 'JPY'),
      leadTimeLabel: intl ? '3-4 business days DHL' : '国内3-4営業日発送',
      recommendationReason: prefersEnglish
          ? 'Best for bilingual/company seals'
          : '社名・英字におすすめ',
    ),
    ShopMaterialHighlight(
      material: horn,
      badge: prefersEnglish ? 'Classic' : '格上げ',
      tagline: prefersEnglish ? 'Rich texture and depth' : '艶のある存在感',
      startingPrice: const Money(amount: 9800, currency: 'JPY'),
      leadTimeLabel: prefersEnglish ? '5-6 business days' : '5-6営業日仕上げ',
      recommendationReason: prefersEnglish
          ? 'Pairs well with Tensho templates'
          : '篆書テンプレと相性◎',
    ),
    ShopMaterialHighlight(
      material: wood,
      badge: prefersEnglish ? 'Eco' : 'やさしい',
      tagline: prefersEnglish ? 'Warm feel with soft press' : 'やわらかい押し心地',
      startingPrice: const Money(amount: 7200, currency: 'JPY'),
      leadTimeLabel: prefersEnglish ? '4-5 business days' : '4-5営業日仕上げ',
      recommendationReason: prefersEnglish
          ? 'Safe for bank-in / everyday use'
          : '銀行印・日常使いに安心',
    ),
  ];
}

List<ShopGuideLink> _seedGuideLinks(AppExperienceGates gates) {
  final prefersEnglish = gates.prefersEnglish;

  return [
    ShopGuideLink(
      id: 'size-guide',
      title: prefersEnglish ? 'Size guide' : 'サイズの選び方',
      subtitle: prefersEnglish
          ? 'Pick the right diameter by usage and role.'
          : '用途・役職別のおすすめサイズ。',
      icon: Icons.straighten_rounded,
      targetRoute: '${AppRoutePaths.profile}/guides/size',
    ),
    ShopGuideLink(
      id: 'material-care',
      title: prefersEnglish ? 'Material care' : '素材のお手入れ',
      subtitle: prefersEnglish
          ? 'Keep gloss, avoid warping, and store safely.'
          : '艶を保ち反りを防ぐ保管ポイント。',
      icon: Icons.cleaning_services_outlined,
      targetRoute: '${AppRoutePaths.profile}/guides/material-care',
    ),
    ShopGuideLink(
      id: 'culture',
      title: prefersEnglish ? 'Cultural tips' : '印鑑文化のミニガイド',
      subtitle: prefersEnglish
          ? "Dos and don'ts for gifting or ceremonies."
          : '贈答や儀礼でのマナーを短く解説。',
      icon: Icons.library_books_outlined,
      targetRoute: '${AppRoutePaths.profile}/guides/culture-basics',
    ),
  ];
}
