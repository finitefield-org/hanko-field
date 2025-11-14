import 'package:app/features/profile/data/notification_preferences_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
      return FakeNotificationPreferencesRepository();
    });
