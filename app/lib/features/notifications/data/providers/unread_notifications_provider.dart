// ignore_for_file: public_member_api_docs

import 'package:app/features/notifications/data/notification_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

class UnreadNotificationsProvider extends AsyncProvider<int> {
  UnreadNotificationsProvider() : super.args(null, autoDispose: false);

  late final seedMut = mutation<int>(#seed);

  @override
  Future<int> build(Ref ref) async {
    final repository = ref.watch(notificationRepositoryProvider);
    return repository.unreadCount();
  }

  Call<int> seed(int count) => mutate(seedMut, (ref) async {
    ref.state = AsyncData(count);
    return count;
  }, concurrency: Concurrency.dropLatest);
}

final unreadNotificationsProvider = UnreadNotificationsProvider();
