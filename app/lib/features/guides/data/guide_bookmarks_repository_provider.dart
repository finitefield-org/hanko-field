import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/guides/data/guide_bookmarks_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final guideBookmarksRepositoryProvider =
    FutureProvider<GuideBookmarksRepository>((ref) async {
      final prefs = await ref.watch(sharedPreferencesProvider.future);
      return GuideBookmarksRepository(prefs);
    });
