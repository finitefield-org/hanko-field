import 'package:app/core/domain/entities/design.dart';
import 'package:flutter/foundation.dart';

enum DesignGridType { none, square, radial }

DesignGridType designGridTypeFromKey(String? key) {
  return switch (key) {
    null || '' || 'none' => DesignGridType.none,
    'radial' => DesignGridType.radial,
    _ => DesignGridType.square,
  };
}

String designGridTypeToKey(DesignGridType type) {
  return switch (type) {
    DesignGridType.none => 'none',
    DesignGridType.square => 'square',
    DesignGridType.radial => 'radial',
  };
}

@immutable
class DesignEditorConfig {
  const DesignEditorConfig({
    required this.alignment,
    required this.strokeWidth,
    required this.margin,
    required this.rotation,
    required this.grid,
  });

  final DesignCanvasAlignment alignment;
  final double strokeWidth;
  final double margin;
  final double rotation;
  final DesignGridType grid;

  bool get showGrid => grid != DesignGridType.none;

  DesignEditorConfig copyWith({
    DesignCanvasAlignment? alignment,
    double? strokeWidth,
    double? margin,
    double? rotation,
    DesignGridType? grid,
  }) {
    return DesignEditorConfig(
      alignment: alignment ?? this.alignment,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      margin: margin ?? this.margin,
      rotation: rotation ?? this.rotation,
      grid: grid ?? this.grid,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignEditorConfig &&
            other.alignment == alignment &&
            other.strokeWidth == strokeWidth &&
            other.margin == margin &&
            other.rotation == rotation &&
            other.grid == grid);
  }

  @override
  int get hashCode =>
      Object.hash(alignment, strokeWidth, margin, rotation, grid);
}

@immutable
class DesignEditorState {
  const DesignEditorState({
    required this.config,
    required this.baseline,
    this.undoStack = const <DesignEditorConfig>[],
    this.redoStack = const <DesignEditorConfig>[],
    this.isAutosaving = false,
    this.lastSavedAt,
  });

  final DesignEditorConfig config;
  final DesignEditorConfig baseline;
  final List<DesignEditorConfig> undoStack;
  final List<DesignEditorConfig> redoStack;
  final bool isAutosaving;
  final DateTime? lastSavedAt;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  bool get isDirty => config != baseline;

  DesignEditorState copyWith({
    DesignEditorConfig? config,
    DesignEditorConfig? baseline,
    List<DesignEditorConfig>? undoStack,
    List<DesignEditorConfig>? redoStack,
    bool? isAutosaving,
    DateTime? lastSavedAt,
    bool clearLastSavedAt = false,
  }) {
    return DesignEditorState(
      config: config ?? this.config,
      baseline: baseline ?? this.baseline,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      isAutosaving: isAutosaving ?? this.isAutosaving,
      lastSavedAt: clearLastSavedAt ? null : lastSavedAt ?? this.lastSavedAt,
    );
  }
}
