import 'dart:async';

import 'package:app/core/storage/offline_cache_repository.dart';

class HowToProgressRepository {
  HowToProgressRepository(this._cache);

  final OfflineCacheRepository _cache;

  Future<Set<String>> loadCompletedTutorialIds() async {
    final cached = await _cache.readHowToCompletions();
    return cached.value ?? <String>{};
  }

  Future<void> saveCompletedTutorialIds(Set<String> completed) {
    return _cache.writeHowToCompletions(completed);
  }
}
