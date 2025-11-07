import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/design_creation/data/kanji_mapping_repository.dart';
import 'package:app/features/design_creation/domain/kanji_candidate.dart';

class KanjiDictionaryRepository {
  KanjiDictionaryRepository({
    required KanjiMappingRepository candidateRepository,
    required OfflineCacheRepository cache,
    this.historyLimit = 8,
    this.viewedLimit = 6,
  }) : _candidateRepository = candidateRepository,
       _cache = cache;

  final KanjiMappingRepository _candidateRepository;
  final OfflineCacheRepository _cache;
  final int historyLimit;
  final int viewedLimit;

  Future<KanjiCandidateFetchResult> searchCandidates({
    String query = '',
    Set<KanjiStrokeBucket> strokeFilters = const {},
    Set<KanjiRadicalCategory> radicalFilters = const {},
  }) {
    return _candidateRepository.fetchCandidates(
      query: query,
      strokeFilters: strokeFilters,
      radicalFilters: radicalFilters,
    );
  }

  Future<Set<String>> loadBookmarks() => _candidateRepository.loadBookmarks();

  Future<void> saveBookmarks(Set<String> bookmarks) =>
      _candidateRepository.saveBookmarks(bookmarks);

  Future<List<String>> loadSearchHistory() async {
    final cached = await _cache.readKanjiSearchHistory();
    if (cached.hasValue && cached.value != null) {
      return List.unmodifiable(cached.value!);
    }
    return const [];
  }

  Future<List<String>> upsertSearchHistory(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return loadSearchHistory();
    }
    final cached = await _cache.readKanjiSearchHistory();
    final history = List<String>.from(cached.value ?? const <String>[]);
    history.removeWhere((element) => element == normalized);
    history.insert(0, normalized);
    if (history.length > historyLimit) {
      history.removeRange(historyLimit, history.length);
    }
    await _cache.writeKanjiSearchHistory(history);
    return List.unmodifiable(history);
  }

  Future<List<String>> loadViewedEntries() async {
    final cached = await _cache.readKanjiViewedEntries();
    if (cached.hasValue && cached.value != null) {
      return List.unmodifiable(cached.value!);
    }
    return const [];
  }

  Future<List<String>> registerViewedEntry(String entryId) async {
    if (entryId.isEmpty) {
      return loadViewedEntries();
    }
    final cached = await _cache.readKanjiViewedEntries();
    final ids = List<String>.from(cached.value ?? const <String>[]);
    ids.removeWhere((value) => value == entryId);
    ids.insert(0, entryId);
    if (ids.length > viewedLimit) {
      ids.removeRange(viewedLimit, ids.length);
    }
    await _cache.writeKanjiViewedEntries(ids);
    return List.unmodifiable(ids);
  }

  List<KanjiCandidate> featuredCandidates({int limit = 6}) =>
      _candidateRepository.featuredCandidates(limit: limit);

  KanjiCandidate? candidateById(String id) =>
      _candidateRepository.candidateById(id);

  List<KanjiCandidate> candidatesByIds(Iterable<String> ids) =>
      _candidateRepository.candidatesByIds(ids);

  List<KanjiCandidate> allCandidates() => _candidateRepository.allCandidates();
}
