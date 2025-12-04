// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/search/data/search_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';

class SearchIndex {
  SearchIndex({required this.gates});

  final AppExperienceGates gates;

  late final List<Template> _templates = _buildTemplates();
  late final List<Material> _materials = _buildMaterials();
  late final List<Guide> _articles = _buildArticles();
  late final List<Guide> _faqs = _buildFaqs();

  List<SearchSuggestion> suggestionsFor(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    final prefersEnglish = gates.prefersEnglish;
    final base = <SearchSuggestion>[
      ..._templates.map(
        (t) => SearchSuggestion(
          label: t.name,
          context: prefersEnglish ? 'Template' : 'テンプレート',
          segment: SearchSegment.templates,
        ),
      ),
      ..._materials.map(
        (m) => SearchSuggestion(
          label: m.name,
          context: prefersEnglish ? 'Material' : '素材',
          segment: SearchSegment.materials,
        ),
      ),
      ..._articles.map(
        (g) => SearchSuggestion(
          label: _titleFor(g),
          context: prefersEnglish ? 'Guide' : '記事',
          segment: SearchSegment.articles,
        ),
      ),
      ..._faqs.map(
        (g) => SearchSuggestion(
          label: _titleFor(g),
          context: 'FAQ',
          segment: SearchSegment.faq,
        ),
      ),
      SearchSuggestion(
        label: prefersEnglish ? 'Voice search' : '音声で探す',
        context: prefersEnglish ? 'Coming soon' : '近日追加',
      ),
    ];

    if (query.isEmpty) {
      return base.take(6).toList();
    }

    final scored =
        base
            .map((s) => (score: _scoreMatch(s.label, query), suggestion: s))
            .where((tuple) => tuple.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(6).map((t) => t.suggestion).toList();
  }

  List<String> seedHistory() {
    if (gates.prefersEnglish) {
      return const ['bank seal', 'square template', 'quick reorder'];
    }
    return const ['銀行印 角印', '実印チェック', '素材の違い'];
  }

  Page<TemplateSearchHit> searchTemplates(
    String rawQuery, {
    String? pageToken,
  }) {
    final query = rawQuery.trim().toLowerCase();
    final hits =
        _templates
            .map(
              (template) => (
                score: _scoreTemplate(template, query),
                hit: TemplateSearchHit(
                  template: template,
                  reason: _reasonForTemplate(template, query),
                ),
              ),
            )
            .where((tuple) => tuple.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final items = hits.map((tuple) => tuple.hit).toList();
    return _page(items, pageToken: pageToken);
  }

  Page<MaterialSearchHit> searchMaterials(
    String rawQuery, {
    String? pageToken,
  }) {
    final query = rawQuery.trim().toLowerCase();

    final hits =
        _materials
            .map(
              (material) => (
                score: _scoreMaterial(material, query),
                hit: MaterialSearchHit(
                  material: material,
                  summary: _summaryForMaterial(material),
                  badge: _badgeForMaterial(material),
                ),
              ),
            )
            .where((tuple) => tuple.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final items = hits.map((tuple) => tuple.hit).toList();
    return _page(items, pageToken: pageToken);
  }

  Page<ArticleSearchHit> searchArticles(String rawQuery, {String? pageToken}) {
    final query = rawQuery.trim().toLowerCase();
    final hits = <({double score, ArticleSearchHit hit})>[];

    for (final guide in _articles) {
      final translation = _translationFor(guide);
      final score =
          _scoreMatch(translation.title, query) +
          _scoreMatch(translation.summary ?? translation.body, query) * 0.8;

      if (score <= 0) continue;

      hits.add((
        score: score,
        hit: ArticleSearchHit(
          guide: guide,
          summary:
              translation.summary ??
              (gates.prefersEnglish
                  ? 'Detailed walkthrough'
                  : '詳しい手順やチェックポイント'),
          category: guide.category,
        ),
      ));
    }

    hits.sort((a, b) => b.score.compareTo(a.score));
    final items = hits.map((tuple) => tuple.hit).toList();
    return _page(items, pageToken: pageToken);
  }

  Page<FaqSearchHit> searchFaq(String rawQuery, {String? pageToken}) {
    final query = rawQuery.trim().toLowerCase();
    final hits = <({double score, FaqSearchHit hit})>[];

    for (final guide in _faqs) {
      final translation = _translationFor(guide);
      final score =
          _scoreMatch(translation.title, query) +
          _scoreMatch(translation.summary ?? '', query) * 0.6 +
          _scoreMatch(translation.body, query) * 0.3;

      if (score <= 0) continue;

      hits.add((
        score: score,
        hit: FaqSearchHit(
          guide: guide,
          question: translation.title,
          answer: translation.summary ?? translation.body,
        ),
      ));
    }

    hits.sort((a, b) => b.score.compareTo(a.score));
    final items = hits.map((tuple) => tuple.hit).toList();
    return _page(items, pageToken: pageToken);
  }

  List<Template> _buildTemplates() {
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
        isPublic: true,
        sort: 10,
        version: '1.0.0',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 4)),
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
        isPublic: true,
        sort: 20,
        version: '1.1.0',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 45)),
        updatedAt: now.subtract(const Duration(days: 8)),
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
        isPublic: true,
        sort: 30,
        version: '1.0.1',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 70)),
        updatedAt: now.subtract(const Duration(days: 12)),
      ),
      Template(
        id: 'engraved-thin',
        name: prefersEnglish ? 'Kanji fine lines' : '細線バランス',
        slug: 'engraved-thin',
        description: prefersEnglish
            ? 'Keeps delicate strokes readable for long names.'
            : '長い氏名でも潰れない細線テンプレート。',
        tags: const ['kanji', 'long-name'],
        shape: SealShape.square,
        writing: WritingStyle.reisho,
        defaults: const TemplateDefaults(
          sizeMm: 18,
          stroke: TemplateStrokeDefaults(weight: 0.38, contrast: 0.14),
          layout: TemplateLayoutDefaults(grid: 'balanced', margin: 1.0),
        ),
        constraints: const TemplateConstraints(
          sizeMm: SizeConstraint(min: 15, max: 21, step: 0.5),
          strokeWeight: RangeConstraint(min: 0.32, max: 0.55),
        ),
        previewUrl:
            'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=600&q=60',
        isPublic: true,
        sort: 40,
        version: '1.0.0',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 52)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
    ];
  }

  List<Material> _buildMaterials() {
    final now = DateTime.now();
    return [
      Material(
        id: 'akamatsu',
        name: gates.prefersEnglish ? 'Akamatsu wood' : '赤松ウッド',
        type: MaterialType.wood,
        finish: MaterialFinish.matte,
        color: gates.prefersEnglish ? 'Warm cedar' : 'やわらかい茶色',
        hardness: 3.2,
        density: 0.55,
        careNotes: gates.prefersEnglish
            ? 'Keep away from moisture.'
            : '湿気を避けて保管。',
        sustainability: const Sustainability(
          certifications: ['FSC'],
          notes: 'Re-planted every 5 years',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1501045661006-fcebe0257c3f?auto=format&fit=crop&w=600&q=60',
        ],
        isActive: true,
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
      Material(
        id: 'titan-brushed',
        name: gates.prefersEnglish ? 'Brushed titanium' : 'チタンヘアライン',
        type: MaterialType.titanium,
        finish: MaterialFinish.hairline,
        color: gates.prefersEnglish ? 'Cool silver' : 'シルバー',
        hardness: 6.0,
        density: 4.51,
        careNotes: gates.prefersEnglish
            ? 'Hypoallergenic and weather resistant.'
            : '金属アレルギー対応・耐候性あり。',
        sustainability: const Sustainability(
          certifications: ['ISO14001'],
          notes: 'Recycled alloy mix',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1471357674240-e1a485acb3e1?auto=format&fit=crop&w=600&q=60',
        ],
        isActive: true,
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now.subtract(const Duration(days: 14)),
      ),
      Material(
        id: 'resin-soft',
        name: gates.prefersEnglish ? 'Resin soft touch' : '樹脂ソフトタッチ',
        type: MaterialType.acrylic,
        finish: MaterialFinish.matte,
        color: gates.prefersEnglish ? 'Ivory' : 'アイボリー',
        hardness: 2.4,
        density: 1.18,
        careNotes: gates.prefersEnglish
            ? 'Great for practice or replacement seals.'
            : '練習用・代替印に適した耐水素材。',
        sustainability: const Sustainability(
          certifications: ['RoHS'],
          notes: 'Low-VOC coating',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=600&q=60',
        ],
        isActive: true,
        createdAt: now.subtract(const Duration(days: 75)),
        updatedAt: now.subtract(const Duration(days: 9)),
      ),
    ];
  }

  List<Guide> _buildArticles() {
    final now = DateTime.now();
    return [
      Guide(
        slug: 'choose-seal-size',
        category: GuideCategory.howto,
        isPublic: true,
        translations: {
          'ja': const GuideTranslation(
            title: '印鑑サイズの選び方',
            body: '用途別に 12mm〜18mm の目安と、文字数に応じた余白の確保方法を紹介。',
            summary: '用途別の推奨サイズと余白バランスのコツ。',
          ),
          'en': const GuideTranslation(
            title: 'How to pick the right seal size',
            body:
                'Quick guide for choosing between 12mm-18mm with tips for name length and margins.',
            summary: 'Size guide by use case with margin tips.',
          ),
        },
        tags: const ['size', 'guide'],
        heroImageUrl:
            'https://images.unsplash.com/photo-1505843513577-22bb7d21e455?auto=format&fit=crop&w=1200&q=60',
        readingTimeMinutes: 4,
        author: const GuideAuthor(name: 'Hanko Field Studio'),
        sources: const ['standards/jitsuin'],
        publishAt: now.subtract(const Duration(days: 35)),
        version: '1.0.0',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
      Guide(
        slug: 'material-care',
        category: GuideCategory.culture,
        isPublic: true,
        translations: {
          'ja': const GuideTranslation(
            title: '材質別のお手入れ',
            body: '木材・チタン・樹脂それぞれの保管方法と寿命の目安。',
            summary: '素材ごとのメンテナンス手順まとめ。',
          ),
          'en': const GuideTranslation(
            title: 'Material care tips',
            body:
                'Care checklist for wood, titanium, and resin seals to keep them crisp.',
            summary: 'Maintenance steps per material.',
          ),
        },
        tags: const ['care', 'material'],
        heroImageUrl:
            'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1200&q=60',
        readingTimeMinutes: 3,
        author: const GuideAuthor(name: 'Atelier Team'),
        sources: const [],
        publishAt: now.subtract(const Duration(days: 28)),
        version: '1.0.0',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 32)),
        updatedAt: now.subtract(const Duration(days: 6)),
      ),
    ];
  }

  List<Guide> _buildFaqs() {
    final now = DateTime.now();
    return [
      Guide(
        slug: 'faq-registrability',
        category: GuideCategory.faq,
        isPublic: true,
        translations: {
          'ja': const GuideTranslation(
            title: '実印として登録できますか？',
            body: '公的手続き向けに篆書ベースの書体を選び、15mm 以上を推奨しています。',
            summary: '実印登録の条件とおすすめ設定。',
          ),
          'en': const GuideTranslation(
            title: 'Can I register this as a jitsuin?',
            body:
                'Choose Tensho writing, keep size above 15mm, and avoid decorative marks.',
            summary: 'Registrability checklist.',
          ),
        },
        tags: const ['registry', 'official'],
        readingTimeMinutes: 2,
        author: const GuideAuthor(name: 'Support'),
        publishAt: now.subtract(const Duration(days: 22)),
        version: '1.0.0',
        createdAt: now.subtract(const Duration(days: 24)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
      Guide(
        slug: 'faq-shipping-intl',
        category: GuideCategory.faq,
        isPublic: true,
        translations: {
          'ja': const GuideTranslation(
            title: '海外配送はできますか？',
            body: 'DHL とゆうパックでの発送に対応。英語表記の帳票も同梱可能です。',
            summary: '海外配送の可否と手数料。',
          ),
          'en': const GuideTranslation(
            title: 'Do you ship internationally?',
            body:
                'We ship with DHL and Japan Post. English packing slips available on request.',
            summary: 'International shipping options.',
          ),
        },
        tags: const ['shipping', 'international'],
        readingTimeMinutes: 2,
        author: const GuideAuthor(name: 'Logistics'),
        publishAt: now.subtract(const Duration(days: 18)),
        version: '1.0.0',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
    ];
  }

  String _titleFor(Guide guide) {
    final translation = _translationFor(guide);
    return translation.title;
  }

  GuideTranslation _translationFor(Guide guide) {
    final lang = gates.locale.languageCode.toLowerCase();
    if (guide.translations.containsKey(lang)) {
      return guide.translations[lang]!;
    }
    if (gates.prefersJapanese && guide.translations.containsKey('ja')) {
      return guide.translations['ja']!;
    }
    return guide.translations.values.first;
  }

  String _summaryForMaterial(Material material) {
    if (material.type == MaterialType.titanium) {
      return gates.prefersEnglish
          ? 'Durable, hypoallergenic, weather resistant.'
          : '耐久性・アレルギー対応・耐候性に優れた素材。';
    }
    if (material.type == MaterialType.wood) {
      return gates.prefersEnglish
          ? 'Warm texture with FSC-certified sourcing.'
          : 'FSC認証の温かみある木材。';
    }
    return gates.prefersEnglish
        ? 'Lightweight resin for practice or backups.'
        : '軽量で練習用に最適な樹脂素材。';
  }

  String? _badgeForMaterial(Material material) {
    switch (material.type) {
      case MaterialType.titanium:
        return gates.prefersEnglish ? 'Popular' : '人気';
      case MaterialType.wood:
        return gates.prefersEnglish ? 'Warm' : '温かみ';
      case MaterialType.acrylic:
        return gates.prefersEnglish ? 'Light' : '軽量';
      case MaterialType.horn:
        return null;
    }
  }

  double _scoreTemplate(Template template, String query) {
    if (query.isEmpty) return 1.0 + template.sort / 100;

    final lower = query.toLowerCase();
    var score = 0.0;
    if (template.name.toLowerCase().contains(lower)) {
      score += 3;
    }
    if ((template.description ?? '').toLowerCase().contains(lower)) {
      score += 1.5;
    }
    if (template.tags.any((t) => t.toLowerCase().contains(lower))) {
      score += 1.2;
    }
    if (template.shape == SealShape.square && lower.contains('square')) {
      score += 1.4;
    }
    if (lower.contains('official') &&
        template.constraints.registrability?.jpJitsuinAllowed == true) {
      score += 1.4;
    }
    return score;
  }

  String _reasonForTemplate(Template template, String query) {
    if (query.isEmpty) {
      return gates.prefersEnglish ? 'Recommended starting point' : 'まずはこれがおすすめ';
    }

    final lower = query.toLowerCase();
    if (lower.contains('square') && template.shape == SealShape.square) {
      return gates.prefersEnglish
          ? 'Square fit for company seals'
          : '社名に合わせやすい角印';
    }
    if (lower.contains('official') &&
        template.constraints.registrability?.jpJitsuinAllowed == true) {
      return gates.prefersEnglish ? 'Ready for registrability' : '実印登録に適した設定';
    }
    if (template.tags.any((t) => lower.contains(t.toLowerCase()))) {
      return gates.prefersEnglish ? 'Matches your keyword' : 'キーワードに一致';
    }
    return gates.prefersEnglish ? 'Balanced margins' : '余白バランス良好';
  }

  double _scoreMaterial(Material material, String query) {
    if (query.isEmpty) return 1.0;
    final lower = query.toLowerCase();
    var score = 0.0;
    if (material.name.toLowerCase().contains(lower)) {
      score += 2.6;
    }
    if ((material.color ?? '').toLowerCase().contains(lower)) {
      score += 0.6;
    }
    if (material.type == MaterialType.titanium && lower.contains('metal')) {
      score += 1.2;
    }
    if (material.type == MaterialType.wood &&
        (lower.contains('wood') || lower.contains('warm'))) {
      score += 1.0;
    }
    return score;
  }

  double _scoreMatch(String text, String query) {
    if (query.isEmpty) return 1.0;
    final lower = query.toLowerCase();
    final normalized = text.toLowerCase();
    if (normalized.contains(lower)) {
      return 2.0 + 1 / (normalized.indexOf(lower) + 1);
    }
    return 0;
  }

  Page<T> _page<T>(List<T> items, {String? pageToken}) {
    const pageSize = 5;
    final start = int.tryParse(pageToken ?? '0') ?? 0;
    final slice = items.skip(start).take(pageSize).toList();
    final next = start + slice.length < items.length
        ? '${start + slice.length}'
        : null;
    return Page(items: slice, nextPageToken: next);
  }
}
