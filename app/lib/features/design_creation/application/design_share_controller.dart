import 'package:app/features/design_creation/application/design_share_state.dart';
import 'package:app/features/design_creation/domain/design_share_templates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designShareControllerProvider =
    NotifierProvider<DesignShareController, DesignShareState>(
      DesignShareController.new,
      name: 'designShareControllerProvider',
    );

class DesignShareController extends Notifier<DesignShareState> {
  @override
  DesignShareState build() {
    final initialTemplate = kDesignShareTemplates.first;
    return DesignShareState(
      selectedTemplateId: initialTemplate.id,
      selectedHashtagsByTemplate: {
        for (final template in kDesignShareTemplates)
          template.id: Set<String>.from(template.defaultHashtags),
      },
    );
  }

  void selectTemplate(String templateId) {
    final template = kDesignShareTemplates.maybeById(templateId);
    if (template == null) {
      return;
    }
    if (state.selectedTemplateId == templateId) {
      return;
    }
    state = state.copyWith(
      selectedTemplateId: template.id,
      selectedBackgroundIndex: 0,
      selectedHashtagsByTemplate: _ensureTemplateDefaults(
        state.selectedHashtagsByTemplate,
        template,
      ),
    );
  }

  void selectBackground(int index) {
    final template = kDesignShareTemplates.byId(state.selectedTemplateId);
    final clampedIndex = index.clamp(0, template.backgrounds.length - 1);
    if (state.selectedBackgroundIndex == clampedIndex) {
      return;
    }
    state = state.copyWith(selectedBackgroundIndex: clampedIndex.toInt());
  }

  void toggleWatermark(bool value) {
    if (state.watermarkEnabled == value) {
      return;
    }
    state = state.copyWith(watermarkEnabled: value);
  }

  void toggleIncludeHashtags(bool value) {
    if (state.includeHashtags == value) {
      return;
    }
    state = state.copyWith(includeHashtags: value);
  }

  void updateCaption(String caption) {
    if (state.captionDraft == caption) {
      return;
    }
    state = state.copyWith(captionDraft: caption);
  }

  void applyCaptionSuggestion(String suggestion) {
    state = state.copyWith(captionDraft: suggestion);
  }

  void toggleHashtag(String templateId, String hashtag) {
    final template = kDesignShareTemplates.maybeById(templateId);
    if (template == null) {
      return;
    }
    final normalized = hashtag.trim();
    if (normalized.isEmpty) {
      return;
    }
    final updatedMap = _cloneSelectionMap(state.selectedHashtagsByTemplate);
    final current = updatedMap[templateId] ?? <String>{};
    if (current.contains(normalized)) {
      final next = Set<String>.from(current)..remove(normalized);
      updatedMap[templateId] = next;
    } else {
      final next = Set<String>.from(current)..add(normalized);
      updatedMap[templateId] = next;
    }
    state = state.copyWith(selectedHashtagsByTemplate: updatedMap);
  }

  void resetHashtagsToDefault(String templateId) {
    final template = kDesignShareTemplates.maybeById(templateId);
    if (template == null) {
      return;
    }
    final updatedMap = _cloneSelectionMap(state.selectedHashtagsByTemplate);
    updatedMap[templateId] = Set<String>.from(template.defaultHashtags);
    state = state.copyWith(selectedHashtagsByTemplate: updatedMap);
  }

  void beginShare() {
    state = state.copyWith(isSharing: true, clearError: true);
  }

  void completeShare(DateTime timestamp) {
    state = state.copyWith(
      isSharing: false,
      lastSharedAt: timestamp,
      clearError: true,
    );
  }

  void failShare(String message) {
    state = state.copyWith(isSharing: false, errorMessage: message);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Map<String, Set<String>> _ensureTemplateDefaults(
    Map<String, Set<String>> current,
    DesignShareTemplate template,
  ) {
    final updated = _cloneSelectionMap(current);
    final existing = updated[template.id];
    if (existing == null || existing.isEmpty) {
      updated[template.id] = Set<String>.from(template.defaultHashtags);
    }
    return updated;
  }

  Map<String, Set<String>> _cloneSelectionMap(Map<String, Set<String>> source) {
    return {
      for (final entry in source.entries)
        entry.key: Set<String>.from(entry.value),
    };
  }
}
