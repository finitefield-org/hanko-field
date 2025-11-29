// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/config/app_flavor.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/privacy/privacy_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final firebaseCrashlyticsProvider = Provider<FirebaseCrashlytics>((ref) {
  ref.watch(firebaseAppProvider);
  return FirebaseCrashlytics.instance;
});

final crashReporterProvider = Provider<CrashReporter>((ref) {
  final crashlytics = ref.watch(firebaseCrashlyticsProvider);
  final logger = Logger('CrashReporter');
  return CrashReporter(ref, crashlytics, logger);
});

final crashReportingInitializerProvider = AsyncProvider<void>((ref) async {
  final crashReporter = ref.watch(crashReporterProvider);
  final flavor = ref.watch(appFlavorProvider);
  final preferences = await ref.watch(privacyPreferencesProvider.future);

  await crashReporter.initialize(flavor, preferences.crashReportingAllowed);

  ref.listen(privacyPreferencesProvider, (next) {
    if (next case AsyncData<PrivacyPreferences>(:final value)) {
      unawaited(
        crashReporter
            .setCollectionEnabled(value.crashReportingAllowed)
            .catchError((Object error, StackTrace stack) {
              crashReporter.logger.warning(
                'Failed to update Crashlytics collection state: $error',
                error,
                stack,
              );
            }),
      );
    }
  });
});

class CrashReporter {
  CrashReporter(this._ref, this._crashlytics, this.logger);

  final Ref _ref;
  final FirebaseCrashlytics _crashlytics;
  final Logger logger;

  Future<void> initialize(AppFlavor flavor, bool collectionEnabled) async {
    await _crashlytics.setCustomKey('environment', flavor.name);
    await setCollectionEnabled(collectionEnabled);
  }

  Future<void> setCollectionEnabled(bool enabled) {
    return _crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    FlutterError.presentError(details);
    logger.severe(
      'Flutter error: ${details.exceptionAsString()}',
      details.exception,
      details.stack ?? StackTrace.current,
    );
    if (!_allowSending) return;
    await _crashlytics.recordFlutterFatalError(details);
  }

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    logger.severe('Uncaught error: $error', error, stack);
    if (!_allowSending) return;
    await _crashlytics.recordError(error, stack, fatal: fatal);
  }

  bool get _allowSending =>
      _ref
          .watch(privacyPreferencesProvider)
          .valueOrNull
          ?.crashReportingAllowed ??
      false;
}
