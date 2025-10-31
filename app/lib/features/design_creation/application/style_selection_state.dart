import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/design_creation/domain/style_template.dart';
import 'package:flutter/foundation.dart';

@immutable
class StyleSelectionState {
  const StyleSelectionState({
    this.isLoading = false,
    this.persona = UserPersona.japanese,
    this.scriptFilter = StyleScriptFamily.kanji,
    this.activeShapes = const <DesignShape>{},
    this.availableShapes = const <DesignShape>{},
    this.availableScripts = const <StyleScriptFamily>{},
    this.availableFontRefs = const <String>{},
    this.templates = const <StyleTemplate>[],
    this.selectedTemplateId,
    this.errorMessage,
    this.prefetchingTemplateId,
    this.prefetchedTemplateIds = const <String>{},
    this.favoriteTemplateIds = const <String>{},
    this.togglingFavoriteTemplateIds = const <String>{},
  });

  final bool isLoading;
  final UserPersona persona;
  final StyleScriptFamily scriptFilter;
  final Set<DesignShape> activeShapes;
  final Set<DesignShape> availableShapes;
  final Set<StyleScriptFamily> availableScripts;
  final Set<String> availableFontRefs;
  final List<StyleTemplate> templates;
  final String? selectedTemplateId;
  final String? errorMessage;
  final String? prefetchingTemplateId;
  final Set<String> prefetchedTemplateIds;
  final Set<String> favoriteTemplateIds;
  final Set<String> togglingFavoriteTemplateIds;

  List<StyleTemplate> get visibleTemplates {
    return templates
        .where((template) {
          if (template.scriptFamily != scriptFilter) {
            return false;
          }
          if (!template.matchesShapes(activeShapes)) {
            return false;
          }
          return template.matchesFonts(availableFontRefs);
        })
        .toList(growable: false);
  }

  bool get hasSelection => selectedTemplateId != null;

  StyleSelectionState copyWith({
    bool? isLoading,
    UserPersona? persona,
    StyleScriptFamily? scriptFilter,
    Set<DesignShape>? activeShapes,
    Set<DesignShape>? availableShapes,
    Set<StyleScriptFamily>? availableScripts,
    Set<String>? availableFontRefs,
    List<StyleTemplate>? templates,
    String? selectedTemplateId,
    bool clearSelectedTemplate = false,
    String? errorMessage,
    bool clearError = false,
    String? prefetchingTemplateId,
    bool clearPrefetchingTemplate = false,
    Set<String>? prefetchedTemplateIds,
    Set<String>? favoriteTemplateIds,
    Set<String>? togglingFavoriteTemplateIds,
  }) {
    return StyleSelectionState(
      isLoading: isLoading ?? this.isLoading,
      persona: persona ?? this.persona,
      scriptFilter: scriptFilter ?? this.scriptFilter,
      activeShapes: activeShapes ?? this.activeShapes,
      availableShapes: availableShapes ?? this.availableShapes,
      availableScripts: availableScripts ?? this.availableScripts,
      availableFontRefs: availableFontRefs ?? this.availableFontRefs,
      templates: templates ?? this.templates,
      selectedTemplateId: clearSelectedTemplate
          ? null
          : selectedTemplateId ?? this.selectedTemplateId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      prefetchingTemplateId: clearPrefetchingTemplate
          ? null
          : prefetchingTemplateId ?? this.prefetchingTemplateId,
      prefetchedTemplateIds:
          prefetchedTemplateIds ?? this.prefetchedTemplateIds,
      favoriteTemplateIds: favoriteTemplateIds ?? this.favoriteTemplateIds,
      togglingFavoriteTemplateIds:
          togglingFavoriteTemplateIds ?? this.togglingFavoriteTemplateIds,
    );
  }

  StyleTemplate? selectedTemplate() {
    if (selectedTemplateId == null) {
      return null;
    }
    for (final template in templates) {
      if (template.id == selectedTemplateId) {
        return template;
      }
    }
    return null;
  }
}
