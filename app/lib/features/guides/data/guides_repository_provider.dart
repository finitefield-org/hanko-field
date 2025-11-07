import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/guides/data/fake_guides_repository.dart';
import 'package:app/features/guides/data/guides_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final guidesRepositoryProvider = Provider<GuidesRepository>((ref) {
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return FakeGuidesRepository(cache: cache);
});
