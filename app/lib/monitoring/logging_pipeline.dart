// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';
import 'package:app/monitoring/crash_reporting.dart';
import 'package:app/monitoring/device_context_loader.dart';
import 'package:app/monitoring/logging_context.dart';
import 'package:app/privacy/privacy_preferences.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final deviceContextProvider = AsyncProvider<DeviceContext>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final loader = getDeviceContextLoader();
  return loader.loadDeviceContext(
    appVersion: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
  );
});

final logContextProvider = Provider<LogContext>((ref) {
  final deviceContext = ref.watch(deviceContextProvider).valueOrNull;
  final session = ref.watch(userSessionProvider).valueOrNull;
  final locale = ref.watch(appLocaleProvider);

  return LogContext(
    device: deviceContext,
    localeTag: locale.toLanguageTag(),
    userIdHash: _hashUserId(session?.user?.uid),
  );
});

final loggingPipelineInitializerProvider = AsyncProvider<void>((ref) async {
  final logger = Logger('LoggingPipeline');
  final crashReporter = ref.watch(crashReporterProvider);

  Logger.root.level = Level.ALL;

  try {
    await ref.watch(deviceContextProvider.future);
  } catch (e, st) {
    logger.warning('Failed to load device context: $e', e, st);
  }

  void applyContext(LogContext context) {
    unawaited(
      crashReporter.setContext(context).catchError((
        Object error,
        StackTrace st,
      ) {
        logger.fine('Failed to set crash context: $error', error, st);
      }),
    );
  }

  applyContext(ref.read(logContextProvider));

  ref.listen(logContextProvider, (_, next) {
    applyContext(next);
  });

  ref.listen(privacyPreferencesProvider, (_, next) {
    if (next case AsyncData<PrivacyPreferences>(:final value)) {
      if (value.crashReportingAllowed) {
        applyContext(ref.read(logContextProvider));
      }
    }
  });

  final subscription = Logger.root.onRecord.listen((record) {
    final context = ref.read(logContextProvider);
    _forwardLogRecord(crashReporter, record, context, logger);
  });
  ref.onDispose(subscription.cancel);
});

void _forwardLogRecord(
  CrashReporter crashReporter,
  LogRecord record,
  LogContext context,
  Logger logger,
) {
  final payload = _serializeLogRecord(record, context);
  if (!kReleaseMode) {
    debugPrint(payload);
  }

  unawaited(
    crashReporter.log(payload).catchError((Object error, StackTrace stack) {
      logger.fine('Failed to forward log to Crashlytics: $error', error, stack);
    }),
  );

  if (record.loggerName == 'CrashReporter') {
    return;
  }

  if (record.level >= Level.SEVERE) {
    final error = record.error ?? Exception(record.message);
    final stack = record.stackTrace ?? StackTrace.current;
    unawaited(crashReporter.recordError(error, stack, fatal: false));
  }
}

String _serializeLogRecord(LogRecord record, LogContext context) {
  final payload = <String, Object?>{
    'timestamp': record.time.toIso8601String(),
    'logger': record.loggerName,
    'level': record.level.name,
    'message': record.message,
    'error': record.error?.toString(),
    'stack': record.stackTrace?.toString(),
    'context': context.toPayload(),
  };
  return jsonEncode(payload);
}

String? _hashUserId(String? uid) {
  if (uid == null || uid.isEmpty) return null;
  return sha256.convert(utf8.encode(uid)).toString();
}
