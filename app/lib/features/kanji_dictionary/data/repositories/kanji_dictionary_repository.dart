// ignore_for_file: public_member_api_docs

import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/designs/data/models/kanji_mapping_models.dart';
import 'package:app/features/designs/data/repositories/kanji_mapping_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class KanjiDictionaryRepository {
  static const fallback = Scope<KanjiDictionaryRepository>.required(
    'kanji.dictionary.repository',
  );

  Future<KanjiSuggestionResult> search({
    required String query,
    KanjiFilter? filter,
  });

  Future<Set<String>> loadFavorites();

  Future<Set<String>> toggleFavorite(String candidateId);

  Future<List<String>> loadHistory();

  Future<List<String>> pushHistory(String query);

  Future<void> clearHistory();
}

final kanjiDictionaryRepositoryProvider = Provider<KanjiDictionaryRepository>((
  ref,
) {
  final mapping = ref.watch(kanjiMappingRepositoryProvider);
  final cache = ref.watch(kanjiCacheProvider);
  final gates = ref.watch(appExperienceGatesProvider);
  final logger = Logger('KanjiDictionaryRepository');
  return LocalKanjiDictionaryRepository(
    mapping: mapping,
    cache: cache,
    gates: gates,
    logger: logger,
  );
});

class LocalKanjiDictionaryRepository implements KanjiDictionaryRepository {
  LocalKanjiDictionaryRepository({
    required KanjiMappingRepository mapping,
    required LocalCacheStore<JsonMap> cache,
    required AppExperienceGates gates,
    Logger? logger,
  }) : _mapping = mapping,
       _cache = cache,
       _gates = gates,
       _logger = logger ?? Logger('LocalKanjiDictionaryRepository');

  final KanjiMappingRepository _mapping;
  final LocalCacheStore<JsonMap> _cache;
  final AppExperienceGates _gates;
  final Logger _logger;

  @override
  Future<KanjiSuggestionResult> search({
    required String query,
    KanjiFilter? filter,
  }) async {
    return _mapping.fetchCandidates(query: query, filter: filter);
  }

  @override
  Future<Set<String>> loadFavorites() => _mapping.loadBookmarks();

  @override
  Future<Set<String>> toggleFavorite(String candidateId) =>
      _mapping.toggleBookmark(candidateId);

  @override
  Future<List<String>> loadHistory() async {
    final key = LocalCacheKeys.kanjiSearchHistory(persona: _gates.personaKey);
    try {
      final hit = await _cache.read(key.value, policy: CachePolicies.kanji);
      final raw = hit?.value['items'];
      if (raw is List) {
        return raw.whereType<String>().toList();
      }
    } catch (e, stack) {
      _logger.warning('Failed to load kanji history', e, stack);
    }
    return const <String>[];
  }

  @override
  Future<List<String>> pushHistory(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return loadHistory();

    final key = LocalCacheKeys.kanjiSearchHistory(persona: _gates.personaKey);
    final current = await loadHistory();
    final next = <String>[
      normalized,
      ...current.where((q) => q != normalized),
    ].take(12).toList();

    await _cache.write(
      key.value,
      <String, Object?>{'items': next},
      policy: CachePolicies.kanji,
      tags: key.tags,
    );
    return next;
  }

  @override
  Future<void> clearHistory() async {
    final key = LocalCacheKeys.kanjiSearchHistory(persona: _gates.personaKey);
    await _cache.write(
      key.value,
      const <String, Object?>{'items': <String>[]},
      policy: CachePolicies.kanji,
      tags: key.tags,
    );
  }
}
