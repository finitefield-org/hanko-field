import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/design_creation/data/kanji_mapping_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final kanjiMappingRepositoryProvider = Provider<KanjiMappingRepository>((ref) {
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return KanjiMappingRepository(cache: cache);
});
