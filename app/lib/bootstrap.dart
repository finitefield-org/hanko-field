// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/app.dart';
import 'package:app/config/app_flavor.dart';
import 'package:app/firebase/firebase_options.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/firebase/messaging.dart';
import 'package:app/firebase/remote_config.dart';
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
    await configureFirebaseMessaging(container);
  } catch (e, st) {
    logger.warning('Failed to configure Firebase Messaging: $e', e, st);
  }

  try {
    await container.read(remoteConfigInitializerProvider.future);
  } catch (e, st) {
    logger.warning('Failed to initialize Remote Config: $e', e, st);
  }

  runApp(ProviderScope(container: container, child: const HankoFieldApp()));
}
