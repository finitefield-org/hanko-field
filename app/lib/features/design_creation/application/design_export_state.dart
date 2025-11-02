import 'package:app/features/design_creation/application/design_export_types.dart';
import 'package:flutter/foundation.dart';

@immutable
class DesignExportState {
  const DesignExportState({
    this.format = DesignExportFormat.png,
    this.transparentBackground = false,
    this.includeBleed = false,
    this.includeMetadata = true,
    this.watermarkOnShare = true,
    this.isProcessing = false,
    this.isSharing = false,
    this.lastResult,
    this.lastSharedAt,
    this.errorMessage,
    this.shareErrorMessage,
  });

  final DesignExportFormat format;
  final bool transparentBackground;
  final bool includeBleed;
  final bool includeMetadata;
  final bool watermarkOnShare;
  final bool isProcessing;
  final bool isSharing;
  final DesignExportResult? lastResult;
  final DateTime? lastSharedAt;
  final String? errorMessage;
  final String? shareErrorMessage;

  DesignExportState copyWith({
    DesignExportFormat? format,
    bool? transparentBackground,
    bool? includeBleed,
    bool? includeMetadata,
    bool? watermarkOnShare,
    bool? isProcessing,
    bool? isSharing,
    DesignExportResult? lastResult,
    bool clearLastResult = false,
    DateTime? lastSharedAt,
    bool clearLastSharedAt = false,
    String? errorMessage,
    bool clearError = false,
    String? shareErrorMessage,
    bool clearShareError = false,
  }) {
    return DesignExportState(
      format: format ?? this.format,
      transparentBackground:
          transparentBackground ?? this.transparentBackground,
      includeBleed: includeBleed ?? this.includeBleed,
      includeMetadata: includeMetadata ?? this.includeMetadata,
      watermarkOnShare: watermarkOnShare ?? this.watermarkOnShare,
      isProcessing: isProcessing ?? this.isProcessing,
      isSharing: isSharing ?? this.isSharing,
      lastResult: clearLastResult ? null : lastResult ?? this.lastResult,
      lastSharedAt: clearLastSharedAt
          ? null
          : lastSharedAt ?? this.lastSharedAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      shareErrorMessage: clearShareError
          ? null
          : shareErrorMessage ?? this.shareErrorMessage,
    );
  }
}

@immutable
class DesignExportResult {
  const DesignExportResult({
    required this.format,
    required this.filePath,
    required this.generatedAt,
    required this.options,
    this.metadataPath,
  });

  final DesignExportFormat format;
  final String filePath;
  final DateTime generatedAt;
  final DesignExportOptionsSnapshot options;
  final String? metadataPath;
}

@immutable
class DesignExportOptionsSnapshot {
  const DesignExportOptionsSnapshot({
    required this.transparentBackground,
    required this.includeBleed,
    required this.includeMetadata,
  });

  final bool transparentBackground;
  final bool includeBleed;
  final bool includeMetadata;
}
