// ignore_for_file: public_member_api_docs

import 'package:app/monitoring/logging_context.dart';

class DeviceContextLoader {
  Future<DeviceContext> loadDeviceContext({
    required String appVersion,
    required String buildNumber,
  }) async {
    return DeviceContext(
      appVersion: appVersion,
      buildNumber: buildNumber,
      os: 'web',
      osVersion: 'browser',
      deviceModel: 'browser',
    );
  }
}
