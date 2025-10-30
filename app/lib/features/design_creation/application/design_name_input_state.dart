import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:flutter/foundation.dart';

/// 入力欄の検証エラー種別
enum DesignNameFieldError { empty, invalidScript, tooLong }

/// プロフィールなどから提案される名前候補
@immutable
class DesignNameSuggestion {
  const DesignNameSuggestion({
    required this.labelKey,
    required this.surname,
    required this.givenName,
    this.description,
  });

  final String labelKey;
  final String surname;
  final String givenName;
  final String? description;

  bool get isEmpty => surname.isEmpty && givenName.isEmpty;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignNameSuggestion &&
            other.labelKey == labelKey &&
            other.surname == surname &&
            other.givenName == givenName &&
            other.description == description);
  }

  @override
  int get hashCode => Object.hash(labelKey, surname, givenName, description);
}

@immutable
class DesignNameInputState {
  const DesignNameInputState({
    this.surname = '',
    this.givenName = '',
    this.surnameReading = '',
    this.givenNameReading = '',
    this.surnameDirty = false,
    this.givenNameDirty = false,
    this.surnameReadingDirty = false,
    this.givenNameReadingDirty = false,
    this.persona = UserPersona.japanese,
    this.suggestions = const <DesignNameSuggestion>[],
    this.isSubmitting = false,
    this.selectedKanjiMapping,
  });

  final String surname;
  final String givenName;
  final String surnameReading;
  final String givenNameReading;
  final bool surnameDirty;
  final bool givenNameDirty;
  final bool surnameReadingDirty;
  final bool givenNameReadingDirty;
  final UserPersona persona;
  final List<DesignNameSuggestion> suggestions;
  final bool isSubmitting;
  final DesignKanjiMapping? selectedKanjiMapping;

  static const int _kanjiMaxLength = 6;
  static const int _latinMaxLength = 20;

  bool get requiresKana => persona == UserPersona.japanese;

  bool get hasManualEdits =>
      surnameDirty ||
      givenNameDirty ||
      surnameReadingDirty ||
      givenNameReadingDirty;

  bool get isPristine =>
      surname.isEmpty &&
      givenName.isEmpty &&
      surnameReading.isEmpty &&
      givenNameReading.isEmpty &&
      !hasManualEdits;

  String get previewPrimary {
    final parts = [
      surname.trim(),
      givenName.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    if (persona == UserPersona.japanese) {
      return parts.join();
    }
    return parts.join(' ');
  }

  String get previewReading {
    final parts = [
      surnameReading.trim(),
      givenNameReading.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return parts.join(' ');
  }

  DesignNameFieldError? get surnameError =>
      surnameDirty ? _validatePrimaryName(surname) : null;

  DesignNameFieldError? get givenNameError =>
      givenNameDirty ? _validatePrimaryName(givenName) : null;

  DesignNameFieldError? get surnameReadingError =>
      surnameReadingDirty ? _validateReading(surnameReading) : null;

  DesignNameFieldError? get givenNameReadingError =>
      givenNameReadingDirty ? _validateReading(givenNameReading) : null;

  bool get canSubmit {
    final last = this;
    final surnameValid = last._validatePrimaryName(last.surname) == null;
    final givenValid = last._validatePrimaryName(last.givenName) == null;
    if (!surnameValid || !givenValid) {
      return false;
    }

    if (!requiresKana) {
      return true;
    }

    final surnameReadingValid =
        last._validateReading(last.surnameReading) == null;
    final givenReadingValid =
        last._validateReading(last.givenNameReading) == null;
    return surnameReadingValid && givenReadingValid;
  }

  DesignNameInputState copyWith({
    String? surname,
    String? givenName,
    String? surnameReading,
    String? givenNameReading,
    bool? surnameDirty,
    bool? givenNameDirty,
    bool? surnameReadingDirty,
    bool? givenNameReadingDirty,
    UserPersona? persona,
    List<DesignNameSuggestion>? suggestions,
    bool? isSubmitting,
    DesignKanjiMapping? selectedKanjiMapping,
    bool clearSelectedKanjiMapping = false,
  }) {
    return DesignNameInputState(
      surname: surname ?? this.surname,
      givenName: givenName ?? this.givenName,
      surnameReading: surnameReading ?? this.surnameReading,
      givenNameReading: givenNameReading ?? this.givenNameReading,
      surnameDirty: surnameDirty ?? this.surnameDirty,
      givenNameDirty: givenNameDirty ?? this.givenNameDirty,
      surnameReadingDirty: surnameReadingDirty ?? this.surnameReadingDirty,
      givenNameReadingDirty:
          givenNameReadingDirty ?? this.givenNameReadingDirty,
      persona: persona ?? this.persona,
      suggestions: suggestions ?? this.suggestions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      selectedKanjiMapping: clearSelectedKanjiMapping
          ? null
          : selectedKanjiMapping ?? this.selectedKanjiMapping,
    );
  }

  DesignNameFieldError? _validatePrimaryName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return DesignNameFieldError.empty;
    }
    if (persona == UserPersona.japanese) {
      if (_containsHalfWidth(trimmed)) {
        return DesignNameFieldError.invalidScript;
      }
      if (trimmed.length > _kanjiMaxLength) {
        return DesignNameFieldError.tooLong;
      }
    } else {
      if (trimmed.length > _latinMaxLength) {
        return DesignNameFieldError.tooLong;
      }
    }
    return null;
  }

  DesignNameFieldError? _validateReading(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return requiresKana ? DesignNameFieldError.empty : null;
    }
    if (!_kanaPattern.hasMatch(trimmed)) {
      return DesignNameFieldError.invalidScript;
    }
    if (trimmed.length > _latinMaxLength) {
      return DesignNameFieldError.tooLong;
    }
    return null;
  }

  static bool _containsHalfWidth(String value) {
    for (final code in value.runes) {
      if (code <= 0x00FF) {
        return true;
      }
    }
    return false;
  }

  static final RegExp _kanaPattern = RegExp(
    r'^[\u3040-\u309F\u30A0-\u30FF\u31F0-\u31FF\uFF66-\uFF9Fー]+$',
  );
}
