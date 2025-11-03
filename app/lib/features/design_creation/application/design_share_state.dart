import 'package:flutter/foundation.dart';

@immutable
class DesignShareState {
  const DesignShareState({
    required this.selectedTemplateId,
    this.selectedBackgroundIndex = 0,
    this.watermarkEnabled = true,
    this.includeHashtags = true,
    this.captionDraft = '',
    this.selectedHashtagsByTemplate = const <String, Set<String>>{},
    this.isSharing = false,
    this.errorMessage,
    this.lastSharedAt,
  });

  final String selectedTemplateId;
  final int selectedBackgroundIndex;
  final bool watermarkEnabled;
  final bool includeHashtags;
  final String captionDraft;
  final Map<String, Set<String>> selectedHashtagsByTemplate;
  final bool isSharing;
  final String? errorMessage;
  final DateTime? lastSharedAt;

  Set<String> hashtagsForTemplate(String templateId) {
    final selection = selectedHashtagsByTemplate[templateId];
    if (selection == null || selection.isEmpty) {
      return const <String>{};
    }
    return Set.unmodifiable(selection);
  }

  DesignShareState copyWith({
    String? selectedTemplateId,
    int? selectedBackgroundIndex,
    bool? watermarkEnabled,
    bool? includeHashtags,
    String? captionDraft,
    Map<String, Set<String>>? selectedHashtagsByTemplate,
    bool? isSharing,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastSharedAt,
  }) {
    return DesignShareState(
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      selectedBackgroundIndex:
          selectedBackgroundIndex ?? this.selectedBackgroundIndex,
      watermarkEnabled: watermarkEnabled ?? this.watermarkEnabled,
      includeHashtags: includeHashtags ?? this.includeHashtags,
      captionDraft: captionDraft ?? this.captionDraft,
      selectedHashtagsByTemplate:
          selectedHashtagsByTemplate ?? this.selectedHashtagsByTemplate,
      isSharing: isSharing ?? this.isSharing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastSharedAt: lastSharedAt ?? this.lastSharedAt,
    );
  }
}
