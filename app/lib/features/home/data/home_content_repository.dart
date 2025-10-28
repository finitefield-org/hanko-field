import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/features/home/domain/home_content.dart';

abstract class HomeContentRepository {
  Future<HomeUsageInsights> loadUsageInsights({
    required ExperienceGate experience,
  });

  Future<List<HomeFeaturedItem>> loadFeaturedItems({
    required ExperienceGate experience,
    required HomeUsageInsights usage,
  });

  Future<List<HomeRecentDesign>> loadRecentDesigns({
    required ExperienceGate experience,
    required HomeUsageInsights usage,
  });

  Future<List<HomeTemplateRecommendation>> loadTemplateRecommendations({
    required ExperienceGate experience,
    required HomeUsageInsights usage,
  });
}

class FakeHomeContentRepository implements HomeContentRepository {
  const FakeHomeContentRepository();

  @override
  Future<HomeUsageInsights> loadUsageInsights({
    required ExperienceGate experience,
  }) async {
    await _simulateLatency();
    final persona = experience.persona;
    final hasRecentDesigns = persona == UserPersona.japanese;
    final now = DateTime.now();

    return HomeUsageInsights(
      recentDesignCount: hasRecentDesigns ? 3 : 1,
      lastDesignInteractionAt: hasRecentDesigns
          ? now.subtract(const Duration(days: 2))
          : null,
      recommendedTemplateInteractionCount: persona == UserPersona.foreigner
          ? 0
          : 2,
      lastEngagedSection: persona == UserPersona.foreigner
          ? HomeSectionType.templates
          : HomeSectionType.recents,
    );
  }

  @override
  Future<List<HomeFeaturedItem>> loadFeaturedItems({
    required ExperienceGate experience,
    required HomeUsageInsights usage,
  }) async {
    await _simulateLatency();
    if (experience.persona == UserPersona.foreigner) {
      return _internationalFeatured(experience);
    }
    return _domesticFeatured(experience);
  }

  @override
  Future<List<HomeRecentDesign>> loadRecentDesigns({
    required ExperienceGate experience,
    required HomeUsageInsights usage,
  }) async {
    await _simulateLatency();
    if (usage.recentDesignCount == 0) {
      return const [];
    }
    final now = DateTime.now();
    return [
      HomeRecentDesign(
        id: 'JP-INK-01',
        title: '山田 太郎',
        updatedAt: now.subtract(const Duration(days: 1, hours: 3)),
        status: DesignStatus.ready,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=640',
        sourceType: DesignSourceType.typed,
      ),
      HomeRecentDesign(
        id: 'JP-INK-02',
        title: 'はんこ屋 花子',
        updatedAt: now.subtract(const Duration(days: 5, hours: 2)),
        status: DesignStatus.draft,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1520256862855-398228c41684?w=640',
        sourceType: DesignSourceType.logo,
      ),
      HomeRecentDesign(
        id: 'JP-INK-03',
        title: '合同会社 彩',
        updatedAt: now.subtract(const Duration(days: 12)),
        status: DesignStatus.ordered,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1461695008884-25175c8a2601?w=640',
        sourceType: DesignSourceType.uploaded,
      ),
    ];
  }

  @override
  Future<List<HomeTemplateRecommendation>> loadTemplateRecommendations({
    required ExperienceGate experience,
    required HomeUsageInsights usage,
  }) async {
    await _simulateLatency();
    if (experience.persona == UserPersona.foreigner) {
      return _internationalTemplates();
    }
    return _domesticTemplates(experience);
  }

  List<HomeFeaturedItem> _domesticFeatured(ExperienceGate experience) {
    return [
      HomeFeaturedItem(
        id: 'campaign-newyears',
        title: '新春キャンペーン',
        subtitle: '干支モチーフと朱肉ケースをセットで20%オフ',
        imageUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1200',
        ctaLabel: '詳しく見る',
        badgeLabel: '期間限定',
        destination: HomeContentDestination(
          route: ShopDetailRoute(entity: 'products', identifier: 'seal-001'),
          overrideTab: AppTab.shop,
        ),
      ),
      HomeFeaturedItem(
        id: 'campaign-business-hanko',
        title: 'ビジネス印影テンプレート',
        subtitle: '法人登記に最適な丸印テンプレートを厳選しました。',
        imageUrl:
            'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?w=1200',
        ctaLabel: '作成をはじめる',
        destination: HomeContentDestination(
          route: CreationStageRoute(const ['new']),
        ),
      ),
      HomeFeaturedItem(
        id: 'campaign-export',
        title: '印影データのエクスポート',
        subtitle: 'SVG／PNG書き出しでオンライン取引にも対応。',
        imageUrl:
            'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=1200',
        ctaLabel: 'エクスポート方法を見る',
        destination: HomeContentDestination(
          route: LibraryEntryRoute(
            designId: 'JP-INK-03',
            trailing: const ['export'],
          ),
          overrideTab: AppTab.library,
        ),
      ),
    ];
  }

  List<HomeFeaturedItem> _internationalFeatured(ExperienceGate experience) {
    return [
      HomeFeaturedItem(
        id: 'campaign-kanji-guide',
        title: 'Kanji Mapper Walkthrough',
        subtitle:
            'Learn how to match your name to the best fitting kanji with cultural notes.',
        imageUrl:
            'https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?w=1200',
        ctaLabel: 'Start Tutorial',
        badgeLabel: 'New',
        destination: HomeContentDestination(
          route: CreationStageRoute(const ['input', 'kanji-map']),
        ),
      ),
      const HomeFeaturedItem(
        id: 'campaign-global-shipping',
        title: 'Worldwide Shipping Timeline',
        subtitle:
            'Track your seal production milestones and customs events in one place.',
        imageUrl:
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1200',
        ctaLabel: 'View shipping tips',
        destination: HomeContentDestination(route: NotificationsRoute()),
      ),
      HomeFeaturedItem(
        id: 'campaign-template-showcase',
        title: 'Recommended styles for your persona',
        subtitle:
            'River-inspired circle templates optimized for romanised names.',
        imageUrl:
            'https://images.unsplash.com/photo-1521579971123-1192931a1452?w=1200',
        ctaLabel: 'Browse templates',
        destination: HomeContentDestination(
          route: CreationStageRoute(const ['style']),
        ),
      ),
    ];
  }

  List<HomeTemplateRecommendation> _domesticTemplates(
    ExperienceGate experience,
  ) {
    return [
      HomeTemplateRecommendation(
        id: 'tpl-round-classic',
        title: '丸印クラシック',
        description: '銀行印・実印に最適な天書体の丸印テンプレート。',
        shape: DesignShape.round,
        writingStyle: DesignWritingStyle.tensho,
        previewUrl:
            'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=640',
        highlightLabel: '人気',
        destination: HomeContentDestination(
          route: CreationStageRoute(const ['style']),
        ),
      ),
      HomeTemplateRecommendation(
        id: 'tpl-square-modern',
        title: '角印モダン',
        description: '会社認印におすすめのレイアウトと余白バランス。',
        shape: DesignShape.square,
        writingStyle: DesignWritingStyle.kaisho,
        previewUrl:
            'https://images.unsplash.com/photo-1503602642458-232111445657?w=640',
        destination: HomeContentDestination(
          route: CreationStageRoute(const ['style']),
        ),
      ),
      HomeTemplateRecommendation(
        id: 'tpl-round-engrave',
        title: '浮き彫り仕上げ',
        description: '朱肉でも鮮明に映える線幅に自動調整します。',
        shape: DesignShape.round,
        writingStyle: DesignWritingStyle.reisho,
        previewUrl:
            'https://images.unsplash.com/photo-1526778548025-fa2f459cd5c1?w=640',
        destination: HomeContentDestination(
          route: CreationStageRoute(const ['editor']),
        ),
      ),
    ];
  }

  List<HomeTemplateRecommendation> _internationalTemplates() {
    return [
      HomeTemplateRecommendation(
        id: 'tpl-roman-round',
        title: 'Romanised Circle',
        description:
            'Balanced template designed for roman letters in round seals.',
        shape: DesignShape.round,
        writingStyle: DesignWritingStyle.custom,
        previewUrl:
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=640',
        highlightLabel: 'Easy start',
        destination: HomeContentDestination(
          route: CreationStageRoute(const ['new']),
        ),
      ),
      HomeTemplateRecommendation(
        id: 'tpl-kanji-river',
        title: 'River Kanji',
        description: 'Flowing strokes with cultural notes for gift seals.',
        shape: DesignShape.round,
        writingStyle: DesignWritingStyle.gyosho,
        previewUrl:
            'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=640',
        destination: HomeContentDestination(
          route: CreationStageRoute(const ['style']),
        ),
      ),
      HomeTemplateRecommendation(
        id: 'tpl-initial-square',
        title: 'Initial Square',
        description: 'Square layout optimized for short names and initials.',
        shape: DesignShape.square,
        writingStyle: DesignWritingStyle.custom,
        previewUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=640',
        destination: HomeContentDestination(
          route: CreationStageRoute(const ['editor']),
        ),
      ),
    ];
  }

  Future<void> _simulateLatency() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
  }
}
