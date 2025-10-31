import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/application/design_editor_state.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designEditorControllerProvider =
    NotifierProvider<DesignEditorController, DesignEditorState>(
      DesignEditorController.new,
      name: 'designEditorControllerProvider',
    );

class DesignEditorController extends Notifier<DesignEditorState> {
  static const _autosaveDelay = Duration(milliseconds: 600);
  static const _historyLimit = 25;

  Timer? _autosaveTimer;

  @override
  DesignEditorState build() {
    final creation = ref.read(designCreationControllerProvider);
    final initialConfig = _configFromCreation(creation);
    ref.onDispose(() => _autosaveTimer?.cancel());
    return DesignEditorState(config: initialConfig, baseline: initialConfig);
  }

  void updateAlignment(DesignCanvasAlignment alignment) {
    _commitConfig(state.config.copyWith(alignment: alignment));
  }

  void updateStrokeWidth(double value) {
    _commitConfig(state.config.copyWith(strokeWidth: _clampStroke(value)));
  }

  void updateMargin(double value) {
    _commitConfig(state.config.copyWith(margin: _clampMargin(value)));
  }

  void updateRotation(double degrees) {
    _commitConfig(state.config.copyWith(rotation: _normalizeRotation(degrees)));
  }

  void setGrid(DesignGridType grid) {
    _commitConfig(state.config.copyWith(grid: grid));
  }

  void undo() {
    if (!state.canUndo) {
      return;
    }
    final undoStack = List<DesignEditorConfig>.from(state.undoStack);
    final previous = undoStack.removeLast();
    final redoStack = List<DesignEditorConfig>.from(state.redoStack)
      ..add(state.config);
    state = state.copyWith(
      config: previous,
      undoStack: undoStack,
      redoStack: redoStack,
      clearLastSavedAt: true,
    );
    _scheduleAutosave();
  }

  void redo() {
    if (!state.canRedo) {
      return;
    }
    final redoStack = List<DesignEditorConfig>.from(state.redoStack);
    final next = redoStack.removeLast();
    final undoStack = List<DesignEditorConfig>.from(state.undoStack)
      ..add(state.config);
    state = state.copyWith(
      config: next,
      undoStack: undoStack,
      redoStack: redoStack,
      clearLastSavedAt: true,
    );
    _scheduleAutosave();
  }

  void resetToBaseline() {
    if (state.config == state.baseline) {
      return;
    }
    final undoStack = List<DesignEditorConfig>.from(state.undoStack)
      ..add(state.config);
    state = state.copyWith(
      config: state.baseline,
      undoStack: _trimHistory(undoStack),
      redoStack: const [],
      clearLastSavedAt: true,
    );
    _scheduleAutosave();
  }

  void _commitConfig(DesignEditorConfig next) {
    if (next == state.config) {
      return;
    }
    final undoStack = List<DesignEditorConfig>.from(state.undoStack)
      ..add(state.config);
    state = state.copyWith(
      config: next,
      undoStack: _trimHistory(undoStack),
      redoStack: const [],
      clearLastSavedAt: true,
    );
    _scheduleAutosave();
  }

  List<DesignEditorConfig> _trimHistory(List<DesignEditorConfig> history) {
    if (history.length <= _historyLimit) {
      return history;
    }
    return history.sublist(history.length - _historyLimit);
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, _persistConfig);
  }

  void _persistConfig() {
    _autosaveTimer = null;
    if (!ref.mounted) {
      return;
    }
    final config = state.config;
    state = state.copyWith(isAutosaving: true);
    ref
        .read(designCreationControllerProvider.notifier)
        .applyEditorAdjustments(
          strokeWeight: config.strokeWidth,
          margin: config.margin,
          alignment: config.alignment,
          rotation: config.rotation,
          grid: designGridTypeToKey(config.grid),
        );
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(isAutosaving: false, lastSavedAt: DateTime.now());
  }

  DesignEditorConfig _configFromCreation(DesignCreationState creation) {
    final style = creation.styleDraft;
    final stroke = style?.stroke?.weight ?? 2.5;
    final layout = style?.layout;
    final alignment = layout?.alignment ?? DesignCanvasAlignment.center;
    final margin = layout?.margin ?? 6.0;
    final rotation = layout?.rotation ?? 0;
    final grid = designGridTypeFromKey(layout?.grid);
    return DesignEditorConfig(
      alignment: alignment,
      strokeWidth: _clampStroke(stroke),
      margin: _clampMargin(margin),
      rotation: _normalizeRotation(rotation),
      grid: grid,
    );
  }

  double _normalizeRotation(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  double _clampStroke(double value) => value.clamp(1.0, 10.0);

  double _clampMargin(double value) => value.clamp(0.0, 20.0);
}
