import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/notifications/data/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return FakeNotificationRepository(cache: cache);
});
