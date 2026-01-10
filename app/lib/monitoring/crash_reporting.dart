// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/config/app_flavor.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/monitoring/logging_context.dart';
import 'package:app/privacy/privacy_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
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

  ref.listen(privacyPreferencesProvider, (_, next) {
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

  final Ref<CrashReporter> _ref;
  final FirebaseCrashlytics _crashlytics;
  final Logger logger;

  Future<void> initialize(AppFlavor flavor, bool collectionEnabled) async {
    await _crashlytics.setCustomKey('environment', flavor.name);
    await setCollectionEnabled(collectionEnabled);
  }

  Future<void> setContext(LogContext context) async {
    if (!_allowSending) return;
    final keys = context.toCustomKeys();
    for (final entry in keys.entries) {
      await _crashlytics.setCustomKey(entry.key, entry.value);
    }
    if (context.userIdHash == null || context.userIdHash!.isEmpty) {
      await _crashlytics.setCustomKey('user_id_hash', '');
    }
    await _crashlytics.setUserIdentifier(
      context.userIdHash == null || context.userIdHash!.isEmpty
          ? 'anonymous'
          : context.userIdHash!,
    );
  }

  Future<void> setCollectionEnabled(bool enabled) {
    return _crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }

  Future<void> log(String message) async {
    if (!_allowSending) return;
    await _crashlytics.log(message);
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    FlutterError.presentError(details);
    final stack = details.stack ?? StackTrace.current;
    // The structured logging pipeline prints a single JSON line, which can be
    // truncated by logcat. Emit a non-JSON stack preview as well.
    debugPrint('CrashReporter: Flutter stack (top):\n${_stackPreview(stack)}');
    logger.severe(
      'Flutter error: ${details.exceptionAsString()}',
      details.exception,
      stack,
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

String _stackPreview(StackTrace stack, {int maxLines = 25}) {
  final lines = stack.toString().split('\n');
  if (lines.length <= maxLines) return stack.toString();
  return [
    ...lines.take(maxLines),
    '... (${lines.length - maxLines} more lines)',
  ].join('\n');
}
