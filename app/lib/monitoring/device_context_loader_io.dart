// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:app/monitoring/logging_context.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceContextLoader {
  Future<DeviceContext> loadDeviceContext({
    required String appVersion,
    required String buildNumber,
  }) async {
    final deviceInfo = DeviceInfoPlugin();

    var os = Platform.operatingSystem;
    var osVersion = Platform.operatingSystemVersion;
    String? model;
    String? brand;
    bool? isPhysical;

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      os = 'android';
      osVersion = info.version.release;
      model = info.model;
      brand = info.brand;
      isPhysical = info.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      os = 'ios';
      osVersion = info.systemVersion;
      model = info.model;
      brand = 'Apple';
      isPhysical = info.isPhysicalDevice;
    } else if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      os = 'macos';
      osVersion = info.osRelease;
      model = info.model;
    } else if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      os = 'windows';
      osVersion =
          '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}';
      model = info.computerName;
    } else if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      os = 'linux';
      osVersion = info.version ?? info.prettyName;
      model = info.machineId;
    }
    return DeviceContext(
      appVersion: appVersion,
      buildNumber: buildNumber,
      os: os,
      osVersion: osVersion,
      deviceModel: model,
      deviceBrand: brand,
      isPhysicalDevice: isPhysical,
    );
  }
}
