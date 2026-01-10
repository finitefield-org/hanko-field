// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/storage/preferences.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final privacyPreferencesProvider = AsyncProvider<PrivacyPreferences>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return PrivacyPreferences.fromPreferences(prefs);
});

final privacyPreferencesServiceProvider = Provider<PrivacyPreferencesService>((
  ref,
) {
  final logger = Logger('PrivacyPreferencesService');
  return PrivacyPreferencesService(ref, logger);
});

class PrivacyPreferences {
  const PrivacyPreferences({
    required this.crashReportingAllowed,
    required this.analyticsAllowed,
  });

  final bool crashReportingAllowed;
  final bool analyticsAllowed;

  static const defaults = PrivacyPreferences(
    crashReportingAllowed: false,
    analyticsAllowed: false,
  );

  PrivacyPreferences copyWith({
    bool? crashReportingAllowed,
    bool? analyticsAllowed,
  }) {
    return PrivacyPreferences(
      crashReportingAllowed:
          crashReportingAllowed ?? this.crashReportingAllowed,
      analyticsAllowed: analyticsAllowed ?? this.analyticsAllowed,
    );
  }

  static PrivacyPreferences fromPreferences(SharedPreferences prefs) {
    return PrivacyPreferences(
      crashReportingAllowed:
          prefs.getBool(_crashReportingKey) ?? defaults.crashReportingAllowed,
      analyticsAllowed:
          prefs.getBool(_analyticsKey) ?? defaults.analyticsAllowed,
    );
  }

  Future<void> persist(SharedPreferences prefs) async {
    await Future.wait([
      prefs.setBool(_crashReportingKey, crashReportingAllowed),
      prefs.setBool(_analyticsKey, analyticsAllowed),
    ]);
  }
}

class PrivacyPreferencesService {
  PrivacyPreferencesService(this._ref, this._logger);

  final Ref<PrivacyPreferencesService> _ref;
  final Logger _logger;

  Future<PrivacyPreferences> update({
    bool? crashReportingAllowed,
    bool? analyticsAllowed,
  }) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final current = PrivacyPreferences.fromPreferences(prefs);
    final next = current.copyWith(
      crashReportingAllowed: crashReportingAllowed,
      analyticsAllowed: analyticsAllowed,
    );

    await next.persist(prefs);
    _ref.invalidate(privacyPreferencesProvider);
    _logger.info(
      'Privacy preferences updated '
      '(crash=${next.crashReportingAllowed}, analytics=${next.analyticsAllowed})',
    );
    return next;
  }
}

const _crashReportingKey = 'crash_reporting_allowed';
const _analyticsKey = 'analytics_allowed';
