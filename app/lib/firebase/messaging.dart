// ignore_for_file: public_member_api_docs

import 'package:app/config/app_flavor.dart';
import 'package:app/firebase/firebase_options.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final _logger = Logger('FirebaseMessaging');

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final flavor = appFlavorFromEnvironment();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform(flavor),
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  _logger.fine('Background message received: ${message.messageId}');
}

Future<void> configureFirebaseMessaging(ProviderContainer container) async {
  final messaging = container.read(firebaseMessagingProvider);

  await messaging.setAutoInitEnabled(true);

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: false,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
  );
  _logger.info('Notification permission: ${settings.authorizationStatus}');

  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
}
