import 'package:app/core/domain/entities/design.dart';
import 'package:flutter/foundation.dart';

/// クイックフィルタ種別。アナリティクス用 ID も保持する。
enum DesignCreationFilter {
  personal('personal'),
  business('business'),
  gift('gift');

  const DesignCreationFilter(this.analyticsId);

  final String analyticsId;
}

@immutable
class DesignCreationState {
  const DesignCreationState({
    this.selectedMode,
    this.selectedFilter,
    this.storagePermissionGranted = false,
  });

  final DesignSourceType? selectedMode;
  final DesignCreationFilter? selectedFilter;
  final bool storagePermissionGranted;

  DesignCreationState copyWith({
    DesignSourceType? selectedMode,
    DesignCreationFilter? selectedFilter,
    bool? storagePermissionGranted,
    bool resetFilter = false,
  }) {
    return DesignCreationState(
      selectedMode: selectedMode ?? this.selectedMode,
      selectedFilter: resetFilter
          ? null
          : selectedFilter ?? this.selectedFilter,
      storagePermissionGranted:
          storagePermissionGranted ?? this.storagePermissionGranted,
    );
  }

  bool get hasSelection => selectedMode != null;

  bool get canProceed {
    if (selectedMode == null) {
      return false;
    }
    if (selectedMode == DesignSourceType.typed) {
      return true;
    }
    return storagePermissionGranted;
  }
}
