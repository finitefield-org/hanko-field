import 'package:app/features/profile/application/profile_export_controller.dart';
import 'package:app/features/profile/data/data_export_repository.dart';
import 'package:app/features/profile/data/data_export_repository_provider.dart';
import 'package:app/features/profile/domain/data_export.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockDataExportRepository extends Mock implements DataExportRepository {}

void main() {
  late _MockDataExportRepository repository;

  setUpAll(() {
    registerFallbackValue(const DataExportOptions());
  });

  setUp(() {
    repository = _MockDataExportRepository();
  });

  test('build loads snapshot and exposes default options', () async {
    when(() => repository.fetchSnapshot()).thenAnswer((_) async => _snapshot());
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    final state = await container.read(profileExportControllerProvider.future);

    expect(state.snapshot.archives, isNotEmpty);
    expect(state.options.includeAssets, isTrue);
    expect(state.options.includeOrders, isFalse);
  });

  test('setIncludeHistory toggles the option locally', () async {
    when(() => repository.fetchSnapshot()).thenAnswer((_) async => _snapshot());
    final container = _buildContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(profileExportControllerProvider.notifier);
    await container.read(profileExportControllerProvider.future);

    controller.setIncludeHistory(true);

    final state = container.read(profileExportControllerProvider).value!;
    expect(state.options.includeHistory, isTrue);
  });

  test('startExport requests archive and refreshes snapshot', () async {
    final snapshots = [
      _snapshot(),
      _snapshot().copyWith(
        archives: [
          DataExportArchive(
            id: 'exp-new',
            status: DataExportStatus.preparing,
            requestedAt: DateTime(2024, 5, 1, 12),
            bundles: const [DataExportBundle.assets],
            sizeBytes: 100,
          ),
        ],
      ),
    ];
    when(
      () => repository.fetchSnapshot(),
    ).thenAnswer((_) async => snapshots.removeAt(0));
    when(() => repository.requestExport(any())).thenAnswer((_) async {
      return snapshots.first.archives.first;
    });
    final container = _buildContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(profileExportControllerProvider.notifier);
    await container.read(profileExportControllerProvider.future);

    await controller.startExport();

    final state = container.read(profileExportControllerProvider).value!;
    expect(state.snapshot.latestArchive?.id, 'exp-new');
    expect(state.isGenerating, isFalse);
    verify(() => repository.requestExport(any())).called(1);
  });

  test(
    'downloadArchive prepares secure link and clears downloading state',
    () async {
      final snapshots = [
        _snapshot(),
        _snapshot().copyWith(
          archives: [
            _snapshot().archives.first.copyWith(
              downloadUrl: Uri.parse('https://example.com/a1'),
            ),
          ],
        ),
      ];
      when(
        () => repository.fetchSnapshot(),
      ).thenAnswer((_) async => snapshots.removeAt(0));
      when(
        () => repository.downloadArchive('a1'),
      ).thenAnswer((_) async => Uri.parse('https://example.com/a1'));
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      final controller = container.read(
        profileExportControllerProvider.notifier,
      );
      await container.read(profileExportControllerProvider.future);

      final uri = await controller.downloadArchive('a1');

      expect(uri.toString(), 'https://example.com/a1');
      final state = container.read(profileExportControllerProvider).value!;
      expect(state.isDownloading('a1'), isFalse);
      verify(() => repository.downloadArchive('a1')).called(1);
    },
  );
}

ProviderContainer _buildContainer(DataExportRepository repository) {
  return ProviderContainer(
    overrides: [dataExportRepositoryProvider.overrideWithValue(repository)],
  );
}

DataExportSnapshot _snapshot() {
  return DataExportSnapshot(
    archives: [
      DataExportArchive(
        id: 'a1',
        status: DataExportStatus.ready,
        requestedAt: DateTime(2024, 4, 10, 9, 30),
        completedAt: DateTime(2024, 4, 10, 9, 45),
        bundles: const [DataExportBundle.assets, DataExportBundle.orders],
        sizeBytes: 512000000,
        downloadUrl: Uri.parse('https://example.com/a1'),
      ),
    ],
    estimatedDuration: const Duration(minutes: 3),
    defaultOptions: const DataExportOptions(
      includeAssets: true,
      includeOrders: false,
      includeHistory: false,
    ),
  );
}
