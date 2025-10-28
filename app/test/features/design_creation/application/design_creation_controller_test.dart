import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/services/permissions/storage_permission_service.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStoragePermissionService extends StoragePermissionService {
  _FakeStoragePermissionService({
    required this.hasAccessValue,
    required this.requestResult,
  });

  bool hasAccessValue;
  bool requestResult;
  int requestCount = 0;

  @override
  Future<bool> hasAccess() async => hasAccessValue;

  @override
  Future<bool> requestAccess() async {
    requestCount += 1;
    hasAccessValue = requestResult;
    return requestResult;
  }
}

void main() {
  group('DesignCreationController', () {
    test(
      'selectMode updates typed mode and grants permission automatically',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(
          designCreationControllerProvider.notifier,
        );
        notifier.selectMode(DesignSourceType.typed);

        final state = container.read(designCreationControllerProvider);
        expect(state.selectedMode, DesignSourceType.typed);
        expect(state.storagePermissionGranted, true);
      },
    );

    test('ensureStoragePermission requests access when missing', () async {
      final fakeService = _FakeStoragePermissionService(
        hasAccessValue: false,
        requestResult: true,
      );
      final container = ProviderContainer(
        overrides: [
          storagePermissionServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        designCreationControllerProvider.notifier,
      );
      notifier.selectMode(DesignSourceType.uploaded);

      final granted = await notifier.ensureStoragePermission();
      final state = container.read(designCreationControllerProvider);

      expect(fakeService.requestCount, 1);
      expect(granted, true);
      expect(state.storagePermissionGranted, true);
    });

    test('selectFilter toggles between filters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        designCreationControllerProvider.notifier,
      );
      notifier.selectFilter(DesignCreationFilter.personal);
      var state = container.read(designCreationControllerProvider);
      expect(state.selectedFilter, DesignCreationFilter.personal);

      notifier.selectFilter(null);
      state = container.read(designCreationControllerProvider);
      expect(state.selectedFilter, isNull);
    });
  });
}
