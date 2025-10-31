import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/application/style_selection_state.dart';
import 'package:app/features/design_creation/application/style_template_repository_provider.dart';
import 'package:app/features/design_creation/data/style_template_repository.dart';
import 'package:app/features/design_creation/domain/style_template.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final styleSelectionControllerProvider =
    NotifierProvider<StyleSelectionController, StyleSelectionState>(
      StyleSelectionController.new,
      name: 'styleSelectionControllerProvider',
    );

class StyleSelectionController extends Notifier<StyleSelectionState> {
  late final StyleTemplateRepository _repository;
  bool _bootstrapped = false;

  @override
  StyleSelectionState build() {
    _repository = ref.read(styleTemplateRepositoryProvider);
    final persona =
        ref.read(designCreationControllerProvider).nameDraft?.persona ??
        UserPersona.japanese;

    if (!_bootstrapped) {
      _bootstrapped = true;
      Future.microtask(() => _load(persona: persona));
    }

    return StyleSelectionState(
      persona: persona,
      scriptFilter: _defaultScriptForPersona(persona),
    );
  }

  Future<void> retry() async {
    await _load(persona: state.persona, forceReload: true);
  }

  Future<void> _load({
    required UserPersona persona,
    bool forceReload = false,
  }) async {
    state = state.copyWith(isLoading: true, persona: persona, clearError: true);

    try {
      final fonts = await _repository.fetchAvailableFontRefs(persona);
      final templates = await _repository.fetchTemplates(
        persona: persona,
        availableFontRefs: fonts,
      );
      final favorites = await _repository.loadFavoriteTemplateIds();

      final scripts = templates
          .map((template) => template.scriptFamily)
          .toSet();
      final shapes = templates.map((template) => template.shape).toSet();
      final nextScript = _resolveScriptFilter(
        requested: state.scriptFilter,
        available: scripts,
      );

      var selectedId = state.selectedTemplateId;
      final selectedTemplate = _findTemplate(templates, selectedId);
      if (selectedTemplate == null ||
          selectedTemplate.scriptFamily != nextScript ||
          !(selectedTemplate.matchesFonts(fonts) &&
              selectedTemplate.matchesShapes(state.activeShapes))) {
        selectedId = _resolveDefaultTemplateId(
          templates: templates,
          scriptFilter: nextScript,
        );
      }

      state = state.copyWith(
        isLoading: false,
        templates: templates,
        availableFontRefs: fonts,
        availableScripts: scripts,
        availableShapes: shapes,
        activeShapes: forceReload && state.activeShapes.isEmpty
            ? <DesignShape>{}
            : (state.activeShapes.isEmpty ? shapes : state.activeShapes),
        scriptFilter: nextScript,
        selectedTemplateId: selectedId,
        favoriteTemplateIds: favorites,
      );

      final template = _findTemplate(state.templates, state.selectedTemplateId);
      if (template != null) {
        unawaited(_applySelection(template, triggeredByUser: false));
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load templates. Please try again.',
      );
    }
  }

  void changeScript(StyleScriptFamily script) {
    if (script == state.scriptFilter) {
      return;
    }
    state = state.copyWith(scriptFilter: script, clearError: true);
    _reconcileSelection();
  }

  void toggleShapeFilter(DesignShape shape) {
    final current = Set<DesignShape>.from(state.activeShapes);
    if (current.contains(shape)) {
      current.remove(shape);
    } else {
      current.add(shape);
    }
    // Keep empty meaning "all shapes" for UX flexibility.
    state = state.copyWith(activeShapes: current, clearError: true);
    _reconcileSelection();
  }

  void selectTemplate(String templateId) {
    final template = _findTemplate(state.templates, templateId);
    if (template == null) {
      return;
    }
    unawaited(_applySelection(template, triggeredByUser: true));
  }

  Future<void> toggleFavorite(String templateId) async {
    if (state.togglingFavoriteTemplateIds.contains(templateId)) {
      return;
    }

    final previousFavorites = Set<String>.from(state.favoriteTemplateIds);
    final nextFavorites = Set<String>.from(state.favoriteTemplateIds);
    final removed = nextFavorites.remove(templateId);
    if (!removed) {
      nextFavorites.add(templateId);
    }
    final toggling = Set<String>.from(state.togglingFavoriteTemplateIds)
      ..add(templateId);

    state = state.copyWith(
      favoriteTemplateIds: nextFavorites,
      togglingFavoriteTemplateIds: toggling,
      clearError: true,
    );

    try {
      await _repository.saveFavoriteTemplateIds(nextFavorites);
    } catch (_) {
      final rollbackToggling = Set<String>.from(
        state.togglingFavoriteTemplateIds,
      )..remove(templateId);
      state = state.copyWith(
        favoriteTemplateIds: previousFavorites,
        togglingFavoriteTemplateIds: rollbackToggling,
        errorMessage: 'Unable to update favorites. Please retry.',
      );
      return;
    }

    final completedToggling = Set<String>.from(
      state.togglingFavoriteTemplateIds,
    )..remove(templateId);
    state = state.copyWith(togglingFavoriteTemplateIds: completedToggling);
  }

  void clearErrorMessage() {
    state = state.copyWith(clearError: true);
  }

  Future<void> _applySelection(
    StyleTemplate template, {
    required bool triggeredByUser,
  }) async {
    state = state.copyWith(selectedTemplateId: template.id, clearError: true);

    _updateDesignCreationState(template);

    if (!state.prefetchedTemplateIds.contains(template.id)) {
      state = state.copyWith(prefetchingTemplateId: template.id);
      try {
        await _repository.prefetchTemplateAssets(
          template.templateRef ?? template.id,
        );
        final updatedPrefetched = Set<String>.from(state.prefetchedTemplateIds)
          ..add(template.id);
        state = state.copyWith(
          prefetchedTemplateIds: updatedPrefetched,
          clearPrefetchingTemplate: true,
        );
      } catch (_) {
        state = state.copyWith(
          errorMessage: 'Failed to prepare template assets.',
          clearPrefetchingTemplate: true,
        );
      }
    }

    if (triggeredByUser) {
      final analytics = ref.read(analyticsControllerProvider.notifier);
      unawaited(
        analytics.logEvent(
          DesignStyleSelectedEvent(
            templateId: template.templateRef ?? template.id,
            script: template.scriptFamily.analyticsId,
            shape: template.shape.name,
          ),
        ),
      );
    }
  }

  void _reconcileSelection() {
    final visible = state.visibleTemplates;
    if (visible.isEmpty) {
      state = state.copyWith(clearSelectedTemplate: true);
      return;
    }

    final selected = _findTemplate(visible, state.selectedTemplateId);
    if (selected != null) {
      return;
    }
    final fallback = visible.first;
    unawaited(_applySelection(fallback, triggeredByUser: false));
  }

  void _updateDesignCreationState(StyleTemplate template) {
    final notifier = ref.read(designCreationControllerProvider.notifier);
    notifier.setStyleSelection(
      shape: template.shape,
      writingStyle: template.writingStyle,
      templateRef: template.templateRef ?? template.id,
      fontRef: template.fontRefs.isEmpty ? null : template.fontRefs.first,
      previewUrl: template.previewUrl,
      templateTitle: template.title,
    );
  }

  StyleScriptFamily _defaultScriptForPersona(UserPersona persona) {
    return switch (persona) {
      UserPersona.japanese => StyleScriptFamily.kanji,
      UserPersona.foreigner => StyleScriptFamily.roman,
    };
  }

  StyleScriptFamily _resolveScriptFilter({
    required StyleScriptFamily requested,
    required Set<StyleScriptFamily> available,
  }) {
    if (available.isEmpty) {
      return requested;
    }
    if (available.contains(requested)) {
      return requested;
    }
    return available.first;
  }

  String? _resolveDefaultTemplateId({
    required List<StyleTemplate> templates,
    required StyleScriptFamily scriptFilter,
  }) {
    for (final template in templates) {
      if (template.scriptFamily == scriptFilter) {
        return template.id;
      }
    }
    return templates.isEmpty ? null : templates.first.id;
  }

  StyleTemplate? _findTemplate(
    List<StyleTemplate> templates,
    String? templateId,
  ) {
    if (templateId == null) {
      return null;
    }
    for (final template in templates) {
      if (template.id == templateId) {
        return template;
      }
    }
    return null;
  }
}
