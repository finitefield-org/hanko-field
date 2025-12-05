// ignore_for_file: public_member_api_docs

import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum StoragePermissionStatus { granted, denied, restricted }

extension StoragePermissionStatusX on StoragePermissionStatus {
  bool get isGranted => this == StoragePermissionStatus.granted;

  String get label => switch (this) {
    StoragePermissionStatus.granted => 'granted',
    StoragePermissionStatus.denied => 'denied',
    StoragePermissionStatus.restricted => 'restricted',
  };
}

abstract class StoragePermissionClient {
  Future<StoragePermissionStatus> status();

  Future<StoragePermissionStatus> request();
}

class MemoryStoragePermissionClient implements StoragePermissionClient {
  MemoryStoragePermissionClient({
    StoragePermissionStatus initialStatus = StoragePermissionStatus.granted,
    Logger? logger,
  }) : _status = initialStatus,
       _logger = logger ?? Logger('StoragePermissionClient');

  final Logger _logger;
  StoragePermissionStatus _status;

  @override
  Future<StoragePermissionStatus> status() async {
    _logger.fine('Storage permission status: ${_status.label}');
    return _status;
  }

  @override
  Future<StoragePermissionStatus> request() async {
    _logger.fine('Requesting storage permission (in-memory default grant)');
    _status = StoragePermissionStatus.granted;
    return _status;
  }
}

const storagePermissionClientScope = Scope<StoragePermissionClient>.required(
  'storage.permission.client',
);

final storagePermissionClientProvider = Provider<StoragePermissionClient>((
  ref,
) {
  try {
    return ref.scope(storagePermissionClientScope);
  } on StateError {
    return MemoryStoragePermissionClient();
  }
});
