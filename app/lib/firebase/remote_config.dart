// ignore_for_file: public_member_api_docs

import 'package:app/firebase/firebase_providers.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

const remoteConfigDefaults = <String, Object>{
  'feature_design_ai': false,
  'feature_checkout_enabled': true,
  'min_supported_version_ios': '1.0.0',
  'min_supported_version_android': '1.0.0',
  'latest_version_ios': '',
  'latest_version_android': '',
  'app_store_url_ios': '',
  'app_store_url_android': '',
};

final _remoteConfigLogger = Logger('RemoteConfigInitializer');

final remoteConfigInitializerProvider = AsyncProvider<void>((ref) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);

  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );

    await remoteConfig.setDefaults(remoteConfigDefaults);
    await remoteConfig.fetchAndActivate();
  } catch (e, stack) {
    _remoteConfigLogger.warning(
      'Failed to initialize Remote Config; using cached/default values.',
      e,
      stack,
    );
  }
});
