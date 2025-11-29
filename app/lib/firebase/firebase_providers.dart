// ignore_for_file: public_member_api_docs

import 'package:app/config/app_flavor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:miniriverpod/miniriverpod.dart';

const appFlavorScope = Scope<AppFlavor>.required('appFlavor');
const firebaseAppScope = Scope<FirebaseApp>.required('firebaseApp');

final appFlavorProvider = Provider<AppFlavor>((ref) {
  try {
    return ref.scope(appFlavorScope);
  } on StateError {
    return appFlavorFromEnvironment();
  }
});

final firebaseAppProvider = Provider<FirebaseApp>((ref) {
  try {
    return ref.scope(firebaseAppScope);
  } on StateError {
    return Firebase.app();
  }
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  final app = ref.watch(firebaseAppProvider);
  return FirebaseAuth.instanceFor(app: app);
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  ref.watch(firebaseAppProvider);
  return FirebaseMessaging.instance;
});

final firebaseRemoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  final app = ref.watch(firebaseAppProvider);
  return FirebaseRemoteConfig.instanceFor(app: app);
});
