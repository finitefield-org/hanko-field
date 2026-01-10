// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

class HomeFeaturedItem {
  const HomeFeaturedItem({
    required this.id,
    required this.title,
    required this.body,
    required this.badge,
    required this.imageUrl,
    required this.actionLabel,
    required this.targetRoute,
    this.tagline,
    this.weight = 1,
  });

  final String id;
  final String title;
  final String body;
  final String badge;
  final String imageUrl;
  final String actionLabel;
  final String targetRoute;
  final String? tagline;
  final double weight;
}

class RecommendedTemplate {
  const RecommendedTemplate({
    required this.template,
    required this.reason,
    required this.score,
  });

  final Template template;
  final String reason;
  final double score;
}

class HomeFeaturedProvider extends AsyncProvider<List<HomeFeaturedItem>> {
  HomeFeaturedProvider() : super.args(null, autoDispose: true);

  @override
  Future<List<HomeFeaturedItem>> build(
    Ref<AsyncValue<List<HomeFeaturedItem>>> ref,
  ) async {
    final gates = ref.watch(appExperienceGatesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final campaigns = List<HomeFeaturedItem>.of(_featuredCampaigns(gates));
    campaigns.sort(
      (a, b) => _scoreFeatured(b, gates).compareTo(_scoreFeatured(a, gates)),
    );
    return campaigns;
  }
}

final homeFeaturedProvider = HomeFeaturedProvider();

class HomeRecentDesignsProvider extends AsyncProvider<List<Design>> {
  HomeRecentDesignsProvider() : super.args(null, autoDispose: true);

  @override
  Future<List<Design>> build(Ref<AsyncValue<List<Design>>> ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    final session = ref.watch(userSessionProvider).valueOrNull;
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return _seedRecentDesigns(gates, session);
  }
}

final homeRecentDesignsProvider = HomeRecentDesignsProvider();

class HomeRecommendedTemplatesProvider
    extends AsyncProvider<List<RecommendedTemplate>> {
  HomeRecommendedTemplatesProvider() : super.args(null, autoDispose: true);

  @override
  Future<List<RecommendedTemplate>> build(
    Ref<AsyncValue<List<RecommendedTemplate>>> ref,
  ) async {
    final gates = ref.watch(appExperienceGatesProvider);
    final recents = await ref.watch(homeRecentDesignsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final templates = _seedTemplates(gates);
    final scored = templates.map((template) {
      final score = _scoreTemplate(template, gates, recents);
      final reason = _reasonForTemplate(template, gates, recents);
      return RecommendedTemplate(
        template: template,
        reason: reason,
        score: score,
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    return scored;
  }
}

final homeRecommendedTemplatesProvider = HomeRecommendedTemplatesProvider();

List<HomeFeaturedItem> _featuredCampaigns(AppExperienceGates gates) {
  final prefersEnglish = gates.prefersEnglish;
  final intl = gates.emphasizeInternationalFlows;

  return [
    HomeFeaturedItem(
      id: 'intl-onboarding',
      title: prefersEnglish ? 'International-friendly kits' : '外国人サポート特集',
      body: prefersEnglish
          ? 'Roman alphabet guidance, DHL配送の優先枠をまとめたスターターキット。'
          : 'ローマ字ガイドやDHL優先枠付きのスターターセット。',
      badge: prefersEnglish ? 'Featured' : '特集',
      tagline: intl ? 'EN/JA bilingual tips' : 'おすすめテンプレ付き',
      imageUrl:
          'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=1200&q=60',
      actionLabel: prefersEnglish ? 'Browse kit' : 'スターターを見る',
      targetRoute: AppRoutePaths.designNew,
      weight: intl ? 1.4 : 1.0,
    ),
    HomeFeaturedItem(
      id: 'jp-registrability',
      title: prefersEnglish ? 'Registrability-first templates' : '実印チェック優先',
      body: prefersEnglish
          ? '篆書ベースで公的手続きに強いテンプレートをまとめました。'
          : '公的手続きで安心な篆書テンプレートを厳選。',
      badge: prefersEnglish ? 'Official' : '公的手続き',
      tagline: prefersEnglish ? 'Jitsuin / bank-ready' : '実印・銀行印OK',
      imageUrl:
          'https://images.unsplash.com/photo-1455849318743-b2233052fcff?auto=format&fit=crop&w=1200&q=60',
      actionLabel: prefersEnglish ? 'See templates' : 'テンプレートを見る',
      targetRoute: AppRoutePaths.designStyle,
      weight: gates.enableRegistrabilityCheck ? 1.5 : 1.0,
    ),
    HomeFeaturedItem(
      id: 'ai-refinement',
      title: prefersEnglish ? 'AI refinement' : 'AI 仕上げ提案',
      body: prefersEnglish
          ? 'にじみ・太さを自動で補正。1タップで候補比較できます。'
          : 'にじみ/太さをAIで補正して候補を比較できます。',
      badge: 'AI',
      tagline: prefersEnglish ? 'Fast previews' : 'プレビュー付き',
      imageUrl:
          'https://images.unsplash.com/photo-1508602639530-96c859f6b2f5?auto=format&fit=crop&w=1200&q=60',
      actionLabel: prefersEnglish ? 'Open AI suggestions' : 'AI提案を見る',
      targetRoute: AppRoutePaths.designAi,
      weight: 1.1,
    ),
  ];
}

double _scoreFeatured(HomeFeaturedItem item, AppExperienceGates gates) {
  var score = item.weight;
  if (item.id == 'intl-onboarding' && gates.emphasizeInternationalFlows) {
    score += 1.2;
  }
  if (item.id == 'jp-registrability' && gates.enableRegistrabilityCheck) {
    score += 1;
  }
  if (gates.isAuthenticated) {
    score += 0.2;
  }
  return score;
}

List<Design> _seedRecentDesigns(
  AppExperienceGates gates,
  UserSession? session,
) {
  final now = DateTime.now();
  final ownerRef = session?.user?.uid ?? 'guest';
  final prefersEnglish = gates.prefersEnglish;
  final useRound = gates.isJapanRegion;

  final primaryName = prefersEnglish ? 'Alex Sato' : '佐藤 太郎';
  final secondName = prefersEnglish ? 'Invoice Seal' : '領収書用';
  final thirdName = prefersEnglish ? 'Project mark' : '案件用スタンプ';

  return [
    Design(
      id: 'd-home-primary',
      ownerRef: ownerRef,
      status: DesignStatus.ready,
      input: DesignInput(
        sourceType: DesignSourceType.typed,
        rawName: primaryName,
        kanji: gates.enableKanjiAssist
            ? const KanjiMapping(value: '佐藤', mappingRef: 'sato')
            : null,
      ),
      shape: useRound ? SealShape.round : SealShape.square,
      size: DesignSize(mm: useRound ? 15.0 : 18.0),
      style: DesignStyle(
        writing: prefersEnglish ? WritingStyle.kaisho : WritingStyle.tensho,
        templateRef: 'classic-red',
        stroke: const StrokeConfig(weight: 0.52),
        layout: const LayoutConfig(grid: 'balanced', margin: 1.4),
      ),
      ai: const AiMetadata(
        enabled: true,
        qualityScore: 0.92,
        registrable: true,
      ),
      assets: const DesignAssets(
        previewPngUrl:
            'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=600&q=60',
        stampMockUrl:
            'https://images.unsplash.com/photo-1506634064465-1c59a0b9f9ed?auto=format&fit=crop&w=400&q=60',
      ),
      version: 3,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 5)),
      lastOrderedAt: now.subtract(const Duration(days: 1)),
    ),
    Design(
      id: 'd-home-invoice',
      ownerRef: ownerRef,
      status: DesignStatus.ordered,
      input: DesignInput(
        sourceType: DesignSourceType.logo,
        rawName: secondName,
      ),
      shape: useRound ? SealShape.round : SealShape.square,
      size: const DesignSize(mm: 16.5),
      style: const DesignStyle(
        writing: WritingStyle.reisho,
        templateRef: 'tensho-bronze',
        stroke: StrokeConfig(weight: 0.48, contrast: 0.12),
        layout: LayoutConfig(grid: 'tight', margin: 1.1),
      ),
      ai: const AiMetadata(
        enabled: true,
        lastJobRef: 'job_recent_invoice',
        qualityScore: 0.88,
        registrable: true,
      ),
      assets: const DesignAssets(
        previewPngUrl:
            'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=500&q=60',
      ),
      version: 2,
      createdAt: now.subtract(const Duration(days: 8)),
      updatedAt: now.subtract(const Duration(days: 1)),
      lastOrderedAt: now.subtract(const Duration(days: 3)),
    ),
    Design(
      id: 'd-home-project',
      ownerRef: ownerRef,
      status: DesignStatus.draft,
      input: DesignInput(
        sourceType: DesignSourceType.uploaded,
        rawName: thirdName,
      ),
      shape: useRound ? SealShape.round : SealShape.square,
      size: const DesignSize(mm: 14.0),
      style: const DesignStyle(
        writing: WritingStyle.koentai,
        templateRef: 'grid-etched',
        stroke: StrokeConfig(weight: 0.4),
        layout: LayoutConfig(grid: 'centered', margin: 1.2),
      ),
      ai: const AiMetadata(
        enabled: false,
        registrable: false,
        diagnostics: ['ストロークが細めです'],
      ),
      assets: const DesignAssets(
        previewPngUrl:
            'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=500&q=60',
      ),
      version: 1,
      createdAt: now.subtract(const Duration(days: 14)),
      updatedAt: now.subtract(const Duration(days: 5)),
    ),
  ];
}

List<Template> _seedTemplates(AppExperienceGates gates) {
  final now = DateTime.now();
  final prefersEnglish = gates.prefersEnglish;

  return [
    Template(
      id: 'tensho-classic',
      name: prefersEnglish ? 'Tensho classic' : '篆書クラシック',
      slug: 'tensho-classic',
      description: prefersEnglish
          ? 'Deep red outline with balanced margin for official seals.'
          : '朱肉映えする余白バランスの篆書テンプレ。',
      tags: const ['official', 'balanced'],
      shape: SealShape.round,
      writing: WritingStyle.tensho,
      defaults: const TemplateDefaults(
        sizeMm: 15,
        stroke: TemplateStrokeDefaults(weight: 0.52),
        layout: TemplateLayoutDefaults(grid: 'balanced', margin: 1.4),
      ),
      constraints: const TemplateConstraints(
        sizeMm: SizeConstraint(min: 12, max: 18, step: 0.5),
        strokeWeight: RangeConstraint(min: 0.35, max: 0.78),
        registrability: RegistrabilityHint(jpJitsuinAllowed: true),
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=600&q=60',
      exampleImages: const [],
      recommendations: const TemplateRecommendations(
        defaultSizeMm: 15,
        materialRefs: ['akamatsu'],
        productRefs: ['round-classic'],
      ),
      isPublic: true,
      sort: 10,
      version: '1.0.0',
      isDeprecated: false,
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Template(
      id: 'modern-square',
      name: prefersEnglish ? 'Modern square' : 'モダン角印',
      slug: 'modern-square',
      description: prefersEnglish
          ? 'Square layout with gentle contrast for bilingual names.'
          : 'ローマ字でも映える角印レイアウト。',
      tags: const ['international', 'square'],
      shape: SealShape.square,
      writing: WritingStyle.kaisho,
      defaults: const TemplateDefaults(
        sizeMm: 18,
        stroke: TemplateStrokeDefaults(weight: 0.46),
        layout: TemplateLayoutDefaults(
          grid: 'grid',
          margin: 1.1,
          centerBias: 0.12,
        ),
      ),
      constraints: const TemplateConstraints(
        sizeMm: SizeConstraint(min: 15, max: 21, step: 0.5),
        strokeWeight: RangeConstraint(min: 0.3, max: 0.62),
        registrability: RegistrabilityHint(
          jpJitsuinAllowed: false,
          bankInAllowed: true,
        ),
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=600&q=60',
      exampleImages: const [],
      recommendations: const TemplateRecommendations(
        defaultSizeMm: 18,
        materialRefs: ['beech'],
        productRefs: ['square-modern'],
      ),
      isPublic: true,
      sort: 20,
      version: '1.1.0',
      isDeprecated: false,
      createdAt: now.subtract(const Duration(days: 45)),
      updatedAt: now.subtract(const Duration(days: 4)),
    ),
    Template(
      id: 'engraved-bold',
      name: prefersEnglish ? 'Engraved bold' : '深彫りボールド',
      slug: 'engraved-bold',
      description: prefersEnglish
          ? 'Thicker strokes for soft materials, easy to align.'
          : 'やわらかい素材でも潰れにくい太めストローク。',
      tags: const ['bold', 'easy'],
      shape: SealShape.round,
      writing: WritingStyle.koentai,
      defaults: const TemplateDefaults(
        sizeMm: 16,
        stroke: TemplateStrokeDefaults(weight: 0.64, contrast: 0.1),
        layout: TemplateLayoutDefaults(grid: 'centered', margin: 1.2),
        fontRef: 'koentai-a',
      ),
      constraints: const TemplateConstraints(
        sizeMm: SizeConstraint(min: 13, max: 19, step: 0.5),
        strokeWeight: RangeConstraint(min: 0.46, max: 0.75),
        margin: RangeConstraint(min: 0.8, max: 1.6),
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=600&q=60',
      exampleImages: const [],
      recommendations: const TemplateRecommendations(
        defaultSizeMm: 16,
        materialRefs: ['sakura'],
      ),
      isPublic: true,
      sort: 30,
      version: '1.0.1',
      isDeprecated: false,
      createdAt: now.subtract(const Duration(days: 70)),
      updatedAt: now.subtract(const Duration(days: 7)),
    ),
  ];
}

double _scoreTemplate(
  Template template,
  AppExperienceGates gates,
  List<Design> recents,
) {
  var score = 1 + template.sort / 100;
  final last = recents.isNotEmpty ? recents.first : null;

  if (last != null) {
    if (last.shape == template.shape) score += 1.2;
    if (last.style.writing == template.writing) score += 0.8;
    final delta = (last.size.mm - (template.defaults?.sizeMm ?? last.size.mm))
        .abs()
        .clamp(0, 4);
    score += max(0, 0.6 - delta * 0.1);
  }

  if (gates.enableRegistrabilityCheck &&
      template.constraints.registrability?.jpJitsuinAllowed == true) {
    score += 0.6;
  }

  if (gates.emphasizeInternationalFlows && template.shape == SealShape.square) {
    score += 0.4;
  }

  return score;
}

String _reasonForTemplate(
  Template template,
  AppExperienceGates gates,
  List<Design> recents,
) {
  final prefersEnglish = gates.prefersEnglish;
  final last = recents.isNotEmpty ? recents.first : null;
  final shapeLabel = template.shape == SealShape.round
      ? (prefersEnglish ? 'round' : '丸')
      : (prefersEnglish ? 'square' : '角');
  final writingLabel = switch (template.writing) {
    WritingStyle.tensho => prefersEnglish ? 'Tensho' : '篆書',
    WritingStyle.reisho => prefersEnglish ? 'Reisho' : '隷書',
    WritingStyle.kaisho => prefersEnglish ? 'Kaisho' : '楷書',
    WritingStyle.gyosho => prefersEnglish ? 'Gyosho' : '行書',
    WritingStyle.koentai => prefersEnglish ? 'Koentai' : '古印体',
    WritingStyle.custom => prefersEnglish ? 'Custom' : 'カスタム',
  };

  if (last != null && last.shape == template.shape) {
    return prefersEnglish
        ? 'Matches your recent $shapeLabel seal for easy reuse'
        : '最近の$shapeLabel印と揃えやすいレイアウト';
  }

  if (template.constraints.registrability?.jpJitsuinAllowed == true &&
      gates.enableRegistrabilityCheck) {
    return prefersEnglish ? 'Ready for registrability checks' : '実印チェック向けの設定です';
  }

  if (template.shape == SealShape.square && gates.emphasizeInternationalFlows) {
    return prefersEnglish
        ? 'Good balance for bilingual/company names'
        : '英字/社名でも収まりやすい角印';
  }

  return prefersEnglish
      ? '$writingLabel style with guided margins'
      : '$writingLabel ベースの見やすい余白';
}
