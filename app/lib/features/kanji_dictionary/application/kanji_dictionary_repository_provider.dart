import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/design_creation/application/kanji_mapping_repository_provider.dart';
import 'package:app/features/kanji_dictionary/data/kanji_dictionary_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final kanjiDictionaryRepositoryProvider = Provider<KanjiDictionaryRepository>((
  ref,
) {
  final candidateRepository = ref.watch(kanjiMappingRepositoryProvider);
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return KanjiDictionaryRepository(
    candidateRepository: candidateRepository,
    cache: cache,
  );
});
