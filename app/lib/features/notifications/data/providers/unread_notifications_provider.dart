// ignore_for_file: public_member_api_docs

import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/notifications/data/notification_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

class UnreadNotificationsProvider extends AsyncProvider<int> {
  UnreadNotificationsProvider() : super.args(null, autoDispose: false);

  late final seedMut = mutation<int>(#seed);
  late final refreshMut = mutation<int>(#refresh);

  @override
  Future<int> build(Ref<AsyncValue<int>> ref) async {
    final cached = await _loadCachedCount(ref);
    if (cached != null) {
      ref.state = AsyncData(cached);
    }
    final repository = ref.watch(notificationRepositoryProvider);
    return repository.unreadCount();
  }

  Call<int, AsyncValue<int>> seed(int count) => mutate(seedMut, (ref) async {
    ref.state = AsyncData(count);
    return count;
  }, concurrency: Concurrency.dropLatest);

  Call<int, AsyncValue<int>> refresh() => mutate(refreshMut, (ref) async {
    final repository = ref.watch(notificationRepositoryProvider);
    final count = await repository.unreadCount();
    ref.state = AsyncData(count);
    return count;
  }, concurrency: Concurrency.dropLatest);

  Future<int?> _loadCachedCount(Ref<AsyncValue<int>> ref) async {
    final cache = ref.watch(notificationsCacheProvider);
    final gates = ref.watch(appExperienceGatesProvider);
    final cacheKey = LocalCacheKeys.notifications(
      userId: gates.isAuthenticated ? 'current' : 'guest',
    );
    final hit = await cache.read(cacheKey.value);
    final raw = hit?.value['unreadCount'];
    return raw is int ? raw : null;
  }
}

final unreadNotificationsProvider = UnreadNotificationsProvider();
