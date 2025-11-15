import 'dart:async';

import 'package:app/features/profile/data/data_export_repository.dart';
import 'package:app/features/profile/data/data_export_repository_provider.dart';
import 'package:app/features/profile/domain/data_export.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfileExportState {
  ProfileExportState({
    required this.snapshot,
    required this.options,
    this.isGenerating = false,
    this.isRefreshing = false,
    Set<String>? downloadingArchiveIds,
  }) : downloadingArchiveIds = Set.unmodifiable(
         downloadingArchiveIds ?? const <String>{},
       );

  final DataExportSnapshot snapshot;
  final DataExportOptions options;
  final bool isGenerating;
  final bool isRefreshing;
  final Set<String> downloadingArchiveIds;

  DataExportArchive? get latestArchive => snapshot.latestArchive;

  bool isDownloading(String archiveId) =>
      downloadingArchiveIds.contains(archiveId);

  ProfileExportState copyWith({
    DataExportSnapshot? snapshot,
    DataExportOptions? options,
    bool? isGenerating,
    bool? isRefreshing,
    Set<String>? downloadingArchiveIds,
  }) {
    return ProfileExportState(
      snapshot: snapshot ?? this.snapshot,
      options: options ?? this.options,
      isGenerating: isGenerating ?? this.isGenerating,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      downloadingArchiveIds:
          downloadingArchiveIds ?? this.downloadingArchiveIds,
    );
  }
}

class ProfileExportController extends AsyncNotifier<ProfileExportState> {
  DataExportRepository get _repository =>
      ref.read(dataExportRepositoryProvider);

  @override
  Future<ProfileExportState> build() => _loadState();

  Future<ProfileExportState> _loadState({
    DataExportOptions? optionsOverride,
  }) async {
    final snapshot = await _repository.fetchSnapshot();
    return _buildState(snapshot, optionsOverride: optionsOverride);
  }

  ProfileExportState _buildState(
    DataExportSnapshot snapshot, {
    DataExportOptions? optionsOverride,
  }) {
    return ProfileExportState(
      snapshot: snapshot,
      options: optionsOverride ?? snapshot.defaultOptions,
    );
  }

  Future<void> reload() async {
    final previous = state.asData?.value;
    if (previous == null) {
      state = const AsyncLoading();
    } else {
      state = AsyncData(previous.copyWith(isRefreshing: true));
    }
    try {
      final next = await _loadState(optionsOverride: previous?.options);
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(next);
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  void setIncludeAssets(bool include) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        options: current.options.copyWith(includeAssets: include),
      ),
    );
  }

  void setIncludeOrders(bool include) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        options: current.options.copyWith(includeOrders: include),
      ),
    );
  }

  void setIncludeHistory(bool include) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        options: current.options.copyWith(includeHistory: include),
      ),
    );
  }

  Future<void> startExport() async {
    final current = state.asData?.value ?? await future;
    if (current.isGenerating || !current.options.hasSelection) {
      return;
    }
    state = AsyncData(current.copyWith(isGenerating: true));
    try {
      await _repository.requestExport(current.options);
      final snapshot = await _repository.fetchSnapshot();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(_buildState(snapshot));
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isGenerating: false));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<Uri> downloadArchive(String archiveId) async {
    final current = state.asData?.value ?? await future;
    if (current.isDownloading(archiveId)) {
      return Future.error(
        StateError('Archive $archiveId is already downloading'),
      );
    }
    final downloading = {...current.downloadingArchiveIds, archiveId};
    state = AsyncData(current.copyWith(downloadingArchiveIds: downloading));
    try {
      final uri = await _repository.downloadArchive(archiveId);
      final snapshot = await _repository.fetchSnapshot();
      if (!ref.mounted) {
        return uri;
      }
      final base = _buildState(snapshot, optionsOverride: current.options);
      final remaining = {...downloading}..remove(archiveId);
      state = AsyncData(
        base.copyWith(
          isGenerating: current.isGenerating,
          downloadingArchiveIds: remaining,
        ),
      );
      return uri;
    } catch (error, stackTrace) {
      if (ref.mounted) {
        final remaining = {...downloading}..remove(archiveId);
        state = AsyncData(current.copyWith(downloadingArchiveIds: remaining));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final profileExportControllerProvider =
    AsyncNotifierProvider<ProfileExportController, ProfileExportState>(
      ProfileExportController.new,
    );
