import 'package:app/features/notifications/domain/app_notification.dart';
import 'package:flutter/foundation.dart';

enum NotificationChannelType { push, email }

enum NotificationDigestFrequency { daily, weekly, monthly }

@immutable
class NotificationCategoryPreference {
  const NotificationCategoryPreference({
    required this.category,
    required this.pushEnabled,
    required this.emailEnabled,
  });

  final NotificationCategory category;
  final bool pushEnabled;
  final bool emailEnabled;

  NotificationCategoryPreference copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
  }) {
    return NotificationCategoryPreference(
      category: category,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is NotificationCategoryPreference &&
        other.category == category &&
        other.pushEnabled == pushEnabled &&
        other.emailEnabled == emailEnabled;
  }

  @override
  int get hashCode => Object.hash(category, pushEnabled, emailEnabled);
}

@immutable
class NotificationDigestSchedule {
  const NotificationDigestSchedule({
    required this.frequency,
    required this.hour,
    required this.minute,
    this.weekday = DateTime.monday,
    this.dayOfMonth = 1,
  }) : assert(hour >= 0 && hour < 24),
       assert(minute >= 0 && minute < 60),
       assert(weekday >= DateTime.monday && weekday <= DateTime.sunday),
       assert(dayOfMonth >= 1 && dayOfMonth <= 31);

  final NotificationDigestFrequency frequency;
  final int hour;
  final int minute;
  final int weekday;
  final int dayOfMonth;

  NotificationDigestSchedule copyWith({
    NotificationDigestFrequency? frequency,
    int? hour,
    int? minute,
    int? weekday,
    int? dayOfMonth,
  }) {
    return NotificationDigestSchedule(
      frequency: frequency ?? this.frequency,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekday: weekday ?? this.weekday,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is NotificationDigestSchedule &&
        other.frequency == frequency &&
        other.hour == hour &&
        other.minute == minute &&
        other.weekday == weekday &&
        other.dayOfMonth == dayOfMonth;
  }

  @override
  int get hashCode => Object.hash(frequency, hour, minute, weekday, dayOfMonth);
}

@immutable
class NotificationQuietHours {
  const NotificationQuietHours({
    this.enabled = false,
    this.startMinutes = 22 * 60,
    this.endMinutes = 7 * 60,
  }) : assert(startMinutes >= 0 && startMinutes < 24 * 60),
       assert(endMinutes >= 0 && endMinutes < 24 * 60);

  final bool enabled;
  final int startMinutes;
  final int endMinutes;

  NotificationQuietHours copyWith({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
  }) {
    return NotificationQuietHours(
      enabled: enabled ?? this.enabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is NotificationQuietHours &&
        other.enabled == enabled &&
        other.startMinutes == startMinutes &&
        other.endMinutes == endMinutes;
  }

  @override
  int get hashCode => Object.hash(enabled, startMinutes, endMinutes);
}

@immutable
class NotificationPreferences {
  NotificationPreferences({
    required List<NotificationCategoryPreference> categories,
    required this.digestSchedule,
    required this.quietHours,
  }) : categories = List.unmodifiable(categories);

  final List<NotificationCategoryPreference> categories;
  final NotificationDigestSchedule digestSchedule;
  final NotificationQuietHours quietHours;

  NotificationPreferences copyWith({
    List<NotificationCategoryPreference>? categories,
    NotificationDigestSchedule? digestSchedule,
    NotificationQuietHours? quietHours,
  }) {
    return NotificationPreferences(
      categories: categories ?? this.categories,
      digestSchedule: digestSchedule ?? this.digestSchedule,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is NotificationPreferences &&
        listEquals(other.categories, categories) &&
        other.digestSchedule == digestSchedule &&
        other.quietHours == quietHours;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(categories), digestSchedule, quietHours);
}
