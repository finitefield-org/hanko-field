// ignore_for_file: public_member_api_docs

import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:miniriverpod/miniriverpod.dart';

class UnreadNotificationsProvider extends AsyncProvider<int> {
  UnreadNotificationsProvider() : super.args(null, autoDispose: false);

  late final seedMut = mutation<int>(#seed);

  @override
  Future<int> build(Ref ref) async {
    final cache = ref.watch(notificationsCacheProvider);
    final key = LocalCacheKeys.notifications();
    final hit = await cache.read(key.value);

    final existing = _countFromHit(hit);
    if (existing != null) return existing;

    const fallback = 3;
    await cache.write(key.value, {'unreadCount': fallback}, tags: key.tags);
    return fallback;
  }

  Call<int> seed(int count) => mutate(seedMut, (ref) async {
    final cache = ref.watch(notificationsCacheProvider);
    final key = LocalCacheKeys.notifications();
    final payload = <String, Object?>{'unreadCount': count};

    await cache.write(key.value, payload, tags: key.tags);
    ref.state = AsyncData(count);
    return count;
  }, concurrency: Concurrency.dropLatest);

  int? _countFromHit(CacheHit<JsonMap>? hit) {
    if (hit == null) return null;
    final unread = hit.value['unreadCount'];
    if (unread is int) return unread;
    return null;
  }
}

final unreadNotificationsProvider = UnreadNotificationsProvider();
