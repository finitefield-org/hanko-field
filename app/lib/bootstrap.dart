// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/app.dart';
import 'package:app/config/app_flavor.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/notifications/data/push_notification_navigation.dart';
import 'package:app/features/support/data/push_support_chat_handler.dart';
import 'package:app/firebase/firebase_options.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/firebase/messaging.dart';
import 'package:app/firebase/remote_config.dart';
import 'package:app/monitoring/crash_reporting.dart';
import 'package:app/monitoring/performance_monitoring.dart';
import 'package:app/privacy/privacy_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

Future<void> bootstrap({required AppFlavor flavor}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = Logger('Bootstrap');
  final envFlavor = appFlavorFromEnvironment();

  if (envFlavor != flavor) {
    logger.warning(
      'APP_FLAVOR dart-define ($envFlavor) does not match entrypoint flavor '
      '$flavor. Background isolates will use APP_FLAVOR.',
    );
  }

  final firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform(flavor),
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final container = ProviderContainer(
    overrides: [
      appFlavorScope.overrideWithValue(flavor),
      firebaseAppScope.overrideWithValue(firebaseApp),
    ],
  );

  try {
    await container.read(privacyPreferencesProvider.future);
  } catch (e, st) {
    logger.warning('Failed to load privacy preferences: $e', e, st);
  }

  try {
    await container.read(crashReportingInitializerProvider.future);
  } catch (e, st) {
    logger.warning('Failed to initialize Crashlytics: $e', e, st);
  }

  try {
    await container.read(analyticsInitializerProvider.future);
  } catch (e, st) {
    logger.warning('Failed to initialize Analytics: $e', e, st);
  }

  try {
    await container.read(performanceMonitoringInitializerProvider.future);
  } catch (e, st) {
    logger.warning('Failed to initialize Performance Monitoring: $e', e, st);
  }

  try {
    await configureFirebaseMessaging(container);
  } catch (e, st) {
    logger.warning('Failed to configure Firebase Messaging: $e', e, st);
  }

  try {
    await container.read(remoteConfigInitializerProvider.future);
  } catch (e, st) {
    logger.warning('Failed to initialize Remote Config: $e', e, st);
  }

  try {
    await container.read(pushNotificationNavigationInitializerProvider.future);
  } catch (e, st) {
    logger.warning('Failed to initialize push navigation: $e', e, st);
  }

  try {
    await container.read(supportChatPushHandlerProvider.future);
  } catch (e, st) {
    logger.warning('Failed to initialize support chat push handler: $e', e, st);
  }

  try {
    await container.read(localPersistenceInitializerProvider.future);
  } catch (e, st) {
    logger.warning('Failed to initialize local persistence: $e', e, st);
  }

  final crashReporter = container.read(crashReporterProvider);

  FlutterError.onError = (details) {
    unawaited(crashReporter.recordFlutterError(details));
  };

  runZonedGuarded(
    () {
      runApp(ProviderScope(container: container, child: const HankoFieldApp()));
    },
    (error, stack) =>
        unawaited(crashReporter.recordError(error, stack, fatal: true)),
  );

  unawaited(
    container
        .read(analyticsClientProvider)
        .track(const AppOpenedEvent(entryPoint: 'bootstrap')),
  );
}
