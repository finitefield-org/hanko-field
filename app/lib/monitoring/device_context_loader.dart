// ignore_for_file: public_member_api_docs

import 'package:app/monitoring/device_context_loader_io.dart'
    if (dart.library.html) 'package:app/monitoring/device_context_loader_web.dart';

DeviceContextLoader getDeviceContextLoader() => DeviceContextLoader();
