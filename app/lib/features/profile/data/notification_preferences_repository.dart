import 'dart:async';

import 'package:app/features/notifications/domain/app_notification.dart';
import 'package:app/features/profile/domain/notification_preferences.dart';

abstract class NotificationPreferencesRepository {
  Future<NotificationPreferences> fetch();
  Future<NotificationPreferences> save(NotificationPreferences preferences);
}

class FakeNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  FakeNotificationPreferencesRepository({
    Duration latency = const Duration(milliseconds: 320),
    NotificationPreferences? seed,
  }) : _latency = latency,
       _preferences = seed ?? _defaultPreferences;

  final Duration _latency;
  NotificationPreferences _preferences;

  static NotificationPreferences get _defaultPreferences {
    return NotificationPreferences(
      categories: const [
        NotificationCategoryPreference(
          category: NotificationCategory.order,
          pushEnabled: true,
          emailEnabled: true,
        ),
        NotificationCategoryPreference(
          category: NotificationCategory.production,
          pushEnabled: true,
          emailEnabled: true,
        ),
        NotificationCategoryPreference(
          category: NotificationCategory.promotion,
          pushEnabled: true,
          emailEnabled: false,
        ),
        NotificationCategoryPreference(
          category: NotificationCategory.guide,
          pushEnabled: false,
          emailEnabled: true,
        ),
        NotificationCategoryPreference(
          category: NotificationCategory.system,
          pushEnabled: true,
          emailEnabled: true,
        ),
      ],
      digestSchedule: const NotificationDigestSchedule(
        frequency: NotificationDigestFrequency.daily,
        hour: 19,
        minute: 0,
        weekday: DateTime.monday,
        dayOfMonth: 15,
      ),
      quietHours: const NotificationQuietHours(
        enabled: true,
        startMinutes: 23 * 60,
        endMinutes: 7 * 60,
      ),
    );
  }

  @override
  Future<NotificationPreferences> fetch() async {
    await Future.delayed(_latency);
    return _preferences;
  }

  @override
  Future<NotificationPreferences> save(
    NotificationPreferences preferences,
  ) async {
    await Future.delayed(_latency * 2);
    _preferences = preferences;
    return _preferences;
  }
}
