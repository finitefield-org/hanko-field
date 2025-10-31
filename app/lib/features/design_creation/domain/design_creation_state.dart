import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:flutter/foundation.dart';

/// クイックフィルタ種別。アナリティクス用 ID も保持する。
enum DesignCreationFilter {
  personal('personal'),
  business('business'),
  gift('gift');

  const DesignCreationFilter(this.analyticsId);

  final String analyticsId;
}

/// 名前入力ステージのドラフト値
@immutable
class DesignNameDraft {
  const DesignNameDraft({
    required this.persona,
    required this.surname,
    required this.givenName,
    this.surnameReading,
    this.givenNameReading,
    this.kanjiMapping,
  });

  final UserPersona persona;
  final String surname;
  final String givenName;
  final String? surnameReading;
  final String? givenNameReading;
  final DesignKanjiMapping? kanjiMapping;

  /// 表示用の結合済みテキスト。日本語は姓+名、その他はスペース区切り。
  String get combined {
    final trimmedSurname = surname.trim();
    final trimmedGiven = givenName.trim();
    if (trimmedGiven.isEmpty) {
      return trimmedSurname;
    }
    return persona == UserPersona.japanese
        ? '$trimmedSurname$trimmedGiven'
        : '$trimmedSurname $trimmedGiven';
  }

  DesignNameDraft copyWith({
    UserPersona? persona,
    String? surname,
    String? givenName,
    String? surnameReading,
    bool clearSurnameReading = false,
    String? givenNameReading,
    bool clearGivenNameReading = false,
    DesignKanjiMapping? kanjiMapping,
    bool clearKanjiMapping = false,
  }) {
    return DesignNameDraft(
      persona: persona ?? this.persona,
      surname: surname ?? this.surname,
      givenName: givenName ?? this.givenName,
      surnameReading: clearSurnameReading
          ? null
          : surnameReading ?? this.surnameReading,
      givenNameReading: clearGivenNameReading
          ? null
          : givenNameReading ?? this.givenNameReading,
      kanjiMapping: clearKanjiMapping
          ? null
          : kanjiMapping ?? this.kanjiMapping,
    );
  }

  DesignInput toDesignInput() {
    final combinedValue = combined;
    final hasNonAscii = combinedValue.runes.any(
      (codePoint) => codePoint > 0x7F,
    );
    final effectiveMapping =
        kanjiMapping ??
        (hasNonAscii ? DesignKanjiMapping(value: combinedValue) : null);
    return DesignInput(
      sourceType: DesignSourceType.typed,
      rawName: combinedValue,
      kanji: effectiveMapping,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignNameDraft &&
            other.persona == persona &&
            other.surname == surname &&
            other.givenName == givenName &&
            other.surnameReading == surnameReading &&
            other.givenNameReading == givenNameReading &&
            other.kanjiMapping == kanjiMapping);
  }

  @override
  int get hashCode {
    return Object.hash(
      persona,
      surname,
      givenName,
      surnameReading,
      givenNameReading,
      kanjiMapping,
    );
  }
}

@immutable
class DesignCreationState {
  const DesignCreationState({
    this.selectedMode,
    this.selectedFilter,
    this.storagePermissionGranted = false,
    this.nameDraft,
    this.pendingInput,
    this.styleDraft,
    this.selectedShape,
    this.selectedTemplatePreviewUrl,
    this.selectedTemplateTitle,
  });

  final DesignSourceType? selectedMode;
  final DesignCreationFilter? selectedFilter;
  final bool storagePermissionGranted;
  final DesignNameDraft? nameDraft;
  final DesignInput? pendingInput;
  final DesignStyle? styleDraft;
  final DesignShape? selectedShape;
  final String? selectedTemplatePreviewUrl;
  final String? selectedTemplateTitle;

  DesignCreationState copyWith({
    DesignSourceType? selectedMode,
    DesignCreationFilter? selectedFilter,
    bool? storagePermissionGranted,
    bool resetFilter = false,
    DesignNameDraft? nameDraft,
    bool clearNameDraft = false,
    DesignInput? pendingInput,
    bool clearPendingInput = false,
    DesignStyle? styleDraft,
    bool clearStyleDraft = false,
    DesignShape? selectedShape,
    bool clearSelectedShape = false,
    String? selectedTemplatePreviewUrl,
    bool clearSelectedTemplatePreview = false,
    String? selectedTemplateTitle,
    bool clearSelectedTemplateTitle = false,
  }) {
    return DesignCreationState(
      selectedMode: selectedMode ?? this.selectedMode,
      selectedFilter: resetFilter
          ? null
          : selectedFilter ?? this.selectedFilter,
      storagePermissionGranted:
          storagePermissionGranted ?? this.storagePermissionGranted,
      nameDraft: clearNameDraft ? null : nameDraft ?? this.nameDraft,
      pendingInput: clearPendingInput
          ? null
          : pendingInput ?? this.pendingInput,
      styleDraft: clearStyleDraft ? null : styleDraft ?? this.styleDraft,
      selectedShape: clearSelectedShape
          ? null
          : selectedShape ?? this.selectedShape,
      selectedTemplatePreviewUrl: clearSelectedTemplatePreview
          ? null
          : selectedTemplatePreviewUrl ?? this.selectedTemplatePreviewUrl,
      selectedTemplateTitle: clearSelectedTemplateTitle
          ? null
          : selectedTemplateTitle ?? this.selectedTemplateTitle,
    );
  }

  bool get hasSelection => selectedMode != null;

  bool get hasStyleSelection => styleDraft != null && selectedShape != null;

  bool get canProceed {
    if (selectedMode == null) {
      return false;
    }
    if (selectedMode == DesignSourceType.typed) {
      return true;
    }
    return storagePermissionGranted;
  }

  DesignInput? get typedInput => pendingInput;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignCreationState &&
            other.selectedMode == selectedMode &&
            other.selectedFilter == selectedFilter &&
            other.storagePermissionGranted == storagePermissionGranted &&
            other.nameDraft == nameDraft &&
            other.pendingInput == pendingInput &&
            other.styleDraft == styleDraft &&
            other.selectedShape == selectedShape &&
            other.selectedTemplatePreviewUrl == selectedTemplatePreviewUrl &&
            other.selectedTemplateTitle == selectedTemplateTitle);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      selectedMode,
      selectedFilter,
      storagePermissionGranted,
      nameDraft,
      pendingInput,
      styleDraft,
      selectedShape,
      selectedTemplatePreviewUrl,
      selectedTemplateTitle,
    ]);
  }
}
