import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/services/permissions/storage_permission_service.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designCreationControllerProvider =
    NotifierProvider<DesignCreationController, DesignCreationState>(
      DesignCreationController.new,
      name: 'designCreationControllerProvider',
    );

class DesignCreationController extends Notifier<DesignCreationState> {
  late final StoragePermissionService _permissionService;

  @override
  DesignCreationState build() {
    _permissionService = ref.read(storagePermissionServiceProvider);
    return const DesignCreationState();
  }

  void selectMode(DesignSourceType mode) {
    state = state.copyWith(
      selectedMode: mode,
      storagePermissionGranted: mode == DesignSourceType.typed,
      clearStyleDraft: true,
      clearSelectedShape: true,
      clearSelectedTemplatePreview: true,
      clearSelectedTemplateTitle: true,
    );
  }

  void selectFilter(DesignCreationFilter? filter) {
    state = state.copyWith(selectedFilter: filter, resetFilter: filter == null);
  }

  void setNameDraft(DesignNameDraft draft) {
    state = state.copyWith(
      selectedMode: state.selectedMode ?? DesignSourceType.typed,
      nameDraft: draft,
      pendingInput: draft.toDesignInput(),
    );
  }

  Future<bool> ensureStoragePermission() async {
    if (state.selectedMode == DesignSourceType.typed) {
      return true;
    }
    final alreadyGranted = await _permissionService.hasAccess();
    if (alreadyGranted) {
      state = state.copyWith(storagePermissionGranted: true);
      return true;
    }
    final granted = await _permissionService.requestAccess();
    state = state.copyWith(storagePermissionGranted: granted);
    return granted;
  }

  void resetSelection() {
    state = const DesignCreationState();
  }

  void updateKanjiMapping(DesignKanjiMapping? mapping) {
    final currentDraft = state.nameDraft;
    if (currentDraft == null) {
      return;
    }
    final updatedDraft = currentDraft.copyWith(
      kanjiMapping: mapping,
      clearKanjiMapping: mapping == null,
    );
    state = state.copyWith(
      nameDraft: updatedDraft,
      pendingInput: updatedDraft.toDesignInput(),
    );
  }

  void setStyleSelection({
    required DesignShape shape,
    required DesignWritingStyle writingStyle,
    required String templateRef,
    String? fontRef,
    String? previewUrl,
    String? templateTitle,
  }) {
    state = state.copyWith(
      styleDraft: DesignStyle(
        writing: writingStyle,
        fontRef: fontRef,
        templateRef: templateRef,
      ),
      selectedShape: shape,
      selectedTemplatePreviewUrl: previewUrl,
      selectedTemplateTitle: templateTitle,
    );
  }

  void applyEditorAdjustments({
    required double strokeWeight,
    required double margin,
    required DesignCanvasAlignment alignment,
    required double rotation,
    required String grid,
  }) {
    final currentStyle = state.styleDraft;
    if (currentStyle == null) {
      return;
    }
    final stroke = (currentStyle.stroke ?? const DesignStroke()).copyWith(
      weight: strokeWeight,
    );
    final layout =
        (currentStyle.layout ??
                const DesignLayout(alignment: DesignCanvasAlignment.center))
            .copyWith(
              grid: grid,
              margin: margin,
              alignment: alignment,
              rotation: rotation,
            );
    state = state.copyWith(
      styleDraft: currentStyle.copyWith(stroke: stroke, layout: layout),
    );
  }
}
