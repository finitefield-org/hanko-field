import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/repositories/design_repository.dart';
import 'package:app/features/library/data/design_repository_provider.dart';
import 'package:app/shared/version_history/design_version_diff_builder.dart';
import 'package:app/shared/version_history/design_version_history_state.dart';
import 'package:clock/clock.dart' as clock_package;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final libraryDesignVersionsControllerProvider =
    NotifierProvider.family<
      LibraryDesignVersionsController,
      DesignVersionHistoryState,
      String
    >(
      // Keep an explicit lambda to mirror Riverpod's documented family pattern.
      // ignore: unnecessary_lambdas
      (designId) => LibraryDesignVersionsController(designId),
    );

class LibraryDesignVersionsController
    extends Notifier<DesignVersionHistoryState> {
  LibraryDesignVersionsController(this.designId);

  final String designId;

  late final DesignRepository _repository;
  bool _bootstrapped = false;

  @override
  DesignVersionHistoryState build() {
    _repository = ref.read(designRepositoryProvider);
    if (!_bootstrapped) {
      _bootstrapped = true;
      Future.microtask(_load);
    }
    return const DesignVersionHistoryState(isLoading: true);
  }

  Future<void> refresh() => _load();

  Future<void> selectVersion(int index) async {
    if (index == state.selectedIndex) {
      return;
    }
    state = state.copyWith(selectedIndex: index);
  }

  Future<void> rollbackSelectedVersion() async {
    final selected = state.selectedVersion;
    if (selected == null) {
      return;
    }
    state = state.copyWith(
      isRollbackInProgress: true,
      clearErrorMessage: true,
      clearRestoredVersion: true,
      clearDuplicatedDesignId: true,
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final now = clock_package.clock.now();
      final current = state.currentVersion;
      final baseVersion = current != null ? current.version : selected.version;
      final newVersionNumber = baseVersion + 1;
      final restoredSnapshot = selected.snapshot.copyWith(
        version: newVersionNumber,
        updatedAt: now,
      );
      final restored = DesignVersion(
        version: newVersionNumber,
        snapshot: restoredSnapshot,
        createdAt: now,
        createdBy: restoredSnapshot.ownerRef,
        changeNote: 'Restored from v${selected.version}',
      );
      state = state.copyWith(
        isRollbackInProgress: false,
        versions: [restored, ...state.versions],
        selectedIndex: 0,
        restoredVersion: selected.version,
      );
    } catch (_) {
      state = state.copyWith(
        isRollbackInProgress: false,
        errorMessage: 'Failed to restore version. Please try again.',
      );
    }
  }

  Future<void> duplicateSelectedVersion() async {
    final selected = state.selectedVersion;
    if (selected == null) {
      return;
    }
    state = state.copyWith(
      isDuplicateInProgress: true,
      clearErrorMessage: true,
      clearRestoredVersion: true,
      clearDuplicatedDesignId: true,
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final now = clock_package.clock.now();
      final copyId =
          '${selected.snapshot.id}-copy-${now.millisecondsSinceEpoch}';
      state = state.copyWith(
        isDuplicateInProgress: false,
        duplicatedDesignId: copyId,
      );
    } catch (_) {
      state = state.copyWith(
        isDuplicateInProgress: false,
        errorMessage: 'Failed to duplicate version. Please try again.',
      );
    }
  }

  void clearFeedback() {
    if (state.errorMessage == null &&
        state.restoredVersion == null &&
        state.duplicatedDesignId == null) {
      return;
    }
    state = state.copyWith(
      clearErrorMessage: true,
      clearRestoredVersion: true,
      clearDuplicatedDesignId: true,
    );
  }

  List<DesignVersionDiffEntry> diffEntries() {
    final current = state.currentVersion;
    final compared = state.selectedVersion;
    if (current == null || compared == null) {
      return const <DesignVersionDiffEntry>[];
    }
    return buildVersionDiffEntries(current: current, compared: compared);
  }

  Future<void> _load({int? selectVersionIndex}) async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearRestoredVersion: true,
      clearDuplicatedDesignId: true,
    );
    try {
      final snapshots = await _repository.fetchVersions(designId);
      final versions = _mapSnapshotsToVersions(snapshots);
      final desiredIndex = selectVersionIndex ?? state.selectedIndex;
      state = state.copyWith(
        isLoading: false,
        versions: versions,
        selectedIndex: _resolveSelectedIndex(versions, desiredIndex),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load version history.',
      );
    }
  }

  int _resolveSelectedIndex(List<DesignVersion> versions, int desired) {
    if (versions.isEmpty) {
      return 0;
    }
    if (desired <= 0) {
      return 0;
    }
    if (desired >= versions.length) {
      return versions.length - 1;
    }
    return desired;
  }

  List<DesignVersion> _mapSnapshotsToVersions(List<Design> designs) {
    return [
      for (var index = 0; index < designs.length; index++)
        _toVersionEntry(designs[index], index),
    ];
  }

  DesignVersion _toVersionEntry(Design design, int index) {
    return DesignVersion(
      version: design.version,
      snapshot: design,
      createdAt: design.updatedAt,
      createdBy: design.ownerRef,
      changeNote: _changeNoteFor(design, index),
    );
  }

  String _changeNoteFor(Design design, int index) {
    if (design.lastOrderedAt != null && index == 1) {
      return 'Snapshot captured before recent order.';
    }
    final score = design.ai?.qualityScore;
    if (score != null && score >= 80 && index == 0) {
      return 'AI tweak accepted (score ${score.round()}).';
    }
    switch (design.status) {
      case DesignStatus.ready:
        return 'Marked ready after layout polish.';
      case DesignStatus.ordered:
        return 'Locked for production reference.';
      case DesignStatus.locked:
        return 'Validation hold for registration.';
      case DesignStatus.draft:
        return index.isEven
            ? 'Manual edits saved for review.'
            : 'Spacing adjustments applied.';
    }
  }
}
