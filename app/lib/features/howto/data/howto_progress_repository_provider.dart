import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/howto/data/howto_progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final howToProgressRepositoryProvider = Provider<HowToProgressRepository>((
  ref,
) {
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return HowToProgressRepository(cache);
});
