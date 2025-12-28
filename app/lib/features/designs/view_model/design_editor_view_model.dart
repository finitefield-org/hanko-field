// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum DesignCanvasLayout { balanced, vertical, grid, arc }

class DesignEditorState {
  const DesignEditorState({
    required this.displayName,
    required this.shape,
    required this.sizeMm,
    required this.writingStyle,
    required this.layout,
    required this.strokeWeight,
    required this.margin,
    required this.rotation,
    required this.gridSpacing,
    required this.showGrid,
    required this.guidesEnabled,
    required this.hasPendingChanges,
    required this.isSaving,
    required this.canUndo,
    required this.canRedo,
    this.templateName,
    this.lastSavedAt,
  });

  final String displayName;
  final SealShape shape;
  final double sizeMm;
  final WritingStyle writingStyle;
  final DesignCanvasLayout layout;
  final double strokeWeight;
  final double margin;
  final double rotation;
  final double gridSpacing;
  final bool showGrid;
  final bool guidesEnabled;
  final bool hasPendingChanges;
  final bool isSaving;
  final bool canUndo;
  final bool canRedo;
  final String? templateName;
  final DateTime? lastSavedAt;

  DesignEditorState copyWith({
    String? displayName,
    SealShape? shape,
    double? sizeMm,
    WritingStyle? writingStyle,
    DesignCanvasLayout? layout,
    double? strokeWeight,
    double? margin,
    double? rotation,
    double? gridSpacing,
    bool? showGrid,
    bool? guidesEnabled,
    bool? hasPendingChanges,
    bool? isSaving,
    bool? canUndo,
    bool? canRedo,
    String? templateName,
    DateTime? lastSavedAt,
  }) {
    return DesignEditorState(
      displayName: displayName ?? this.displayName,
      shape: shape ?? this.shape,
      sizeMm: sizeMm ?? this.sizeMm,
      writingStyle: writingStyle ?? this.writingStyle,
      layout: layout ?? this.layout,
      strokeWeight: strokeWeight ?? this.strokeWeight,
      margin: margin ?? this.margin,
      rotation: rotation ?? this.rotation,
      gridSpacing: gridSpacing ?? this.gridSpacing,
      showGrid: showGrid ?? this.showGrid,
      guidesEnabled: guidesEnabled ?? this.guidesEnabled,
      hasPendingChanges: hasPendingChanges ?? this.hasPendingChanges,
      isSaving: isSaving ?? this.isSaving,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      templateName: templateName ?? this.templateName,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }
}

class DesignEditorViewModel extends AsyncProvider<DesignEditorState> {
  DesignEditorViewModel() : super.args(null, autoDispose: false);

  final List<DesignEditorState> _undoStack = <DesignEditorState>[];
  final List<DesignEditorState> _redoStack = <DesignEditorState>[];
  Timer? _autosaveTimer;
  DesignEditorState? _initialState;
  bool _trackedStart = false;

  late final setLayoutMut = mutation<DesignCanvasLayout>(#setLayout);
  late final setStrokeMut = mutation<double>(#setStroke);
  late final setMarginMut = mutation<double>(#setMargin);
  late final setRotationMut = mutation<double>(#setRotation);
  late final toggleGridMut = mutation<bool>(#toggleGrid);
  late final setGridSpacingMut = mutation<double>(#setGridSpacing);
  late final toggleGuidesMut = mutation<bool>(#toggleGuides);
  late final undoMut = mutation<bool>(#undo);
  late final redoMut = mutation<bool>(#redo);
  late final resetMut = mutation<bool>(#reset);

  @override
  Future<DesignEditorState> build(Ref ref) async {
    ref.onDispose(() => _autosaveTimer?.cancel());

    final seed = _seedFromCreation(ref);
    _initialState = seed;
    _undoStack.clear();
    _redoStack.clear();

    if (!_trackedStart) {
      _trackedStart = true;
      final analytics = ref.watch(analyticsClientProvider);
      final gates = ref.watch(appExperienceGatesProvider);
      unawaited(
        analytics.track(
          DesignEditorStartedEvent(
            layout: seed.layout.name,
            shape: seed.shape.name,
            sizeMm: seed.sizeMm,
            writingStyle: seed.writingStyle.name,
            templateRef: seed.templateName,
            persona: gates.personaKey,
            locale: gates.localeTag,
          ),
        ),
      );
    }

    return seed;
  }

  Call<DesignCanvasLayout> setLayout(DesignCanvasLayout layout) =>
      mutate(setLayoutMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return layout;
        _commit(ref, current.copyWith(layout: layout));
        return layout;
      }, concurrency: Concurrency.dropLatest);

  Call<double> setStroke(double stroke) => mutate(setStrokeMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return stroke;
    final next = current.copyWith(strokeWeight: stroke.clamp(1.0, 6.0));
    _commit(ref, next);
    return next.strokeWeight;
  }, concurrency: Concurrency.dropLatest);

  Call<double> setMargin(double margin) => mutate(setMarginMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return margin;
    final next = current.copyWith(margin: margin.clamp(4.0, 28.0));
    _commit(ref, next);
    return next.margin;
  }, concurrency: Concurrency.dropLatest);

  Call<double> setRotation(double rotation) =>
      mutate(setRotationMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return rotation;
        final next = current.copyWith(rotation: rotation.clamp(-22.0, 22.0));
        _commit(ref, next);
        return next.rotation;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleGrid(bool enabled) => mutate(toggleGridMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return enabled;
    final next = current.copyWith(showGrid: enabled);
    _commit(ref, next);
    return next.showGrid;
  }, concurrency: Concurrency.dropLatest);

  Call<double> setGridSpacing(double spacing) =>
      mutate(setGridSpacingMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return spacing;
        final next = current.copyWith(
          gridSpacing: spacing.clamp(4.0, 32.0),
          showGrid: true,
        );
        _commit(ref, next);
        return next.gridSpacing;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleGuides(bool enabled) => mutate(toggleGuidesMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return enabled;
    final next = current.copyWith(guidesEnabled: enabled);
    _commit(ref, next);
    return next.guidesEnabled;
  }, concurrency: Concurrency.dropLatest);

  Call<bool> undo() => mutate(undoMut, (ref) async {
    if (_undoStack.isEmpty) return false;
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      _redoStack.add(current);
    }
    final restored = _undoStack.removeLast();
    final next = restored.copyWith(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
      hasPendingChanges: true,
    );
    ref.state = AsyncData(next);
    _scheduleAutosave(ref, next);
    return true;
  }, concurrency: Concurrency.dropLatest);

  Call<bool> redo() => mutate(redoMut, (ref) async {
    if (_redoStack.isEmpty) return false;
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      _undoStack.add(current);
    }
    final restored = _redoStack.removeLast();
    final next = restored.copyWith(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
      hasPendingChanges: true,
    );
    ref.state = AsyncData(next);
    _scheduleAutosave(ref, next);
    return true;
  }, concurrency: Concurrency.dropLatest);

  Call<bool> reset() => mutate(resetMut, (ref) async {
    if (_initialState == null) return false;
    _undoStack.clear();
    _redoStack.clear();
    final resetState = _initialState!.copyWith(
      canUndo: false,
      canRedo: false,
      hasPendingChanges: true,
    );
    ref.state = AsyncData(resetState);
    _scheduleAutosave(ref, resetState);
    return true;
  }, concurrency: Concurrency.restart);

  void _commit(Ref ref, DesignEditorState next) {
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      _undoStack.add(current);
      if (_undoStack.length > 25) {
        _undoStack.removeAt(0);
      }
    }
    _redoStack.clear();
    final updated = next.copyWith(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
      hasPendingChanges: true,
    );
    ref.state = AsyncData(updated);
    _scheduleAutosave(ref, updated);
  }

  void _scheduleAutosave(Ref ref, DesignEditorState state) {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () async {
      final current = ref.watch(this).valueOrNull;
      if (current == null || !current.hasPendingChanges) return;
      ref.state = AsyncData(current.copyWith(isSaving: true));
      await Future<void>.delayed(const Duration(milliseconds: 420));
      final latest = ref.watch(this).valueOrNull ?? current;
      ref.state = AsyncData(
        latest.copyWith(
          isSaving: false,
          hasPendingChanges: false,
          lastSavedAt: DateTime.now(),
          canUndo: _undoStack.isNotEmpty,
          canRedo: _redoStack.isNotEmpty,
        ),
      );
    });
  }

  DesignEditorState _seedFromCreation(Ref ref) {
    final creation = ref.watch(designCreationViewModel).valueOrNull;
    final input = creation?.savedInput;
    final style = creation?.selectedStyle;
    final template = creation?.selectedTemplate;
    final rawName = input?.rawName.trim();

    final defaultLayout = creation?.selectedShape == SealShape.square
        ? DesignCanvasLayout.grid
        : DesignCanvasLayout.balanced;
    final layout = switch (style?.layout?.grid) {
      'grid' => DesignCanvasLayout.grid,
      'vertical' => DesignCanvasLayout.vertical,
      'arc' => DesignCanvasLayout.arc,
      _ => defaultLayout,
    };

    return DesignEditorState(
      displayName: rawName != null && rawName.isNotEmpty ? rawName : '山田太郎',
      shape: creation?.selectedShape ?? SealShape.round,
      sizeMm: creation?.selectedSize?.mm ?? 15,
      writingStyle:
          style?.writing ?? creation?.previewStyle ?? WritingStyle.tensho,
      layout: layout,
      strokeWeight: style?.stroke?.weight ?? 2.4,
      margin: style?.layout?.margin ?? 12,
      rotation: 0,
      gridSpacing: max(style?.layout?.margin ?? 12, 6),
      showGrid: true,
      guidesEnabled: true,
      hasPendingChanges: false,
      isSaving: false,
      canUndo: false,
      canRedo: false,
      templateName: template?.name ?? template?.slug ?? template?.id,
      lastSavedAt: null,
    );
  }
}

final designEditorViewModel = DesignEditorViewModel();
