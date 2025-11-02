import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/core/monitoring/audit_logger.dart';
import 'package:app/features/design_creation/application/design_version_history_state.dart';
import 'package:app/features/design_creation/application/design_version_repository_provider.dart';
import 'package:app/features/design_creation/data/design_version_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designVersionHistoryControllerProvider =
    NotifierProvider<DesignVersionHistoryController, DesignVersionHistoryState>(
      DesignVersionHistoryController.new,
    );

class DesignVersionHistoryController
    extends Notifier<DesignVersionHistoryState> {
  static const String _designId = 'design-draft-primary';

  late final DesignVersionRepository _repository;
  bool _bootstrapped = false;

  @override
  DesignVersionHistoryState build() {
    _repository = ref.read(designVersionRepositoryProvider);
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
    final previousCurrent = state.currentVersion;
    state = state.copyWith(
      isRollbackInProgress: true,
      clearErrorMessage: true,
      clearRestoredVersion: true,
      clearDuplicatedDesignId: true,
    );
    try {
      final restored = await _repository.rollbackToVersion(
        designId: _designId,
        version: selected.version,
      );
      await _logRollbackSuccess(
        sourceVersion: selected.version,
        appliedVersion: restored.version,
        previousVersion: previousCurrent?.version,
      );
      await _load(selectVersionIndex: 0);
      state = state.copyWith(
        isRollbackInProgress: false,
        restoredVersion: selected.version,
      );
    } catch (error) {
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
      final duplicate = await _repository.duplicateVersion(
        designId: _designId,
        version: selected.version,
      );
      state = state.copyWith(
        isDuplicateInProgress: false,
        duplicatedDesignId: duplicate.id,
      );
    } catch (error) {
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

    String formatDouble(double? value) {
      if (value == null) {
        return '—';
      }
      return value.toStringAsFixed(1);
    }

    String formatDate(DateTime date) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
          ' ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    String formatInput(Design design) {
      return design.input?.kanji?.value ?? design.input?.rawName ?? '—';
    }

    String formatTemplate(Design design) {
      final template = design.style.templateRef ?? '—';
      final font = design.style.fontRef ?? '—';
      return '$template · $font';
    }

    return <DesignVersionDiffEntry>[
      DesignVersionDiffEntry(
        label: 'Version',
        currentValue: 'v${current.version}',
        comparedValue: 'v${compared.version}',
      ),
      DesignVersionDiffEntry(
        label: 'Updated',
        currentValue: formatDate(current.snapshot.updatedAt),
        comparedValue: formatDate(compared.snapshot.updatedAt),
      ),
      DesignVersionDiffEntry(
        label: 'Shape',
        currentValue: current.snapshot.shape.name,
        comparedValue: compared.snapshot.shape.name,
      ),
      DesignVersionDiffEntry(
        label: 'Writing Style',
        currentValue: current.snapshot.style.writing.name,
        comparedValue: compared.snapshot.style.writing.name,
      ),
      DesignVersionDiffEntry(
        label: 'Template · Font',
        currentValue: formatTemplate(current.snapshot),
        comparedValue: formatTemplate(compared.snapshot),
      ),
      DesignVersionDiffEntry(
        label: 'Stroke Weight',
        currentValue: formatDouble(current.snapshot.style.stroke?.weight),
        comparedValue: formatDouble(compared.snapshot.style.stroke?.weight),
      ),
      DesignVersionDiffEntry(
        label: 'Margin (mm)',
        currentValue: formatDouble(current.snapshot.style.layout?.margin),
        comparedValue: formatDouble(compared.snapshot.style.layout?.margin),
      ),
      DesignVersionDiffEntry(
        label: 'Rotation (°)',
        currentValue: formatDouble(current.snapshot.style.layout?.rotation),
        comparedValue: formatDouble(compared.snapshot.style.layout?.rotation),
      ),
      DesignVersionDiffEntry(
        label: 'Alignment',
        currentValue:
            current.snapshot.style.layout?.alignment?.name ?? 'center',
        comparedValue:
            compared.snapshot.style.layout?.alignment?.name ?? 'center',
      ),
      DesignVersionDiffEntry(
        label: 'Grid',
        currentValue: current.snapshot.style.layout?.grid ?? '—',
        comparedValue: compared.snapshot.style.layout?.grid ?? '—',
      ),
      DesignVersionDiffEntry(
        label: 'Input Text',
        currentValue: formatInput(current.snapshot),
        comparedValue: formatInput(compared.snapshot),
      ),
    ];
  }

  Future<void> _load({int? selectVersionIndex}) async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearRestoredVersion: true,
      clearDuplicatedDesignId: true,
    );
    try {
      final versions = await _repository.fetchVersionHistory(_designId);
      final desiredIndex = selectVersionIndex ?? state.selectedIndex;
      state = state.copyWith(
        isLoading: false,
        versions: versions,
        selectedIndex: _resolveSelectedIndex(versions, desiredIndex),
      );
    } catch (error) {
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

  Future<void> _logRollbackSuccess({
    required int sourceVersion,
    required int appliedVersion,
    int? previousVersion,
  }) async {
    final analytics = ref.read(analyticsControllerProvider.notifier);
    final audit = ref.read(auditLoggerProvider);

    await analytics.logEvent(
      DesignVersionRestoredEvent(
        designId: _designId,
        restoredVersion: sourceVersion,
      ),
    );
    await audit.record(
      AuditEvent(
        action: 'design.version.restore',
        targetRef: 'designs/$_designId',
        metadata: <String, Object?>{
          'restored_version': sourceVersion,
          'applied_version': appliedVersion,
          if (previousVersion != null) 'previous_version': previousVersion,
        },
      ),
    );
  }
}
