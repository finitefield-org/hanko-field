import 'dart:async';

import 'package:app/features/profile/domain/data_export.dart';

abstract class DataExportRepository {
  Future<DataExportSnapshot> fetchSnapshot();
  Future<DataExportArchive> requestExport(DataExportOptions options);
  Future<Uri> downloadArchive(String archiveId);
}

class FakeDataExportRepository implements DataExportRepository {
  FakeDataExportRepository({
    Duration latency = const Duration(milliseconds: 420),
    DateTime Function()? now,
  }) : _latency = latency,
       _now = now ?? DateTime.now {
    final seed = _seedArchives(_now());
    _snapshot = DataExportSnapshot(
      archives: seed,
      estimatedDuration: const Duration(minutes: 3, seconds: 30),
      defaultOptions: const DataExportOptions(
        includeAssets: true,
        includeOrders: true,
        includeHistory: false,
      ),
      updatedAt: _now(),
    );
    final active = seed.firstWhere(
      (archive) => archive.status == DataExportStatus.preparing,
      orElse: () => seed.isEmpty ? _emptyArchive : seed.first,
    );
    if (active.status == DataExportStatus.preparing) {
      _snapshot = _snapshot.copyWith(inFlightArchiveId: active.id);
    }
  }

  final Duration _latency;
  final DateTime Function() _now;
  late DataExportSnapshot _snapshot;

  static DataExportArchive get _emptyArchive => DataExportArchive(
    id: 'empty',
    status: DataExportStatus.ready,
    requestedAt: DateTime.fromMillisecondsSinceEpoch(0),
    bundles: const [],
    sizeBytes: 0,
  );

  static List<DataExportArchive> _seedArchives(DateTime now) {
    return [
      DataExportArchive(
        id: 'export-active',
        status: DataExportStatus.preparing,
        requestedAt: now.subtract(const Duration(minutes: 4)),
        availableAt: now.add(const Duration(minutes: 1, seconds: 15)),
        expiresAt: now.add(const Duration(days: 30)),
        bundles: const [DataExportBundle.assets, DataExportBundle.history],
        sizeBytes: 280 * 1024 * 1024,
      ),
      DataExportArchive(
        id: 'export-ready-1',
        status: DataExportStatus.ready,
        requestedAt: now.subtract(const Duration(days: 2, hours: 4)),
        completedAt: now.subtract(
          const Duration(days: 2, hours: 3, minutes: 20),
        ),
        availableAt: now.subtract(
          const Duration(days: 2, hours: 3, minutes: 20),
        ),
        expiresAt: now.add(const Duration(days: 28)),
        bundles: const [DataExportBundle.assets, DataExportBundle.orders],
        sizeBytes: 460 * 1024 * 1024,
        downloadUrl: Uri.parse(
          'https://downloads.hanko-field.com/data/export-ready-1.zip',
        ),
        lastDownloadedAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      DataExportArchive(
        id: 'export-expired',
        status: DataExportStatus.expired,
        requestedAt: now.subtract(const Duration(days: 45)),
        completedAt: now.subtract(const Duration(days: 44, hours: 20)),
        availableAt: now.subtract(const Duration(days: 44, hours: 20)),
        expiresAt: now.subtract(const Duration(days: 15)),
        bundles: const [
          DataExportBundle.assets,
          DataExportBundle.orders,
          DataExportBundle.history,
        ],
        sizeBytes: 512 * 1024 * 1024,
      ),
    ];
  }

  @override
  Future<DataExportSnapshot> fetchSnapshot() async {
    await Future<void>.delayed(_latency);
    _settleArchives();
    _snapshot = _snapshot.copyWith(updatedAt: _now());
    return _snapshot;
  }

  @override
  Future<DataExportArchive> requestExport(DataExportOptions options) async {
    await Future<void>.delayed(_latency * 2);
    _settleArchives();
    final requestedAt = _now();
    final archive = DataExportArchive(
      id: 'export-${requestedAt.microsecondsSinceEpoch}',
      status: DataExportStatus.preparing,
      requestedAt: requestedAt,
      availableAt: requestedAt.add(_snapshot.estimatedDuration),
      expiresAt: requestedAt.add(const Duration(days: 30)),
      bundles: options.bundles,
      sizeBytes: _estimateSizeBytes(options),
    );
    _snapshot = _snapshot.copyWith(
      archives: [archive, ..._snapshot.archives],
      defaultOptions: options,
      inFlightArchiveId: archive.id,
      updatedAt: requestedAt,
    );
    return archive;
  }

  @override
  Future<Uri> downloadArchive(String archiveId) async {
    await Future<void>.delayed(_latency);
    _settleArchives();
    final index = _snapshot.archives.indexWhere(
      (archive) => archive.id == archiveId,
    );
    if (index == -1) {
      throw StateError('Archive $archiveId not found');
    }
    final archive = _snapshot.archives[index];
    if (archive.status != DataExportStatus.ready) {
      throw StateError('Archive $archiveId is not ready');
    }
    final uri = archive.downloadUrl ?? _buildSignedUrl(archiveId);
    final updated = archive.copyWith(
      downloadUrl: uri,
      lastDownloadedAt: _now(),
    );
    _replaceArchive(updated);
    _snapshot = _snapshot.copyWith(updatedAt: _now());
    return uri;
  }

  void _replaceArchive(DataExportArchive archive) {
    final archives = [
      for (final current in _snapshot.archives)
        if (current.id == archive.id) archive else current,
    ];
    _snapshot = _snapshot.copyWith(archives: archives);
  }

  void _settleArchives() {
    final now = _now();
    final archives = <DataExportArchive>[];
    for (final archive in _snapshot.archives) {
      var next = archive;
      if (archive.status == DataExportStatus.preparing &&
          archive.availableAt != null &&
          !now.isBefore(archive.availableAt!)) {
        next = archive.copyWith(
          status: DataExportStatus.ready,
          completedAt: archive.availableAt,
          downloadUrl: archive.downloadUrl ?? _buildSignedUrl(archive.id),
        );
      }
      if (next.status == DataExportStatus.ready &&
          next.expiresAt != null &&
          now.isAfter(next.expiresAt!)) {
        next = next.copyWith(
          status: DataExportStatus.expired,
          clearDownloadUrl: Object(),
        );
      }
      archives.add(next);
    }
    final hasActiveArchive = archives.any(
      (archive) =>
          archive.id == _snapshot.inFlightArchiveId &&
          archive.status == DataExportStatus.preparing,
    );
    _snapshot = _snapshot.copyWith(
      archives: archives,
      inFlightArchiveId: hasActiveArchive ? _snapshot.inFlightArchiveId : null,
    );
  }

  Uri _buildSignedUrl(String archiveId) {
    const domain = 'https://downloads.hanko-field.com/data';
    return Uri.parse('$domain/$archiveId.zip?token=${archiveId.hashCode}');
  }

  int _estimateSizeBytes(DataExportOptions options) {
    var total = 50 * 1024 * 1024;
    if (options.includeAssets) {
      total += 260 * 1024 * 1024;
    }
    if (options.includeOrders) {
      total += 80 * 1024 * 1024;
    }
    if (options.includeHistory) {
      total += 48 * 1024 * 1024;
    }
    return total;
  }
}
