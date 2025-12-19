// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/storage/preferences.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationCategory { orderUpdates, designUpdates, promotions, guides }

enum NotificationDigestFrequency { daily, weekly, monthly }

const notificationCategories = <NotificationCategory>[
  NotificationCategory.orderUpdates,
  NotificationCategory.designUpdates,
  NotificationCategory.promotions,
  NotificationCategory.guides,
];

class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.digestFrequency,
  });

  final Map<NotificationCategory, bool> pushEnabled;
  final Map<NotificationCategory, bool> emailEnabled;
  final NotificationDigestFrequency digestFrequency;

  static const defaults = NotificationPreferences(
    pushEnabled: {
      NotificationCategory.orderUpdates: true,
      NotificationCategory.designUpdates: true,
      NotificationCategory.promotions: false,
      NotificationCategory.guides: false,
    },
    emailEnabled: {
      NotificationCategory.orderUpdates: true,
      NotificationCategory.designUpdates: false,
      NotificationCategory.promotions: true,
      NotificationCategory.guides: true,
    },
    digestFrequency: NotificationDigestFrequency.weekly,
  );

  bool isPushEnabled(NotificationCategory category) =>
      pushEnabled[category] ?? false;

  bool isEmailEnabled(NotificationCategory category) =>
      emailEnabled[category] ?? false;

  NotificationPreferences copyWith({
    Map<NotificationCategory, bool>? pushEnabled,
    Map<NotificationCategory, bool>? emailEnabled,
    NotificationDigestFrequency? digestFrequency,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      digestFrequency: digestFrequency ?? this.digestFrequency,
    );
  }

  NotificationPreferences updatePush(
    NotificationCategory category,
    bool enabled,
  ) {
    final next = Map<NotificationCategory, bool>.from(pushEnabled);
    next[category] = enabled;
    return copyWith(pushEnabled: next);
  }

  NotificationPreferences updateEmail(
    NotificationCategory category,
    bool enabled,
  ) {
    final next = Map<NotificationCategory, bool>.from(emailEnabled);
    next[category] = enabled;
    return copyWith(emailEnabled: next);
  }

  NotificationPreferences updateDigest(NotificationDigestFrequency frequency) {
    return copyWith(digestFrequency: frequency);
  }

  bool isEquivalentTo(NotificationPreferences other) {
    if (digestFrequency != other.digestFrequency) return false;
    for (final category in notificationCategories) {
      if (pushEnabled[category] != other.pushEnabled[category]) return false;
      if (emailEnabled[category] != other.emailEnabled[category]) return false;
    }
    return true;
  }

  static NotificationPreferences fromPreferences(SharedPreferences prefs) {
    final push = <NotificationCategory, bool>{};
    final email = <NotificationCategory, bool>{};
    for (final category in notificationCategories) {
      push[category] =
          prefs.getBool(_pushKey(category)) ?? defaults.pushEnabled[category]!;
      email[category] =
          prefs.getBool(_emailKey(category)) ??
          defaults.emailEnabled[category]!;
    }

    final frequency =
        _parseFrequency(prefs.getString(_digestKey)) ??
        defaults.digestFrequency;

    return NotificationPreferences(
      pushEnabled: push,
      emailEnabled: email,
      digestFrequency: frequency,
    );
  }

  Future<void> persist(SharedPreferences prefs) async {
    final futures = <Future<bool>>[
      prefs.setString(_digestKey, _frequencyKey(digestFrequency)),
    ];
    for (final category in notificationCategories) {
      futures.add(prefs.setBool(_pushKey(category), isPushEnabled(category)));
      futures.add(prefs.setBool(_emailKey(category), isEmailEnabled(category)));
    }
    await Future.wait(futures);
  }
}

final notificationPreferencesProvider = AsyncProvider<NotificationPreferences>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return NotificationPreferences.fromPreferences(prefs);
});

final notificationPreferencesServiceProvider =
    Provider<NotificationPreferencesService>((ref) {
      final logger = Logger('NotificationPreferencesService');
      return NotificationPreferencesService(ref, logger);
    });

class NotificationPreferencesService {
  NotificationPreferencesService(this._ref, this._logger);

  final Ref _ref;
  final Logger _logger;

  Future<NotificationPreferences> save(
    NotificationPreferences preferences,
  ) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    await preferences.persist(prefs);
    _ref.invalidate(notificationPreferencesProvider);
    _logger.info(
      'Notification preferences updated '
      '(digest=${preferences.digestFrequency.name})',
    );
    return preferences;
  }
}

String _pushKey(NotificationCategory category) =>
    'notification_push_${category.name}';

String _emailKey(NotificationCategory category) =>
    'notification_email_${category.name}';

const _digestKey = 'notification_digest_frequency';

String _frequencyKey(NotificationDigestFrequency frequency) => frequency.name;

NotificationDigestFrequency? _parseFrequency(String? raw) {
  switch (raw) {
    case 'daily':
      return NotificationDigestFrequency.daily;
    case 'weekly':
      return NotificationDigestFrequency.weekly;
    case 'monthly':
      return NotificationDigestFrequency.monthly;
  }
  return null;
}
