import 'package:flutter/foundation.dart';

enum DataExportStatus { preparing, ready, expired, failed }

enum DataExportBundle { assets, orders, history }

@immutable
class DataExportOptions {
  const DataExportOptions({
    this.includeAssets = true,
    this.includeOrders = true,
    this.includeHistory = false,
  });

  final bool includeAssets;
  final bool includeOrders;
  final bool includeHistory;

  bool get hasSelection => includeAssets || includeOrders || includeHistory;

  List<DataExportBundle> get bundles {
    final selected = <DataExportBundle>[];
    if (includeAssets) {
      selected.add(DataExportBundle.assets);
    }
    if (includeOrders) {
      selected.add(DataExportBundle.orders);
    }
    if (includeHistory) {
      selected.add(DataExportBundle.history);
    }
    return List<DataExportBundle>.unmodifiable(selected);
  }

  DataExportOptions copyWith({
    bool? includeAssets,
    bool? includeOrders,
    bool? includeHistory,
  }) {
    return DataExportOptions(
      includeAssets: includeAssets ?? this.includeAssets,
      includeOrders: includeOrders ?? this.includeOrders,
      includeHistory: includeHistory ?? this.includeHistory,
    );
  }
}

@immutable
class DataExportArchive {
  DataExportArchive({
    required this.id,
    required this.status,
    required this.requestedAt,
    required List<DataExportBundle> bundles,
    required this.sizeBytes,
    this.completedAt,
    this.availableAt,
    this.expiresAt,
    this.downloadUrl,
    this.lastDownloadedAt,
  }) : bundles = List<DataExportBundle>.unmodifiable(bundles);

  final String id;
  final DataExportStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final DateTime? availableAt;
  final DateTime? expiresAt;
  final List<DataExportBundle> bundles;
  final int sizeBytes;
  final Uri? downloadUrl;
  final DateTime? lastDownloadedAt;

  DataExportArchive copyWith({
    String? id,
    DataExportStatus? status,
    DateTime? requestedAt,
    DateTime? completedAt,
    DateTime? availableAt,
    DateTime? expiresAt,
    List<DataExportBundle>? bundles,
    int? sizeBytes,
    Uri? downloadUrl,
    Object? clearDownloadUrl,
    DateTime? lastDownloadedAt,
  }) {
    return DataExportArchive(
      id: id ?? this.id,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      completedAt: completedAt ?? this.completedAt,
      availableAt: availableAt ?? this.availableAt,
      expiresAt: expiresAt ?? this.expiresAt,
      bundles: bundles == null
          ? this.bundles
          : List<DataExportBundle>.unmodifiable(bundles),
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadUrl: clearDownloadUrl != null
          ? null
          : downloadUrl ?? this.downloadUrl,
      lastDownloadedAt: lastDownloadedAt ?? this.lastDownloadedAt,
    );
  }
}

const Object _sentinel = Object();

@immutable
class DataExportSnapshot {
  DataExportSnapshot({
    required List<DataExportArchive> archives,
    required this.estimatedDuration,
    required this.defaultOptions,
    this.inFlightArchiveId,
    this.updatedAt,
  }) : archives = List<DataExportArchive>.unmodifiable(archives);

  final List<DataExportArchive> archives;
  final Duration estimatedDuration;
  final DataExportOptions defaultOptions;
  final String? inFlightArchiveId;
  final DateTime? updatedAt;

  DataExportArchive? get latestArchive =>
      archives.isEmpty ? null : archives.first;

  bool get hasArchives => archives.isNotEmpty;

  DataExportSnapshot copyWith({
    List<DataExportArchive>? archives,
    Duration? estimatedDuration,
    DataExportOptions? defaultOptions,
    Object? inFlightArchiveId = _sentinel,
    DateTime? updatedAt,
  }) {
    return DataExportSnapshot(
      archives: archives == null
          ? this.archives
          : List<DataExportArchive>.unmodifiable(archives),
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      defaultOptions: defaultOptions ?? this.defaultOptions,
      inFlightArchiveId: inFlightArchiveId == _sentinel
          ? this.inFlightArchiveId
          : inFlightArchiveId as String?,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
