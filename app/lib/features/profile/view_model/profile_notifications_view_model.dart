// ignore_for_file: public_member_api_docs

import 'package:app/features/notifications/data/notification_preferences.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileNotificationsViewModel
    extends AsyncProvider<NotificationPreferences> {
  ProfileNotificationsViewModel() : super.args(null, autoDispose: true);

  late final saveMut = mutation<NotificationPreferences>(#save);

  @override
  Future<NotificationPreferences> build(
    Ref<AsyncValue<NotificationPreferences>> ref,
  ) async {
    return ref.watch(notificationPreferencesProvider.future);
  }

  Call<NotificationPreferences, AsyncValue<NotificationPreferences>> save(
    NotificationPreferences preferences,
  ) => mutate(saveMut, (ref) async {
    final service = ref.watch(notificationPreferencesServiceProvider);
    final saved = await service.save(preferences);
    ref.state = AsyncData(saved);
    return saved;
  }, concurrency: Concurrency.dropLatest);
}

final profileNotificationsViewModel = ProfileNotificationsViewModel();
