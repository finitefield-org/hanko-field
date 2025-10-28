import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ストレージ系権限の付与状態を抽象化したサービス。
abstract class StoragePermissionService {
  const StoragePermissionService();

  Future<bool> hasAccess();
  Future<bool> requestAccess();
}

/// 実装が未定のため、常に許可済み扱いとするフェイクサービス。
class SimulatedStoragePermissionService extends StoragePermissionService {
  const SimulatedStoragePermissionService({this.initiallyGranted = true});

  final bool initiallyGranted;

  @override
  Future<bool> hasAccess() async => initiallyGranted;

  @override
  Future<bool> requestAccess() async => initiallyGranted;
}

final storagePermissionServiceProvider = Provider<StoragePermissionService>(
  (ref) => const SimulatedStoragePermissionService(),
  name: 'storagePermissionServiceProvider',
);
