// ignore_for_file: public_member_api_docs

import 'package:app/firebase/firebase_providers.dart';
import 'package:app/security/storage_permission_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum PermissionAccessStatus { granted, denied, restricted, unknown }

extension PermissionAccessStatusX on PermissionAccessStatus {
  bool get isGranted => this == PermissionAccessStatus.granted;
}

class PermissionsOnboardingState {
  const PermissionsOnboardingState({
    required this.storageStatus,
    required this.notificationStatus,
  });

  final StoragePermissionStatus storageStatus;
  final PermissionAccessStatus notificationStatus;

  PermissionsOnboardingState copyWith({
    StoragePermissionStatus? storageStatus,
    PermissionAccessStatus? notificationStatus,
  }) {
    return PermissionsOnboardingState(
      storageStatus: storageStatus ?? this.storageStatus,
      notificationStatus: notificationStatus ?? this.notificationStatus,
    );
  }
}

class PermissionsOnboardingViewModel
    extends AsyncProvider<PermissionsOnboardingState> {
  PermissionsOnboardingViewModel() : super.args(null, autoDispose: true);

  late final requestStorageMut = mutation<StoragePermissionStatus>(
    #requestStorage,
  );
  late final requestNotificationsMut = mutation<PermissionAccessStatus>(
    #requestNotifications,
  );
  late final requestAllMut = mutation<PermissionsOnboardingState>(#requestAll);

  @override
  Future<PermissionsOnboardingState> build(
    Ref<AsyncValue<PermissionsOnboardingState>> ref,
  ) async {
    final storageClient = ref.watch(storagePermissionClientProvider);
    final messaging = ref.watch(firebaseMessagingProvider);

    final storageStatus = await storageClient.status();
    final settings = await messaging.getNotificationSettings();

    return PermissionsOnboardingState(
      storageStatus: storageStatus,
      notificationStatus: _notificationStatus(settings.authorizationStatus),
    );
  }

  Call<StoragePermissionStatus, AsyncValue<PermissionsOnboardingState>>
  requestStorage() => mutate(requestStorageMut, (ref) async {
    final client = ref.watch(storagePermissionClientProvider);
    final status = await client.request();
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      ref.state = AsyncData(current.copyWith(storageStatus: status));
    }
    return status;
  }, concurrency: Concurrency.dropLatest);

  Call<PermissionAccessStatus, AsyncValue<PermissionsOnboardingState>>
  requestNotifications() => mutate(requestNotificationsMut, (ref) async {
    final messaging = ref.watch(firebaseMessagingProvider);
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
    final status = _notificationStatus(settings.authorizationStatus);
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      ref.state = AsyncData(current.copyWith(notificationStatus: status));
    }
    return status;
  }, concurrency: Concurrency.dropLatest);

  Call<PermissionsOnboardingState, AsyncValue<PermissionsOnboardingState>>
  requestAll() => mutate(requestAllMut, (ref) async {
    final client = ref.watch(storagePermissionClientProvider);
    final messaging = ref.watch(firebaseMessagingProvider);

    final storageStatus = await client.request();
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    final next = PermissionsOnboardingState(
      storageStatus: storageStatus,
      notificationStatus: _notificationStatus(settings.authorizationStatus),
    );
    ref.state = AsyncData(next);
    return next;
  }, concurrency: Concurrency.dropLatest);
}

PermissionAccessStatus _notificationStatus(
  AuthorizationStatus authorizationStatus,
) {
  return switch (authorizationStatus) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PermissionAccessStatus.granted,
    AuthorizationStatus.denied => PermissionAccessStatus.denied,
    _ => PermissionAccessStatus.unknown,
  };
}

final permissionsOnboardingViewModel = PermissionsOnboardingViewModel();
