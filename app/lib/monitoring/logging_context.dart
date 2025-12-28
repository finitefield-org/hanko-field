// ignore_for_file: public_member_api_docs

class DeviceContext {
  const DeviceContext({
    required this.appVersion,
    required this.buildNumber,
    required this.os,
    required this.osVersion,
    this.deviceModel,
    this.deviceBrand,
    this.isPhysicalDevice,
  });

  final String appVersion;
  final String buildNumber;
  final String os;
  final String osVersion;
  final String? deviceModel;
  final String? deviceBrand;
  final bool? isPhysicalDevice;

  Map<String, String> toCustomKeys() {
    final keys = <String, String>{
      'app_version': appVersion,
      'app_build': buildNumber,
      'os': os,
      'os_version': osVersion,
    };
    if (deviceModel != null && deviceModel!.isNotEmpty) {
      keys['device_model'] = deviceModel!;
    }
    if (deviceBrand != null && deviceBrand!.isNotEmpty) {
      keys['device_brand'] = deviceBrand!;
    }
    if (isPhysicalDevice != null) {
      keys['device_physical'] = isPhysicalDevice! ? 'true' : 'false';
    }
    return keys;
  }

  Map<String, Object?> toPayload() {
    return {
      'app_version': appVersion,
      'app_build': buildNumber,
      'os': os,
      'os_version': osVersion,
      'device_model': deviceModel,
      'device_brand': deviceBrand,
      'device_physical': isPhysicalDevice,
    };
  }
}

class LogContext {
  const LogContext({
    required this.device,
    required this.localeTag,
    required this.userIdHash,
  });

  final DeviceContext? device;
  final String? localeTag;
  final String? userIdHash;

  Map<String, String> toCustomKeys() {
    final keys = <String, String>{};
    final deviceKeys = device?.toCustomKeys();
    if (deviceKeys != null) {
      keys.addAll(deviceKeys);
    }
    if (localeTag != null && localeTag!.isNotEmpty) {
      keys['locale'] = localeTag!;
    }
    if (userIdHash != null && userIdHash!.isNotEmpty) {
      keys['user_id_hash'] = userIdHash!;
    }
    return keys;
  }

  Map<String, Object?> toPayload() {
    return {
      'device': device?.toPayload(),
      'locale': localeTag,
      'user_id_hash': userIdHash,
    };
  }
}
