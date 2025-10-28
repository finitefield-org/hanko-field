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
  });

  final UserPersona persona;
  final String surname;
  final String givenName;
  final String? surnameReading;
  final String? givenNameReading;

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
    );
  }

  DesignInput toDesignInput() {
    final combinedValue = combined;
    final hasNonAscii = combinedValue.runes.any(
      (codePoint) => codePoint > 0x7F,
    );
    return DesignInput(
      sourceType: DesignSourceType.typed,
      rawName: combinedValue,
      kanji: hasNonAscii ? DesignKanjiMapping(value: combinedValue) : null,
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
            other.givenNameReading == givenNameReading);
  }

  @override
  int get hashCode {
    return Object.hash(
      persona,
      surname,
      givenName,
      surnameReading,
      givenNameReading,
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
  });

  final DesignSourceType? selectedMode;
  final DesignCreationFilter? selectedFilter;
  final bool storagePermissionGranted;
  final DesignNameDraft? nameDraft;
  final DesignInput? pendingInput;

  DesignCreationState copyWith({
    DesignSourceType? selectedMode,
    DesignCreationFilter? selectedFilter,
    bool? storagePermissionGranted,
    bool resetFilter = false,
    DesignNameDraft? nameDraft,
    bool clearNameDraft = false,
    DesignInput? pendingInput,
    bool clearPendingInput = false,
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
    );
  }

  bool get hasSelection => selectedMode != null;

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
}
