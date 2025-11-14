import 'dart:async';

import 'package:app/features/notifications/domain/app_notification.dart';
import 'package:app/features/profile/data/notification_preferences_repository.dart';
import 'package:app/features/profile/data/notification_preferences_repository_provider.dart';
import 'package:app/features/profile/domain/notification_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfileNotificationsState {
  const ProfileNotificationsState({
    required this.saved,
    required this.draft,
    this.isSaving = false,
    this.lastSavedAt,
  });

  final NotificationPreferences saved;
  final NotificationPreferences draft;
  final bool isSaving;
  final DateTime? lastSavedAt;

  bool get hasChanges => saved != draft;

  ProfileNotificationsState copyWith({
    NotificationPreferences? saved,
    NotificationPreferences? draft,
    bool? isSaving,
    DateTime? lastSavedAt,
  }) {
    return ProfileNotificationsState(
      saved: saved ?? this.saved,
      draft: draft ?? this.draft,
      isSaving: isSaving ?? this.isSaving,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }
}

class ProfileNotificationsController
    extends AsyncNotifier<ProfileNotificationsState> {
  NotificationPreferencesRepository get _repository =>
      ref.read(notificationPreferencesRepositoryProvider);

  ProfileNotificationsState? get _current => state.asData?.value;

  @override
  Future<ProfileNotificationsState> build() => _load();

  Future<ProfileNotificationsState> _load() async {
    final preferences = await _repository.fetch();
    return ProfileNotificationsState(
      saved: preferences,
      draft: preferences,
      lastSavedAt: null,
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    try {
      final next = await _load();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(next);
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> saveChanges() async {
    final current = _current ?? await future;
    if (current.isSaving || !current.hasChanges) {
      return;
    }
    final pending = current.copyWith(isSaving: true);
    state = AsyncData(pending);
    try {
      final saved = await _repository.save(pending.draft);
      if (!ref.mounted) {
        return;
      }
      final updated = ProfileNotificationsState(
        saved: saved,
        draft: saved,
        isSaving: false,
        lastSavedAt: DateTime.now(),
      );
      state = AsyncData(updated);
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isSaving: false));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void resetDraft() {
    final current = _current;
    if (current == null || !current.hasChanges || current.isSaving) {
      return;
    }
    state = AsyncData(current.copyWith(draft: current.saved));
  }

  void updateChannel({
    required NotificationCategory category,
    required NotificationChannelType channel,
    required bool enabled,
  }) {
    final current = _current;
    if (current == null) {
      return;
    }
    final nextCategories = [
      for (final entry in current.draft.categories)
        if (entry.category == category)
          switch (channel) {
            NotificationChannelType.push => entry.copyWith(
              pushEnabled: enabled,
            ),
            NotificationChannelType.email => entry.copyWith(
              emailEnabled: enabled,
            ),
          }
        else
          entry,
    ];
    final nextDraft = current.draft.copyWith(categories: nextCategories);
    state = AsyncData(current.copyWith(draft: nextDraft));
  }

  void setDigestFrequency(NotificationDigestFrequency frequency) {
    final current = _current;
    if (current == null) {
      return;
    }
    final schedule = current.draft.digestSchedule.copyWith(
      frequency: frequency,
    );
    _updateDigest(schedule);
  }

  void setDigestTime({required int hour, required int minute}) {
    final current = _current;
    if (current == null) {
      return;
    }
    final schedule = current.draft.digestSchedule.copyWith(
      hour: hour,
      minute: minute,
    );
    _updateDigest(schedule);
  }

  void setDigestWeekday(int weekday) {
    final current = _current;
    if (current == null) {
      return;
    }
    final schedule = current.draft.digestSchedule.copyWith(weekday: weekday);
    _updateDigest(schedule);
  }

  void setDigestDayOfMonth(int dayOfMonth) {
    final current = _current;
    if (current == null) {
      return;
    }
    final schedule = current.draft.digestSchedule.copyWith(
      dayOfMonth: dayOfMonth,
    );
    _updateDigest(schedule);
  }

  void setQuietHoursEnabled(bool enabled) {
    final current = _current;
    if (current == null) {
      return;
    }
    final quietHours = current.draft.quietHours.copyWith(enabled: enabled);
    _updateQuietHours(quietHours);
  }

  void setQuietHoursStart(int minuteOfDay) {
    final current = _current;
    if (current == null) {
      return;
    }
    final quietHours = current.draft.quietHours.copyWith(
      startMinutes: minuteOfDay,
    );
    _updateQuietHours(quietHours);
  }

  void setQuietHoursEnd(int minuteOfDay) {
    final current = _current;
    if (current == null) {
      return;
    }
    final quietHours = current.draft.quietHours.copyWith(
      endMinutes: minuteOfDay,
    );
    _updateQuietHours(quietHours);
  }

  void _updateDigest(NotificationDigestSchedule schedule) {
    final current = _current;
    if (current == null) {
      return;
    }
    final nextDraft = current.draft.copyWith(digestSchedule: schedule);
    state = AsyncData(current.copyWith(draft: nextDraft));
  }

  void _updateQuietHours(NotificationQuietHours quietHours) {
    final current = _current;
    if (current == null) {
      return;
    }
    final nextDraft = current.draft.copyWith(quietHours: quietHours);
    state = AsyncData(current.copyWith(draft: nextDraft));
  }
}

final profileNotificationsControllerProvider =
    AsyncNotifierProvider<
      ProfileNotificationsController,
      ProfileNotificationsState
    >(ProfileNotificationsController.new);
