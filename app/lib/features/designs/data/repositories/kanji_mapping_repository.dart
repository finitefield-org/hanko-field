// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/designs/data/models/kanji_mapping_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class KanjiMappingRepository {
  static const fallback = Scope<KanjiMappingRepository>.required(
    'kanji.mapping.repository',
  );

  Future<KanjiSuggestionResult> fetchCandidates({
    required String query,
    KanjiFilter? filter,
  });

  Future<Set<String>> loadBookmarks();

  Future<Set<String>> toggleBookmark(String candidateId);
}

final kanjiMappingRepositoryProvider = Provider<KanjiMappingRepository>((ref) {
  final cache = ref.watch(kanjiCacheProvider);
  final gates = ref.watch(appExperienceGatesProvider);
  final logger = Logger('KanjiMappingRepository');
  return LocalKanjiMappingRepository(
    cache: cache,
    gates: gates,
    logger: logger,
  );
});

class LocalKanjiMappingRepository implements KanjiMappingRepository {
  LocalKanjiMappingRepository({
    required LocalCacheStore<JsonMap> cache,
    required AppExperienceGates gates,
    Logger? logger,
  }) : _cache = cache,
       _gates = gates,
       _logger = logger ?? Logger('LocalKanjiMappingRepository');

  final LocalCacheStore<JsonMap> _cache;
  final AppExperienceGates _gates;
  final Logger _logger;

  bool _bookmarksLoaded = false;
  final Set<String> _bookmarks = {};
  late final List<KanjiCandidate> _catalog = _seedCatalog(_gates);

  @override
  Future<KanjiSuggestionResult> fetchCandidates({
    required String query,
    KanjiFilter? filter,
  }) async {
    await _ensureBookmarksLoaded();
    final normalizedQuery = query.trim().isEmpty
        ? _defaultQuery()
        : query.trim();
    final activeFilter = filter ?? const KanjiFilter();
    final cacheKey = LocalCacheKeys.kanjiSuggestions(
      query: normalizedQuery,
      persona: _gates.personaKey,
      filterKey: activeFilter.cacheKey,
    );

    try {
      final matches = _filterCatalog(
        normalizedQuery.toLowerCase(),
        activeFilter,
      );
      await Future<void>.delayed(const Duration(milliseconds: 220));

      final payload = <String, Object?>{
        'items': matches.map((c) => c.toJson()).toList(),
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      unawaited(
        _cache.write(
          cacheKey.value,
          payload,
          policy: CachePolicies.kanji,
          tags: cacheKey.tags,
        ),
      );

      return KanjiSuggestionResult(
        candidates: matches,
        fromCache: false,
        cachedAt: DateTime.now(),
      );
    } catch (e, stack) {
      _logger.warning('Failed to fetch kanji suggestions', e, stack);
      final cached = await _cache.read(
        cacheKey.value,
        policy: CachePolicies.kanji,
      );
      if (cached != null) {
        return KanjiSuggestionResult(
          candidates: _decodeCandidates(cached.value),
          fromCache: true,
          cachedAt: cached.storedAt,
        );
      }
      rethrow;
    }
  }

  @override
  Future<Set<String>> loadBookmarks() async {
    await _ensureBookmarksLoaded();
    return _bookmarks.toSet();
  }

  @override
  Future<Set<String>> toggleBookmark(String candidateId) async {
    await _ensureBookmarksLoaded();
    if (_bookmarks.contains(candidateId)) {
      _bookmarks.remove(candidateId);
    } else {
      _bookmarks.add(candidateId);
    }
    await _persistBookmarks();
    return _bookmarks.toSet();
  }

  Future<void> _ensureBookmarksLoaded() async {
    if (_bookmarksLoaded) return;
    final key = LocalCacheKeys.kanjiBookmarks(persona: _gates.personaKey);
    try {
      final hit = await _cache.read(key.value, policy: CachePolicies.kanji);
      final raw = hit?.value['ids'];
      if (raw is List) {
        _bookmarks.addAll(raw.whereType<String>());
      }
    } catch (e, stack) {
      _logger.warning('Failed to load kanji bookmarks', e, stack);
    }
    _bookmarksLoaded = true;
  }

  Future<void> _persistBookmarks() async {
    final key = LocalCacheKeys.kanjiBookmarks(persona: _gates.personaKey);
    await _cache.write(
      key.value,
      <String, Object?>{'ids': _bookmarks.toList()},
      tags: key.tags,
      policy: CachePolicies.kanji,
    );
  }

  List<KanjiCandidate> _filterCatalog(String query, KanjiFilter filter) {
    final filtered = _catalog.where((candidate) {
      final inQuery = _matchesQuery(candidate, query);
      final matchesStroke = filter.strokeBucket == null
          ? true
          : _matchesStrokeBucket(candidate.strokeCount, filter.strokeBucket!);
      final matchesRadical = filter.radical == null
          ? true
          : candidate.radical == filter.radical;

      return inQuery && matchesStroke && matchesRadical;
    }).toList()..sort((a, b) => b.popularity.compareTo(a.popularity));

    if (filtered.isNotEmpty) return filtered;

    // Fallback to popular candidates if nothing matches.
    return _catalog
        .sorted((a, b) => b.popularity.compareTo(a.popularity))
        .take(12)
        .toList();
  }

  bool _matchesQuery(KanjiCandidate candidate, String query) {
    final lower = query.toLowerCase();
    final haystack = <String>[
      candidate.glyph,
      candidate.meaning.toLowerCase(),
      candidate.pronunciation.toLowerCase(),
      ...candidate.keywords.map((k) => k.toLowerCase()),
    ].join(' ');
    return haystack.contains(lower);
  }

  bool _matchesStrokeBucket(int strokes, String bucket) {
    switch (bucket) {
      case '1-5':
        return strokes <= 5;
      case '6-10':
        return strokes >= 6 && strokes <= 10;
      case '11-15':
        return strokes >= 11 && strokes <= 15;
      case '16+':
        return strokes >= 16;
    }
    return true;
  }

  List<KanjiCandidate> _decodeCandidates(JsonMap map) {
    final raw = map['items'];
    if (raw is! List) return const <KanjiCandidate>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(KanjiCandidate.fromJson)
        .toList();
  }

  String _defaultQuery() {
    if (_gates.prefersEnglish) return 'hanko';
    return '印';
  }

  List<KanjiCandidate> _seedCatalog(AppExperienceGates gates) {
    final prefersEnglish = gates.prefersEnglish;
    final intl = gates.emphasizeInternationalFlows;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rng = Random(now);

    final base = <KanjiCandidate>[
      KanjiCandidate(
        id: 'sato',
        glyph: '佐藤',
        meaning: prefersEnglish ? 'helpful wisteria' : '助ける＋藤',
        pronunciation: prefersEnglish ? 'Sa-tō' : 'さとう',
        popularity: intl ? 0.92 : 0.85,
        strokeCount: 21,
        radical: 'plant',
        keywords: const ['surname', 'heritage', 'assist'],
      ),
      KanjiCandidate(
        id: 'yuki',
        glyph: '優希',
        meaning: prefersEnglish ? 'gentle hope' : 'やさしさ・希望',
        pronunciation: prefersEnglish ? 'Yū-ki' : 'ゆうき',
        popularity: 0.81,
        strokeCount: 17,
        radical: 'heart',
        keywords: const ['given', 'hope', 'gentle'],
      ),
      KanjiCandidate(
        id: 'haru',
        glyph: '陽',
        meaning: prefersEnglish ? 'sunny' : '太陽・明るい',
        pronunciation: prefersEnglish ? 'Haru' : 'はる',
        popularity: 0.77,
        strokeCount: 12,
        radical: 'sun',
        keywords: const ['spring', 'bright', 'warm'],
      ),
      KanjiCandidate(
        id: 'umi',
        glyph: '海',
        meaning: prefersEnglish ? 'sea' : '海',
        pronunciation: prefersEnglish ? 'Umi' : 'うみ',
        popularity: 0.7,
        strokeCount: 9,
        radical: 'water',
        keywords: const ['ocean', 'water', 'wave'],
      ),
      KanjiCandidate(
        id: 'hana',
        glyph: '華',
        meaning: prefersEnglish ? 'radiant' : '華やか',
        pronunciation: prefersEnglish ? 'Hana' : 'はな',
        popularity: intl ? 0.74 : 0.68,
        strokeCount: 14,
        radical: 'plant',
        keywords: const ['flower', 'elegant', 'beauty'],
      ),
      KanjiCandidate(
        id: 'riku',
        glyph: '陸',
        meaning: prefersEnglish ? 'land' : '大地・陸',
        pronunciation: prefersEnglish ? 'Riku' : 'りく',
        popularity: 0.65,
        strokeCount: 11,
        radical: 'earth',
        keywords: const ['ground', 'firm'],
      ),
      KanjiCandidate(
        id: 'ren',
        glyph: '蓮',
        meaning: prefersEnglish ? 'lotus' : '蓮',
        pronunciation: prefersEnglish ? 'Ren' : 'れん',
        popularity: 0.73,
        strokeCount: 13,
        radical: 'plant',
        keywords: const ['lotus', 'calm'],
      ),
      KanjiCandidate(
        id: 'ken',
        glyph: '健',
        meaning: prefersEnglish ? 'healthy' : '健康',
        pronunciation: prefersEnglish ? 'Ken' : 'けん',
        popularity: 0.71,
        strokeCount: 11,
        radical: 'person',
        keywords: const ['strong', 'health'],
      ),
      KanjiCandidate(
        id: 'ai',
        glyph: '愛',
        meaning: prefersEnglish ? 'love' : '愛情',
        pronunciation: prefersEnglish ? 'Ai' : 'あい',
        popularity: 0.8,
        strokeCount: 13,
        radical: 'heart',
        keywords: const ['love', 'care', 'affection'],
      ),
      KanjiCandidate(
        id: 'mizuho',
        glyph: '瑞穂',
        meaning: prefersEnglish ? 'abundant rice' : '豊かな稲穂',
        pronunciation: prefersEnglish ? 'Mizuho' : 'みずほ',
        popularity: 0.6,
        strokeCount: 24,
        radical: 'grain',
        keywords: const ['harvest', 'grain'],
      ),
      KanjiCandidate(
        id: 'sora',
        glyph: '空',
        meaning: prefersEnglish ? 'sky' : '空・そら',
        pronunciation: prefersEnglish ? 'Sora' : 'そら',
        popularity: intl ? 0.69 : 0.64,
        strokeCount: 8,
        radical: 'roof',
        keywords: const ['sky', 'space', 'open'],
      ),
      KanjiCandidate(
        id: 'asahi',
        glyph: '朝日',
        meaning: prefersEnglish ? 'morning sun' : '朝日の光',
        pronunciation: prefersEnglish ? 'Asahi' : 'あさひ',
        popularity: 0.66,
        strokeCount: 12,
        radical: 'sun',
        keywords: const ['sunrise', 'bright'],
      ),
      KanjiCandidate(
        id: 'rio',
        glyph: '理央',
        meaning: prefersEnglish ? 'logic + center' : '理＋央',
        pronunciation: prefersEnglish ? 'Rio' : 'りお',
        popularity: 0.62 + (intl ? 0.04 : 0),
        strokeCount: 20,
        radical: 'jade',
        keywords: const ['reason', 'center'],
      ),
    ];

    return base
        .map(
          (candidate) => candidate.copyWith(
            popularity: (candidate.popularity + rng.nextDouble() * 0.08 - 0.04)
                .clamp(0.45, 0.98),
          ),
        )
        .toList();
  }
}
