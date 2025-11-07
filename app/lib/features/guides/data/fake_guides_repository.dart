import 'dart:async';

import 'package:app/core/domain/entities/content.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/guides/data/guides_repository.dart';
import 'package:app/features/guides/domain/guide_detail.dart';
import 'package:app/features/guides/domain/guide_list_entry.dart';

class FakeGuidesRepository implements GuidesRepository {
  FakeGuidesRepository({
    required OfflineCacheRepository cache,
    Duration latency = const Duration(milliseconds: 280),
    DateTime Function()? now,
  }) : _cache = cache,
       _latency = latency,
       _now = now ?? DateTime.now {
    _articles = _seedArticles();
    _articleUpdatedMap = {
      for (final article in _articles) article.slug: article.updatedAt,
    };
  }

  final OfflineCacheRepository _cache;
  final Duration _latency;
  final DateTime Function() _now;
  late final List<GuideArticle> _articles;
  late final Map<String, DateTime> _articleUpdatedMap;

  @override
  Future<GuidesRepositoryResult> fetchGuides(GuideListRequest request) async {
    final cacheKey = _cacheKey(request);
    final cached = await _readCache(cacheKey: cacheKey, request: request);

    try {
      await Future<void>.delayed(_latency);
      final entries = _buildEntries(request);
      final timestamp = _now();
      await _cache.writeGuides(
        CachedGuideList(
          guides: entries.map(_cacheItemFromEntry).toList(),
          locale: request.localeTag,
          updatedAt: timestamp,
        ),
        key: cacheKey,
      );
      return _buildResult(
        entries: entries,
        request: request,
        fromCache: false,
        timestamp: timestamp,
      );
    } catch (error) {
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<GuideDetailResult> fetchGuideDetail(GuideDetailRequest request) async {
    final cacheKey = _detailCacheKey(request);
    final cached = await _readDetailCache(cacheKey: cacheKey, request: request);
    try {
      await Future<void>.delayed(_latency);
      final article = _articles.firstWhere(
        (candidate) => candidate.slug == request.slug,
        orElse: () => throw StateError('Guide not found: ${request.slug}'),
      );
      final translation = _resolveTranslation(article, request.localeTag);
      if (translation == null) {
        throw StateError(
          'Guide ${request.slug} missing translation for ${request.localeTag}',
        );
      }
      final detail = _buildDetail(
        article: article,
        translation: translation,
        localeTag: request.localeTag,
      );
      final related = _relatedEntries(
        request: request,
        excludeSlug: article.slug,
        category: article.category,
      );
      final timestamp = _now();
      await _cache.writeGuideDetail(
        CachedGuideDetail(
          article: _cacheArticleFromDetail(detail),
          related: related.map(_cacheItemFromEntry).toList(),
          updatedAt: timestamp,
        ),
        key: cacheKey,
      );
      return _buildDetailResult(
        detail: detail,
        related: related,
        request: request,
        fromCache: false,
        timestamp: timestamp,
      );
    } catch (error) {
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<GuidesRepositoryResult?> _readCache({
    required String cacheKey,
    required GuideListRequest request,
  }) async {
    final cache = await _cache.readGuides(key: cacheKey);
    final snapshot = cache.value;
    if (snapshot == null) {
      return null;
    }
    final entries = snapshot.guides
        .map(_entryFromCache)
        .toList(growable: false);
    final timestamp = snapshot.updatedAt ?? cache.lastUpdated ?? _now();
    return _buildResult(
      entries: entries,
      request: request,
      fromCache: true,
      timestamp: timestamp,
    );
  }

  Future<GuideDetailResult?> _readDetailCache({
    required String cacheKey,
    required GuideDetailRequest request,
  }) async {
    final cache = await _cache.readGuideDetail(key: cacheKey);
    final snapshot = cache.value;
    if (snapshot == null) {
      return null;
    }
    final detail = _detailFromCache(snapshot.article);
    final related = snapshot.related
        .map(_entryFromCache)
        .toList(growable: false);
    final timestamp = snapshot.updatedAt ?? cache.lastUpdated ?? _now();
    return _buildDetailResult(
      detail: detail,
      related: related,
      request: request,
      fromCache: true,
      timestamp: timestamp,
    );
  }

  GuidesRepositoryResult _buildResult({
    required List<GuideListEntry> entries,
    required GuideListRequest request,
    required bool fromCache,
    required DateTime timestamp,
  }) {
    final recommended = entries
        .where(
          (entry) => entry.featured && entry.supportsPersona(request.persona),
        )
        .take(4)
        .toList(growable: false);
    return GuidesRepositoryResult(
      guides: entries,
      recommended: recommended,
      localeTag: request.localeTag,
      persona: request.persona,
      fetchedAt: timestamp,
      fromCache: fromCache,
    );
  }

  GuideDetailResult _buildDetailResult({
    required GuideDetail detail,
    required List<GuideListEntry> related,
    required GuideDetailRequest request,
    required bool fromCache,
    required DateTime timestamp,
  }) {
    return GuideDetailResult(
      detail: detail,
      related: related,
      localeTag: request.localeTag,
      persona: request.persona,
      fetchedAt: timestamp,
      fromCache: fromCache,
    );
  }

  List<GuideListEntry> _buildEntries(GuideListRequest request) {
    final result = <GuideListEntry>[];
    for (final article in _articles) {
      final personas = _personaTargetsFor(article.tags);
      if (personas.isNotEmpty && !personas.contains(request.persona)) {
        continue;
      }
      final translation = _resolveTranslation(article, request.localeTag);
      if (translation == null) {
        continue;
      }
      result.add(
        GuideListEntry(
          id: article.id,
          slug: article.slug,
          title: translation.title,
          summary: _summaryFor(translation),
          category: article.category,
          locale: translation.locale,
          heroImageUrl: article.heroImageUrl,
          readingTimeMinutes: article.readingTimeMinutes,
          tags: article.tags,
          personaTargets: personas,
          featured: article.tags.contains('recommended'),
        ),
      );
    }
    result.sort((a, b) {
      final aUpdated =
          _articleUpdatedMap[a.slug] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bUpdated =
          _articleUpdatedMap[b.slug] ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bUpdated.compareTo(aUpdated);
    });
    return result;
  }

  GuideDetail _buildDetail({
    required GuideArticle article,
    required GuideTranslation translation,
    required String localeTag,
  }) {
    final personas = _personaTargetsFor(article.tags);
    final format = _detectFormat(translation.body);
    final summary = _summaryFor(translation);
    final shareUrl =
        'https://app.hanko-field.com/guides/${article.slug}?locale=$localeTag';
    return GuideDetail(
      id: article.id,
      slug: article.slug,
      title: translation.title,
      summary: summary,
      body: translation.body.trim(),
      bodyFormat: format,
      category: article.category,
      locale: translation.locale,
      heroImageUrl: article.heroImageUrl,
      readingTimeMinutes: article.readingTimeMinutes,
      author: article.author,
      sources: article.sources,
      tags: article.tags,
      personaTargets: personas,
      publishAt: article.publishAt,
      updatedAt: article.updatedAt,
      version: article.version,
      shareUrl: shareUrl,
      featured: article.tags.contains('recommended'),
    );
  }

  List<GuideListEntry> _relatedEntries({
    required GuideDetailRequest request,
    required String excludeSlug,
    required GuideCategory category,
  }) {
    final entries = _buildEntries(
      GuideListRequest(localeTag: request.localeTag, persona: request.persona),
    );
    final prioritized = <GuideListEntry>[];
    final others = <GuideListEntry>[];
    for (final entry in entries) {
      if (entry.slug == excludeSlug) {
        continue;
      }
      if (entry.category == category) {
        prioritized.add(entry);
      } else {
        others.add(entry);
      }
    }
    return [...prioritized.take(3), ...others].take(6).toList(growable: false);
  }

  GuideTranslation? _resolveTranslation(
    GuideArticle article,
    String localeTag,
  ) {
    GuideTranslation? exact;
    GuideTranslation? sameLanguage;
    final targetLanguage = _languageOf(localeTag);

    for (final translation in article.translations) {
      final translationLanguage = _languageOf(translation.locale);
      if (translation.locale.toLowerCase() == localeTag.toLowerCase()) {
        exact = translation;
        break;
      }
      if (translationLanguage == targetLanguage && sameLanguage == null) {
        sameLanguage = translation;
      }
    }
    if (exact != null) {
      return exact;
    }
    if (sameLanguage != null) {
      return sameLanguage;
    }
    for (final translation in article.translations) {
      if (_languageOf(translation.locale) == 'en') {
        return translation;
      }
    }
    return article.translations.isEmpty ? null : article.translations.first;
  }

  Set<UserPersona> _personaTargetsFor(List<String> tags) {
    final personas = <UserPersona>{};
    for (final tag in tags) {
      if (!tag.startsWith('persona:')) {
        continue;
      }
      final value = tag.substring('persona:'.length);
      for (final persona in UserPersona.values) {
        if (persona.name == value) {
          personas.add(persona);
        }
      }
    }
    return personas;
  }

  GuideListEntry _entryFromCache(GuideCacheItem item) {
    final personas = <UserPersona>{
      for (final raw in item.personaTargets)
        for (final persona in UserPersona.values)
          if (persona.name == raw) persona,
    };
    return GuideListEntry(
      id: item.id,
      slug: item.slug,
      title: item.title,
      summary: item.summary,
      category: _parseCategory(item.category),
      locale: item.locale,
      heroImageUrl: item.heroImage,
      readingTimeMinutes: item.readingTimeMinutes,
      tags: item.tags,
      personaTargets: personas,
      featured: item.featured,
    );
  }

  GuideCacheItem _cacheItemFromEntry(GuideListEntry entry) {
    return GuideCacheItem(
      id: entry.id,
      slug: entry.slug,
      title: entry.title,
      summary: entry.summary,
      category: entry.category.name,
      locale: entry.locale,
      featured: entry.featured,
      heroImage: entry.heroImageUrl,
      readingTimeMinutes: entry.readingTimeMinutes,
      tags: entry.tags,
      personaTargets: entry.personaTargets
          .map((persona) => persona.name)
          .toList(growable: false),
    );
  }

  CachedGuideArticle _cacheArticleFromDetail(GuideDetail detail) {
    return CachedGuideArticle(
      id: detail.id,
      slug: detail.slug,
      title: detail.title,
      summary: detail.summary,
      body: detail.body,
      bodyFormat: detail.bodyFormat.name,
      category: detail.category.name,
      locale: detail.locale,
      heroImage: detail.heroImageUrl,
      readingTimeMinutes: detail.readingTimeMinutes,
      authorName: detail.author?.name,
      authorProfileUrl: detail.author?.profileUrl,
      tags: detail.tags,
      personaTargets: detail.personaTargets
          .map((persona) => persona.name)
          .toList(growable: false),
      sources: detail.sources,
      publishAt: detail.publishAt,
      updatedAt: detail.updatedAt,
      version: detail.version,
      shareUrl: detail.shareUrl,
      featured: detail.featured,
    );
  }

  GuideDetail _detailFromCache(CachedGuideArticle cached) {
    final personas = <UserPersona>{
      for (final raw in cached.personaTargets)
        for (final persona in UserPersona.values)
          if (persona.name == raw) persona,
    };
    final author = cached.authorName == null && cached.authorProfileUrl == null
        ? null
        : GuideAuthor(
            name: cached.authorName,
            profileUrl: cached.authorProfileUrl,
          );
    return GuideDetail(
      id: cached.id,
      slug: cached.slug,
      title: cached.title,
      summary: cached.summary,
      body: cached.body,
      bodyFormat: cached.bodyFormat == 'html'
          ? GuideBodyFormat.html
          : GuideBodyFormat.markdown,
      category: _parseCategory(cached.category),
      locale: cached.locale,
      heroImageUrl: cached.heroImage,
      readingTimeMinutes: cached.readingTimeMinutes,
      author: author,
      sources: cached.sources,
      tags: cached.tags,
      personaTargets: personas,
      publishAt: cached.publishAt,
      updatedAt: cached.updatedAt,
      version: cached.version,
      shareUrl: cached.shareUrl,
      featured: cached.featured,
    );
  }

  static GuideCategory _parseCategory(String raw) {
    for (final category in GuideCategory.values) {
      if (category.name == raw) {
        return category;
      }
    }
    return GuideCategory.other;
  }

  static String _summaryFor(GuideTranslation translation) {
    final summary = translation.summary?.trim();
    if (summary != null && summary.isNotEmpty) {
      return summary;
    }
    final body = translation.body.trim();
    if (body.length <= 140) {
      return body;
    }
    return '${body.substring(0, 140)}...';
  }

  static GuideBodyFormat _detectFormat(String body) {
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('<') && trimmed.contains('>')) {
      return GuideBodyFormat.html;
    }
    if (trimmed.contains('</p>') || trimmed.contains('<br')) {
      return GuideBodyFormat.html;
    }
    return GuideBodyFormat.markdown;
  }

  static String _languageOf(String localeTag) {
    final normalized = localeTag.toLowerCase();
    final dashIndex = normalized.indexOf('-');
    if (dashIndex == -1) {
      return normalized;
    }
    return normalized.substring(0, dashIndex);
  }

  static String _cacheKey(GuideListRequest request) {
    return '${request.localeTag.toLowerCase()}-${request.persona.name}';
  }

  static String _detailCacheKey(GuideDetailRequest request) {
    return 'detail-${request.slug}-${request.localeTag.toLowerCase()}-${request.persona.name}';
  }

  List<GuideArticle> _seedArticles() {
    final now = DateTime(2024, 5, 20);
    return [
      GuideArticle(
        id: 'guide-kanji-basics',
        slug: 'kanji-mapping-basics',
        category: GuideCategory.howto,
        tags: const [
          'persona:foreigner',
          'recommended',
          'topic:kanji',
          'level:intro',
        ],
        heroImageUrl:
            'https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?w=1200',
        readingTimeMinutes: 6,
        author: const GuideAuthor(name: 'Kana Aoki'),
        sources: const ['cms'],
        translations: const [
          GuideTranslation(
            locale: 'en',
            title: 'Kanji Mapping Basics',
            summary:
                'Match your name to kanji characters with cultural nuance in mind.',
            body:
                'Start by pronouncing your name the way locals would. Compare the phonetic sound to common kanji readings, then shortlist characters that reflect your preferred meaning.',
          ),
          GuideTranslation(
            locale: 'ja',
            title: '漢字マッピング入門',
            summary: 'ローマ字名に最適な漢字を短時間で選ぶための手順です。',
            body:
                '現地での呼ばれ方を意識し、音と意味の両面から候補を集めます。音読み・訓読みの違いを押さえ、文化的に失礼のない字を確認しましょう。',
          ),
        ],
        isPublic: true,
        publishAt: now.subtract(const Duration(days: 2)),
        version: '1.0',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      GuideArticle(
        id: 'guide-hanko-etiquette-intl',
        slug: 'hanko-etiquette-international',
        category: GuideCategory.culture,
        tags: const [
          'persona:foreigner',
          'recommended',
          'topic:etiquette',
          'culture',
        ],
        heroImageUrl:
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1200',
        readingTimeMinutes: 8,
        author: const GuideAuthor(name: 'Mika Sanders'),
        sources: const [],
        translations: const [
          GuideTranslation(
            locale: 'en',
            title: 'Hanko Etiquette Abroad',
            summary:
                'Understand when to bow, when to stamp, and how to carry your seal overseas.',
            body:
                'Store your seal in a breathable case, wipe any excess ink after stamping, and avoid placing it near chopsticks or food. These small gestures signal respect.',
          ),
          GuideTranslation(
            locale: 'ja',
            title: '海外でも使える印鑑マナー',
            summary: '海外出張で失礼にならない印鑑の扱い方を解説します。',
            body: '朱肉をつけた後は必ず余分なインクを拭き、印面を上に向けたまま両手で差し出します。文化の違いを説明すると好印象です。',
          ),
        ],
        isPublic: true,
        publishAt: now.subtract(const Duration(days: 5)),
        version: '1.0',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      GuideArticle(
        id: 'guide-registration-checklist',
        slug: 'bank-registration-checklist',
        category: GuideCategory.policy,
        tags: const [
          'persona:japanese',
          'recommended',
          'topic:policy',
          'compliance',
        ],
        heroImageUrl:
            'https://images.unsplash.com/photo-1521579971123-1192931a1452?w=1200',
        readingTimeMinutes: 9,
        author: const GuideAuthor(name: 'Hanko Field Team'),
        sources: const [],
        translations: const [
          GuideTranslation(
            locale: 'ja',
            title: '銀行印登録チェックリスト',
            summary: '役所・銀行へ提出する前に必ず確認したいポイントをまとめました。',
            body:
                '印面サイズ・彫刻内容・字体、そして印鑑カードの受け取り方法まで時系列でチェックできます。法人・個人それぞれの注意点も掲載。',
          ),
          GuideTranslation(
            locale: 'en',
            title: 'Bank Registration Checklist',
            summary:
                'Ensure your seal meets Japanese bank requirements with this step-by-step list.',
            body:
                'Confirm size, font, reading, and registration forms before your appointment. Bring proof of address and matching identification to avoid repeat visits.',
          ),
        ],
        isPublic: true,
        publishAt: now.subtract(const Duration(days: 9)),
        version: '2.1',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(days: 9)),
      ),
      GuideArticle(
        id: 'guide-material-care',
        slug: 'material-care-guide',
        category: GuideCategory.howto,
        tags: const ['persona:japanese', 'persona:foreigner', 'topic:care'],
        heroImageUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1200',
        readingTimeMinutes: 5,
        author: const GuideAuthor(name: 'Takumi Kato'),
        sources: const [],
        translations: const [
          GuideTranslation(
            locale: 'ja',
            title: '素材別お手入れガイド',
            summary: '柘植・黒水牛・チタン、それぞれの保管と手入れ方法を解説。',
            body: '乾燥と湿気のバランスが重要です。ケースの中に乾燥剤を入れすぎると割れの原因になるので注意しましょう。',
          ),
          GuideTranslation(
            locale: 'en',
            title: 'Seal Material Care Tips',
            summary:
                'Keep wood, horn, and titanium seals looking sharp with quick maintenance routines.',
            body:
                'Avoid direct sunlight, rotate the resting position monthly, and lightly oil horn seals to prevent hairline cracks.',
          ),
        ],
        isPublic: true,
        publishAt: now.subtract(const Duration(days: 14)),
        version: '1.4',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 16)),
        updatedAt: now.subtract(const Duration(days: 14)),
      ),
      GuideArticle(
        id: 'guide-inkpad-howto',
        slug: 'inkpad-guide',
        category: GuideCategory.faq,
        tags: const [
          'persona:japanese',
          'persona:foreigner',
          'topic:ink',
          'support',
        ],
        heroImageUrl:
            'https://images.unsplash.com/photo-1520256862855-398228c41684?w=1200',
        readingTimeMinutes: 4,
        author: const GuideAuthor(name: 'Hanko Support'),
        sources: const [],
        translations: const [
          GuideTranslation(
            locale: 'ja',
            title: '朱肉とスタンプ台の選び方',
            summary: 'ビジネス用と海外携帯用、それぞれのインク特性を比較。',
            body: '顔料系は耐久性があり、油性系は乾燥しづらい特性があります。海外では速乾タイプが好まれます。',
          ),
          GuideTranslation(
            locale: 'en',
            title: 'Choosing The Right Ink Pad',
            summary:
                'Compare pigment, oil-based, and travel-friendly ink pads in minutes.',
            body:
                'Pigment ink delivers crisp edges, while fast-dry pads fit travel scenarios. Store pads upside down to keep the surface saturated.',
          ),
        ],
        isPublic: true,
        publishAt: now.subtract(const Duration(days: 20)),
        version: '1.2',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 25)),
        updatedAt: now.subtract(const Duration(days: 20)),
      ),
      GuideArticle(
        id: 'guide-seasonal-traditions',
        slug: 'seasonal-traditions',
        category: GuideCategory.news,
        tags: const ['persona:japanese', 'topic:culture', 'seasonal'],
        heroImageUrl:
            'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1200',
        readingTimeMinutes: 7,
        author: const GuideAuthor(name: 'Culture Desk'),
        sources: const [],
        translations: const [
          GuideTranslation(
            locale: 'ja',
            title: '季節のしきたりと印章文化',
            summary: '節句や年末に行われる印章のお清め儀式を紹介します。',
            body: '昔は煤払いのタイミングで印材を磨き直し、家族で共有する文化がありました。現代でも年末に印面を整える家庭は多いです。',
          ),
          GuideTranslation(
            locale: 'en',
            title: 'Seasonal Traditions Around Seals',
            summary:
                'Learn how households refresh their seals during seasonal festivals in Japan.',
            body:
                'From New Year polishing to autumn harvest blessings, stamps often appear in family rituals. Try scheduling a gentle cleaning every quarter.',
          ),
        ],
        isPublic: true,
        publishAt: now.subtract(const Duration(days: 30)),
        version: '1.0',
        isDeprecated: false,
        createdAt: now.subtract(const Duration(days: 34)),
        updatedAt: now.subtract(const Duration(days: 30)),
      ),
    ];
  }
}
