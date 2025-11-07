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

  List<KanjiCandidate> allCandidates() => List.unmodifiable(_kanjiCorpus);

  KanjiCandidate? candidateById(String id) {
    for (final candidate in _kanjiCorpus) {
      if (candidate.id == id) {
        return candidate;
      }
    }
    return null;
  }

  List<KanjiCandidate> candidatesByIds(Iterable<String> ids) {
    final map = {for (final entry in _kanjiCorpus) entry.id: entry};
    return ids
        .map((id) => map[id])
        .whereType<KanjiCandidate>()
        .toList(growable: false);
  }

  List<KanjiCandidate> featuredCandidates({int limit = 6}) {
    final sorted = List<KanjiCandidate>.from(_kanjiCorpus)
      ..sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
    if (sorted.length <= limit) {
      return sorted;
    }
    return sorted.sublist(0, limit);
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
    gradeLevel: KanjiGradeLevel.grade1,
    story: 'Represents flowing water, symbolising adaptability and calm.',
    usageExamples: ['多摩川 — Tama River', '川遊び — Playing in the river'],
    strokeOrderHints: [
      '1. Draw the left vertical stroke downward.',
      '2. Add the slightly longer middle stroke.',
      '3. Finish with the right-most stroke.',
    ],
  ),
  const KanjiCandidate(
    id: 'light',
    character: '光',
    meanings: ['light', 'radiance'],
    readings: ['hikari', 'kou'],
    popularityScore: 5,
    strokeCount: 6,
    radicalCategory: KanjiRadicalCategory.fire,
    gradeLevel: KanjiGradeLevel.grade2,
    story: 'A classic seal character conveying brilliance and optimism.',
    usageExamples: ['観光 — Sightseeing', '月光 — Moonlight'],
    strokeOrderHints: [
      '1. Start with the dot above.',
      '2. Draw the central vertical line.',
      '3. Sweep the legs outward from the center.',
    ],
  ),
  const KanjiCandidate(
    id: 'harmony',
    character: '和',
    meanings: ['harmony', 'peace', 'japan'],
    readings: ['wa', 'yawaragu'],
    popularityScore: 5,
    strokeCount: 8,
    radicalCategory: KanjiRadicalCategory.speech,
    gradeLevel: KanjiGradeLevel.grade2,
    story:
        'Symbolises harmony and Japanese style, popular for cross-cultural seals.',
    usageExamples: ['平和 — Peace', '和食 — Japanese cuisine'],
    strokeOrderHints: [
      '1. Write the left “grain” radical from top to bottom.',
      '2. Add the mouth component on the right.',
      '3. Finish with the final sweeping stroke.',
    ],
  ),
  const KanjiCandidate(
    id: 'forest',
    character: '森',
    meanings: ['forest', 'grove'],
    readings: ['mori', 'shin'],
    popularityScore: 4,
    strokeCount: 12,
    radicalCategory: KanjiRadicalCategory.wood,
    gradeLevel: KanjiGradeLevel.grade3,
    story: 'Three trees together evoke abundance and growth.',
    usageExamples: ['森林 — Woodlands', '森羅万象 — All living things'],
    strokeOrderHints: [
      '1. Draw the first 木 on the left.',
      '2. Mirror another 木 on the right.',
      '3. Complete with the center tree strokes.',
    ],
  ),
  const KanjiCandidate(
    id: 'heart',
    character: '志',
    meanings: ['ambition', 'will', 'spirit'],
    readings: ['kokorozashi', 'shi'],
    popularityScore: 4,
    strokeCount: 7,
    radicalCategory: KanjiRadicalCategory.heart,
    gradeLevel: KanjiGradeLevel.grade4,
    story: 'Combines “mind” with sound to indicate sincere aspiration.',
    usageExamples: ['志望 — Aspiration', '有志 — Volunteers'],
    strokeOrderHints: [
      '1. Write the “samurai” component on top.',
      '2. Add the horizontal line that anchors the heart.',
      '3. Finish with the three heart dots.',
    ],
  ),
  const KanjiCandidate(
    id: 'handcraft',
    character: '拓',
    meanings: ['open up', 'cultivate'],
    readings: ['hiraku', 'taku'],
    popularityScore: 3,
    strokeCount: 8,
    radicalCategory: KanjiRadicalCategory.hand,
    gradeLevel: KanjiGradeLevel.jinmeiyo,
    story:
        'Depicts a hand carving into stone—great for creative professionals.',
    usageExamples: ['開拓 — Development', '拓本 — Stone rubbing print'],
    strokeOrderHints: [
      '1. Start with the hand radical strokes on the left.',
      '2. Build the right component from top to bottom.',
      '3. Anchor with the bottom sweeping stroke.',
    ],
  ),
  const KanjiCandidate(
    id: 'voice',
    character: '誠',
    meanings: ['sincerity', 'truth'],
    readings: ['makoto', 'sei'],
    popularityScore: 4,
    strokeCount: 13,
    radicalCategory: KanjiRadicalCategory.speech,
    gradeLevel: KanjiGradeLevel.grade6,
    story: 'Speech radical plus “to become” expresses honest words.',
    usageExamples: ['誠実 — Sincerity', '真誠 — True heart'],
    strokeOrderHints: [
      '1. Write the speech radical starting with the vertical line.',
      '2. Construct the right component from top to bottom.',
      '3. Balance with the final sweeping stroke.',
    ],
  ),
  const KanjiCandidate(
    id: 'flame',
    character: '炎',
    meanings: ['flame', 'passion'],
    readings: ['honoo', 'en'],
    popularityScore: 3,
    strokeCount: 8,
    radicalCategory: KanjiRadicalCategory.fire,
    gradeLevel: KanjiGradeLevel.grade4,
    story: 'Two fires stacked intensify passion—dynamic and energetic.',
    usageExamples: ['炎上 — Blazing up', '炎舞 — Flame dance'],
    strokeOrderHints: [
      '1. Draw the upper fire radical with three strokes.',
      '2. Mirror the fire radical underneath.',
      '3. Add the finishing dots for movement.',
    ],
  ),
  const KanjiCandidate(
    id: 'graceful',
    character: '優',
    meanings: ['gentle', 'superior', 'kind'],
    readings: ['yuu', 'yasashii'],
    popularityScore: 5,
    strokeCount: 17,
    radicalCategory: KanjiRadicalCategory.person,
    gradeLevel: KanjiGradeLevel.grade6,
    story: 'A person next to “graceful” evokes kindness with poise.',
    usageExamples: ['優雅 — Elegance', '女優 — Actress'],
    strokeOrderHints: [
      '1. Begin with the person radical on the left.',
      '2. Layer the complex right component from top to bottom.',
      '3. Close with the heart dots to show compassion.',
    ],
  ),
  const KanjiCandidate(
    id: 'azure',
    character: '蒼',
    meanings: ['deep blue', 'verdant'],
    readings: ['ao', 'sou'],
    popularityScore: 2,
    strokeCount: 13,
    radicalCategory: KanjiRadicalCategory.wood,
    gradeLevel: KanjiGradeLevel.custom,
    story: 'Grass radical plus vivid colour—ideal for nature-inspired brands.',
    usageExamples: ['蒼穹 — Azure sky', '蒼海 — Deep blue ocean'],
    strokeOrderHints: [
      '1. Write the grass radical on top.',
      '2. Add the color component underneath.',
      '3. Finish with the final sweeping stroke.',
    ],
  ),
  const KanjiCandidate(
    id: 'resilient',
    character: '凛',
    meanings: ['dignified', 'chilly'],
    readings: ['rin'],
    popularityScore: 3,
    strokeCount: 15,
    radicalCategory: KanjiRadicalCategory.water,
    gradeLevel: KanjiGradeLevel.jinmeiyo,
    story: 'Icy radical with noble posture, expressing calm determination.',
    usageExamples: ['凛々しい — Gallant', '凛風 — Brisk, dignified breeze'],
    strokeOrderHints: [
      '1. Begin with the ice radical on the left.',
      '2. Stack the central strokes to show stature.',
      '3. End with the sweeping hook for balance.',
    ],
  ),
];
