import 'dart:async';

import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/design_creation/domain/kanji_candidate.dart';
import 'package:clock/clock.dart' as clock_package;

class KanjiMappingRepository {
  KanjiMappingRepository({
    required OfflineCacheRepository cache,
    clock_package.Clock? clock,
  }) : _cache = cache,
       _clock = clock ?? clock_package.clock;

  final OfflineCacheRepository _cache;
  final clock_package.Clock _clock;

  Future<KanjiCandidateFetchResult> fetchCandidates({
    String query = '',
    Set<KanjiStrokeBucket> strokeFilters = const {},
    Set<KanjiRadicalCategory> radicalFilters = const {},
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    final cacheKey = _cacheKey(normalizedQuery, strokeFilters, radicalFilters);

    try {
      final simulated = await _simulateNetworkFetch(
        normalizedQuery: normalizedQuery,
        strokeFilters: strokeFilters,
        radicalFilters: radicalFilters,
      );
      await _cache.writeKanjiCandidates(simulated, key: cacheKey);
      return KanjiCandidateFetchResult(response: simulated, fromCache: false);
    } catch (error) {
      final cached = await _cache.readKanjiCandidates(key: cacheKey);
      if (cached.hasValue) {
        return KanjiCandidateFetchResult(
          response: KanjiCandidateResponse(
            candidates: cached.value!.candidates,
            generatedAt: cached.lastUpdated ?? _clock.now(),
            query: cached.value!.query,
            appliedStrokeFilters: cached.value!.appliedStrokeFilters,
            appliedRadicalFilters: cached.value!.appliedRadicalFilters,
          ),
          fromCache: true,
        );
      }
      rethrow;
    }
  }

  Future<KanjiCandidateResponse?> loadCachedCandidates({
    String query = '',
    Set<KanjiStrokeBucket> strokeFilters = const {},
    Set<KanjiRadicalCategory> radicalFilters = const {},
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    final cacheKey = _cacheKey(normalizedQuery, strokeFilters, radicalFilters);
    final cached = await _cache.readKanjiCandidates(key: cacheKey);
    if (!cached.hasValue) {
      return null;
    }
    return cached.value;
  }

  Future<Set<String>> loadBookmarks() async {
    final cached = await _cache.readKanjiBookmarks();
    if (cached.hasValue && cached.value != null) {
      return cached.value!;
    }
    return <String>{};
  }

  Future<void> saveBookmarks(Set<String> bookmarks) {
    return _cache.writeKanjiBookmarks(bookmarks);
  }

  String _cacheKey(
    String query,
    Set<KanjiStrokeBucket> strokeFilters,
    Set<KanjiRadicalCategory> radicalFilters,
  ) {
    final strokePart = strokeFilters.map((e) => e.name).toList()..sort();
    final radicalPart = radicalFilters.map((e) => e.name).toList()..sort();
    final normalizedQuery = query.isEmpty ? 'any' : query;
    return 'kanji:$normalizedQuery|strokes:${strokePart.join(',')}|radicals:${radicalPart.join(',')}';
  }

  Future<KanjiCandidateResponse> _simulateNetworkFetch({
    required String normalizedQuery,
    required Set<KanjiStrokeBucket> strokeFilters,
    required Set<KanjiRadicalCategory> radicalFilters,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));

    if (normalizedQuery == 'error') {
      throw StateError('Simulated network failure for query "error"');
    }

    final filtered =
        _kanjiCorpus.where((candidate) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              candidate.character.contains(normalizedQuery) ||
              candidate.meanings.any(
                (meaning) => meaning.toLowerCase().contains(normalizedQuery),
              ) ||
              candidate.readings.any(
                (reading) => reading.toLowerCase().contains(normalizedQuery),
              );

          if (!matchesQuery) {
            return false;
          }

          final matchesStroke =
              strokeFilters.isEmpty ||
              strokeFilters.any(
                (bucket) => bucket.matches(candidate.strokeCount),
              );

          if (!matchesStroke) {
            return false;
          }

          final matchesRadical =
              radicalFilters.isEmpty ||
              radicalFilters.contains(candidate.radicalCategory);

          return matchesRadical;
        }).toList()..sort((a, b) {
          final popularity = b.popularityScore.compareTo(a.popularityScore);
          if (popularity != 0) {
            return popularity;
          }
          return a.character.compareTo(b.character);
        });

    return KanjiCandidateResponse(
      candidates: filtered,
      generatedAt: _clock.now(),
      query: normalizedQuery,
      appliedStrokeFilters: strokeFilters,
      appliedRadicalFilters: radicalFilters,
    );
  }
}

class KanjiCandidateFetchResult {
  KanjiCandidateFetchResult({required this.response, required this.fromCache});

  final KanjiCandidateResponse response;
  final bool fromCache;
}

final List<KanjiCandidate> _kanjiCorpus = [
  const KanjiCandidate(
    id: 'river',
    character: '川',
    meanings: ['river', 'stream'],
    readings: ['kawa', 'sen'],
    popularityScore: 5,
    strokeCount: 3,
    radicalCategory: KanjiRadicalCategory.water,
    story: 'Represents flowing water, symbolising adaptability and calm.',
  ),
  const KanjiCandidate(
    id: 'light',
    character: '光',
    meanings: ['light', 'radiance'],
    readings: ['hikari', 'kou'],
    popularityScore: 5,
    strokeCount: 6,
    radicalCategory: KanjiRadicalCategory.fire,
    story: 'A classic seal character conveying brilliance and optimism.',
  ),
  const KanjiCandidate(
    id: 'harmony',
    character: '和',
    meanings: ['harmony', 'peace', 'japan'],
    readings: ['wa', 'yawaragu'],
    popularityScore: 5,
    strokeCount: 8,
    radicalCategory: KanjiRadicalCategory.speech,
    story:
        'Symbolises harmony and Japanese style, popular for cross-cultural seals.',
  ),
  const KanjiCandidate(
    id: 'forest',
    character: '森',
    meanings: ['forest', 'grove'],
    readings: ['mori', 'shin'],
    popularityScore: 4,
    strokeCount: 12,
    radicalCategory: KanjiRadicalCategory.wood,
    story: 'Three trees together evoke abundance and growth.',
  ),
  const KanjiCandidate(
    id: 'heart',
    character: '志',
    meanings: ['ambition', 'will', 'spirit'],
    readings: ['kokorozashi', 'shi'],
    popularityScore: 4,
    strokeCount: 7,
    radicalCategory: KanjiRadicalCategory.heart,
    story: 'Combines “mind” with sound to indicate sincere aspiration.',
  ),
  const KanjiCandidate(
    id: 'handcraft',
    character: '拓',
    meanings: ['open up', 'cultivate'],
    readings: ['hiraku', 'taku'],
    popularityScore: 3,
    strokeCount: 8,
    radicalCategory: KanjiRadicalCategory.hand,
    story:
        'Depicts a hand carving into stone—great for creative professionals.',
  ),
  const KanjiCandidate(
    id: 'voice',
    character: '誠',
    meanings: ['sincerity', 'truth'],
    readings: ['makoto', 'sei'],
    popularityScore: 4,
    strokeCount: 13,
    radicalCategory: KanjiRadicalCategory.speech,
    story: 'Speech radical plus “to become” expresses honest words.',
  ),
  const KanjiCandidate(
    id: 'flame',
    character: '炎',
    meanings: ['flame', 'passion'],
    readings: ['honoo', 'en'],
    popularityScore: 3,
    strokeCount: 8,
    radicalCategory: KanjiRadicalCategory.fire,
    story: 'Two fires stacked intensify passion—dynamic and energetic.',
  ),
  const KanjiCandidate(
    id: 'graceful',
    character: '優',
    meanings: ['gentle', 'superior', 'kind'],
    readings: ['yuu', 'yasashii'],
    popularityScore: 5,
    strokeCount: 17,
    radicalCategory: KanjiRadicalCategory.person,
    story: 'A person next to “graceful” evokes kindness with poise.',
  ),
  const KanjiCandidate(
    id: 'azure',
    character: '蒼',
    meanings: ['deep blue', 'verdant'],
    readings: ['ao', 'sou'],
    popularityScore: 2,
    strokeCount: 13,
    radicalCategory: KanjiRadicalCategory.wood,
    story: 'Grass radical plus vivid colour—ideal for nature-inspired brands.',
  ),
  const KanjiCandidate(
    id: 'resilient',
    character: '凛',
    meanings: ['dignified', 'chilly'],
    readings: ['rin'],
    popularityScore: 3,
    strokeCount: 15,
    radicalCategory: KanjiRadicalCategory.water,
    story: 'Icy radical with noble posture, expressing calm determination.',
  ),
];
