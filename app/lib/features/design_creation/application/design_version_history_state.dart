import 'package:app/core/domain/entities/design.dart';
import 'package:flutter/foundation.dart';

@immutable
class DesignVersionDiffEntry {
  const DesignVersionDiffEntry({
    required this.label,
    required this.currentValue,
    required this.comparedValue,
  });

  final String label;
  final String currentValue;
  final String comparedValue;

  bool get changed => currentValue != comparedValue;
}

@immutable
class DesignVersionHistoryState {
  const DesignVersionHistoryState({
    this.isLoading = false,
    this.errorMessage,
    this.versions = const <DesignVersion>[],
    this.selectedIndex = 0,
    this.isRollbackInProgress = false,
    this.isDuplicateInProgress = false,
    this.restoredVersion,
    this.duplicatedDesignId,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<DesignVersion> versions;
  final int selectedIndex;
  final bool isRollbackInProgress;
  final bool isDuplicateInProgress;
  final int? restoredVersion;
  final String? duplicatedDesignId;

  DesignVersion? get currentVersion => versions.isEmpty ? null : versions.first;

  DesignVersion? get selectedVersion {
    if (versions.isEmpty) {
      return null;
    }
    if (selectedIndex < 0 || selectedIndex >= versions.length) {
      return versions.first;
    }
    return versions[selectedIndex];
  }

  bool get hasSelection => selectedVersion != null;

  DesignVersionHistoryState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<DesignVersion>? versions,
    int? selectedIndex,
    bool? isRollbackInProgress,
    bool? isDuplicateInProgress,
    int? restoredVersion,
    bool clearRestoredVersion = false,
    String? duplicatedDesignId,
    bool clearDuplicatedDesignId = false,
  }) {
    return DesignVersionHistoryState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      versions: versions ?? this.versions,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isRollbackInProgress: isRollbackInProgress ?? this.isRollbackInProgress,
      isDuplicateInProgress:
          isDuplicateInProgress ?? this.isDuplicateInProgress,
      restoredVersion: clearRestoredVersion
          ? null
          : restoredVersion ?? this.restoredVersion,
      duplicatedDesignId: clearDuplicatedDesignId
          ? null
          : duplicatedDesignId ?? this.duplicatedDesignId,
    );
  }
}
