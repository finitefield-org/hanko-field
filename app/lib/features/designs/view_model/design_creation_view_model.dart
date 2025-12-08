// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/security/storage_permission_client.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum NameField { surnameKanji, givenKanji, surnameKana, givenKana }

class NameInputDraft {
  const NameInputDraft({
    this.surnameKanji = '',
    this.givenKanji = '',
    this.surnameKana = '',
    this.givenKana = '',
    this.kanjiMapping,
  });

  final String surnameKanji;
  final String givenKanji;
  final String surnameKana;
  final String givenKana;
  final KanjiMapping? kanjiMapping;

  NameInputDraft copyWith({
    String? surnameKanji,
    String? givenKanji,
    String? surnameKana,
    String? givenKana,
    KanjiMapping? kanjiMapping,
    bool clearKanjiMapping = false,
  }) {
    return NameInputDraft(
      surnameKanji: surnameKanji ?? this.surnameKanji,
      givenKanji: givenKanji ?? this.givenKanji,
      surnameKana: surnameKana ?? this.surnameKana,
      givenKana: givenKana ?? this.givenKana,
      kanjiMapping: clearKanjiMapping
          ? null
          : (kanjiMapping ?? this.kanjiMapping),
    );
  }

  String fullName({required bool prefersEnglish}) {
    final kanji = [surnameKanji, givenKanji]
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(prefersEnglish ? ' ' : '');
    return kanji;
  }

  String fullKana() {
    return [
      surnameKana,
      givenKana,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
  }
}

class NameValidationResult {
  const NameValidationResult({
    required this.isValid,
    this.surnameError,
    this.givenError,
    this.surnameKanaError,
    this.givenKanaError,
    this.scriptWarning,
  });

  final bool isValid;
  final String? surnameError;
  final String? givenError;
  final String? surnameKanaError;
  final String? givenKanaError;
  final String? scriptWarning;

  bool get hasKanaIssues => surnameKanaError != null || givenKanaError != null;
}

class DesignCreationState {
  const DesignCreationState({
    required this.selectedType,
    required this.activeFilters,
    required this.storagePermissionGranted,
    required this.nameDraft,
    required this.previewStyle,
    this.savedInput,
    this.selectedShape,
    this.selectedSize,
    this.selectedStyle,
    this.selectedTemplate,
  });

  final DesignSourceType selectedType;
  final Set<String> activeFilters;
  final bool storagePermissionGranted;
  final NameInputDraft nameDraft;
  final WritingStyle previewStyle;
  final DesignInput? savedInput;
  final SealShape? selectedShape;
  final DesignSize? selectedSize;
  final DesignStyle? selectedStyle;
  final Template? selectedTemplate;

  DesignCreationState copyWith({
    DesignSourceType? selectedType,
    Set<String>? activeFilters,
    bool? storagePermissionGranted,
    NameInputDraft? nameDraft,
    WritingStyle? previewStyle,
    DesignInput? savedInput,
    SealShape? selectedShape,
    DesignSize? selectedSize,
    DesignStyle? selectedStyle,
    Template? selectedTemplate,
    bool clearSavedInput = false,
  }) {
    return DesignCreationState(
      selectedType: selectedType ?? this.selectedType,
      activeFilters: activeFilters ?? this.activeFilters,
      storagePermissionGranted:
          storagePermissionGranted ?? this.storagePermissionGranted,
      nameDraft: nameDraft ?? this.nameDraft,
      previewStyle: previewStyle ?? this.previewStyle,
      savedInput: clearSavedInput ? null : (savedInput ?? this.savedInput),
      selectedShape: selectedShape ?? this.selectedShape,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedStyle: selectedStyle ?? this.selectedStyle,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
    );
  }
}

class DesignCreationViewModel extends AsyncProvider<DesignCreationState> {
  DesignCreationViewModel() : super.args(null, autoDispose: false);

  late final selectTypeMut = mutation<DesignSourceType>(#selectType);
  late final toggleFilterMut = mutation<Set<String>>(#toggleFilter);
  late final ensureStorageMut = mutation<bool>(#ensureStorage);
  late final updateNameMut = mutation<NameInputDraft>(#updateName);
  late final applySuggestionMut = mutation<NameInputDraft>(#applySuggestion);
  late final setKanjiMappingMut = mutation<KanjiMapping?>(#setKanjiMapping);
  late final setPreviewStyleMut = mutation<WritingStyle>(#setPreviewStyle);
  late final setStyleSelectionMut = mutation<DesignStyle>(#setStyleSelection);
  late final saveInputMut = mutation<DesignInput>(#saveInput);

  @override
  Future<DesignCreationState> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    final session = ref.watch(userSessionProvider).valueOrNull;
    final defaults = _defaultFilters(gates);
    final nameSeed = _seedDraftFromProfile(gates, session?.profile);
    String? lastProfileId = session?.profile?.id;

    ref.listen(userSessionProvider, (next) {
      final profile = next.valueOrNull?.profile;
      if (profile == null) return;

      final current = ref.watch(this).valueOrNull;
      if (current == null) return;
      final gatesNow = ref.watch(appExperienceGatesProvider);
      final seed = _seedDraftFromProfile(gatesNow, profile);

      if (lastProfileId == null && !_isDraftEmpty(current.nameDraft)) {
        lastProfileId = profile.id;
        return;
      }

      final profileChanged =
          lastProfileId != null && lastProfileId != profile.id;
      final shouldSeed = _isDraftEmpty(current.nameDraft) || profileChanged;
      lastProfileId = profile.id;

      if (!shouldSeed) return;

      ref.state = AsyncData(
        current.copyWith(nameDraft: seed, clearSavedInput: true),
      );
    });

    return DesignCreationState(
      selectedType: DesignSourceType.typed,
      activeFilters: defaults,
      storagePermissionGranted: false,
      nameDraft: nameSeed,
      previewStyle: WritingStyle.tensho,
      savedInput: null,
      selectedShape: null,
      selectedSize: null,
      selectedStyle: null,
      selectedTemplate: null,
    );
  }

  Call<DesignSourceType> selectType(DesignSourceType type) =>
      mutate(selectTypeMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return type;
        ref.state = AsyncData(current.copyWith(selectedType: type));
        return type;
      }, concurrency: Concurrency.dropLatest);

  Call<Set<String>> toggleFilter(String filterId) =>
      mutate(toggleFilterMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return <String>{};

        final next = Set<String>.from(current.activeFilters);
        if (next.contains(filterId) && next.length > 1) {
          next.remove(filterId);
        } else {
          next.add(filterId);
        }

        ref.state = AsyncData(current.copyWith(activeFilters: next));
        return next;
      }, concurrency: Concurrency.dropLatest);

  Call<NameInputDraft> updateNameField(NameField field, String value) =>
      mutate(updateNameMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return const NameInputDraft();

        final updatedDraft = _updateDraftField(
          current.nameDraft,
          field,
          value,
        ).copyWith(clearKanjiMapping: true);

        ref.state = AsyncData(
          current.copyWith(nameDraft: updatedDraft, clearSavedInput: true),
        );
        return updatedDraft;
      }, concurrency: Concurrency.restart);

  Call<NameInputDraft> applyNameSuggestion(NameInputDraft suggestion) =>
      mutate(applySuggestionMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return suggestion;

        ref.state = AsyncData(
          current.copyWith(nameDraft: suggestion, clearSavedInput: true),
        );
        return suggestion;
      }, concurrency: Concurrency.restart);

  Call<KanjiMapping?> setKanjiMapping(KanjiMapping? mapping) =>
      mutate(setKanjiMappingMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return mapping;

        final draft = _applyKanjiMapping(current.nameDraft, mapping);

        ref.state = AsyncData(
          current.copyWith(nameDraft: draft, clearSavedInput: true),
        );
        return mapping;
      }, concurrency: Concurrency.dropLatest);

  Call<WritingStyle> setPreviewStyle(WritingStyle style) =>
      mutate(setPreviewStyleMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return style;

        ref.state = AsyncData(current.copyWith(previewStyle: style));
        return style;
      }, concurrency: Concurrency.dropLatest);

  Call<DesignStyle> setStyleSelection({
    required SealShape shape,
    required DesignSize size,
    required DesignStyle style,
    Template? template,
  }) => mutate(setStyleSelectionMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return style;

    ref.state = AsyncData(
      current.copyWith(
        selectedShape: shape,
        selectedSize: size,
        selectedStyle: style,
        selectedTemplate: template ?? current.selectedTemplate,
      ),
    );
    return style;
  }, concurrency: Concurrency.dropLatest);

  Call<DesignInput> saveNameInput() => mutate(saveInputMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) {
      throw StateError('Design creation state is not ready');
    }

    final gates = ref.watch(appExperienceGatesProvider);
    final validation = validateNameDraft(current.nameDraft, gates);
    if (!validation.isValid) {
      throw StateError('Name input is invalid');
    }

    final rawName = _composeRawName(
      current.nameDraft,
      prefersEnglish: gates.prefersEnglish,
    );
    final input = DesignInput(
      sourceType: current.selectedType,
      rawName: rawName,
      kanji: current.nameDraft.kanjiMapping,
    );

    ref.state = AsyncData(current.copyWith(savedInput: input));
    return input;
  }, concurrency: Concurrency.dropLatest);

  Call<bool> ensureStorageAccess() => mutate(ensureStorageMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return false;

    final requiresStorage = switch (current.selectedType) {
      DesignSourceType.typed => false,
      DesignSourceType.uploaded => true,
      DesignSourceType.logo => true,
    };
    if (!requiresStorage) return true;

    final client = ref.watch(storagePermissionClientProvider);
    final status = await client.status();
    if (status.isGranted) {
      ref.state = AsyncData(current.copyWith(storagePermissionGranted: true));
      return true;
    }

    final requested = await client.request();
    final granted = requested.isGranted;
    ref.state = AsyncData(current.copyWith(storagePermissionGranted: granted));
    return granted;
  }, concurrency: Concurrency.dropLatest);
}

final designCreationViewModel = DesignCreationViewModel();

Set<String> _defaultFilters(AppExperienceGates gates) {
  final defaults = <String>{
    gates.enableRegistrabilityCheck ? 'official' : 'personal',
  };
  if (gates.emphasizeInternationalFlows) {
    defaults.add('digital');
  }
  return defaults;
}

NameInputDraft _seedDraftFromProfile(
  AppExperienceGates gates,
  UserProfile? profile,
) {
  final displayName = profile?.displayName?.trim();
  if (displayName == null || displayName.isEmpty) {
    return const NameInputDraft();
  }

  final parts = displayName.split(RegExp(r'\s+'));
  final surname = parts.isNotEmpty ? parts.first : '';
  final given = parts.length > 1 ? parts.sublist(1).join(' ') : '';
  return NameInputDraft(
    surnameKanji: surname,
    givenKanji: given,
    surnameKana: gates.prefersEnglish ? '' : '',
    givenKana: gates.prefersEnglish ? '' : '',
  );
}

bool _isDraftEmpty(NameInputDraft draft) {
  return draft.surnameKanji.trim().isEmpty &&
      draft.givenKanji.trim().isEmpty &&
      draft.surnameKana.trim().isEmpty &&
      draft.givenKana.trim().isEmpty &&
      draft.kanjiMapping == null;
}

NameInputDraft _updateDraftField(
  NameInputDraft draft,
  NameField field,
  String value,
) {
  switch (field) {
    case NameField.surnameKanji:
      return draft.copyWith(surnameKanji: value);
    case NameField.givenKanji:
      return draft.copyWith(givenKanji: value);
    case NameField.surnameKana:
      return draft.copyWith(surnameKana: value);
    case NameField.givenKana:
      return draft.copyWith(givenKana: value);
  }
}

NameInputDraft _applyKanjiMapping(NameInputDraft draft, KanjiMapping? mapping) {
  if (mapping == null) {
    return draft.copyWith(kanjiMapping: null);
  }

  var surname = draft.surnameKanji;
  var given = draft.givenKanji;
  final value = mapping.value?.trim() ?? '';

  if (value.isNotEmpty) {
    final parts = value.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      surname = surname.trim().isEmpty ? parts.first : surname;
      given = given.trim().isEmpty ? parts.sublist(1).join(' ') : given;
    } else if (value.length >= 2) {
      surname = surname.trim().isEmpty ? value.substring(0, 1) : surname;
      given = given.trim().isEmpty ? value.substring(1) : given;
    } else if (surname.trim().isEmpty) {
      surname = value;
    }
  }

  return draft.copyWith(
    surnameKanji: surname,
    givenKanji: given,
    kanjiMapping: mapping,
  );
}

NameValidationResult validateNameDraft(
  NameInputDraft draft,
  AppExperienceGates gates,
) {
  String? surnameError;
  String? givenError;
  String? surnameKanaError;
  String? givenKanaError;
  String? scriptWarning;

  if (draft.surnameKanji.trim().isEmpty) {
    surnameError = gates.prefersEnglish ? 'Enter surname' : '姓を入力してください';
  } else if (_containsHalfWidth(draft.surnameKanji) && !gates.prefersEnglish) {
    surnameError = gates.prefersEnglish ? 'Use full width' : '全角で入力してください (姓)';
  }

  if (draft.givenKanji.trim().isEmpty) {
    givenError = gates.prefersEnglish ? 'Enter given name' : '名を入力してください';
  } else if (_containsHalfWidth(draft.givenKanji) && !gates.prefersEnglish) {
    givenError = gates.prefersEnglish ? 'Use full width' : '全角で入力してください (名)';
  }

  if (gates.prefersJapanese) {
    if (draft.surnameKana.trim().isEmpty) {
      surnameKanaError = gates.prefersEnglish
          ? 'Enter surname kana'
          : 'セイを入力してください';
    } else if (!_looksKana(draft.surnameKana)) {
      surnameKanaError = gates.prefersEnglish
          ? 'Use full-width kana'
          : '全角カナで入力してください';
    }

    if (draft.givenKana.trim().isEmpty) {
      givenKanaError = gates.prefersEnglish
          ? 'Enter given name kana'
          : 'メイを入力してください';
    } else if (!_looksKana(draft.givenKana)) {
      givenKanaError = gates.prefersEnglish
          ? 'Use full-width kana'
          : '全角カナで入力してください';
    }
  } else {
    final hasHalfWidthSurname =
        draft.surnameKana.isNotEmpty && _containsHalfWidth(draft.surnameKana);
    final hasHalfWidthGiven =
        draft.givenKana.isNotEmpty && _containsHalfWidth(draft.givenKana);
    if (hasHalfWidthSurname || hasHalfWidthGiven) {
      scriptWarning = gates.prefersEnglish
          ? 'Use kana in full width for engraving accuracy'
          : 'フリガナは全角が推奨です';
    }
  }

  final hasKanaWarning = gates.prefersJapanese
      ? (surnameKanaError == null && givenKanaError == null)
      : true;
  final isValid =
      surnameError == null &&
      givenError == null &&
      (gates.prefersJapanese
          ? surnameKanaError == null && givenKanaError == null
          : hasKanaWarning);

  return NameValidationResult(
    isValid: isValid,
    surnameError: surnameError,
    givenError: givenError,
    surnameKanaError: surnameKanaError,
    givenKanaError: givenKanaError,
    scriptWarning: scriptWarning,
  );
}

String _composeRawName(NameInputDraft draft, {required bool prefersEnglish}) {
  final name = draft.fullName(prefersEnglish: prefersEnglish);
  if (name.isNotEmpty) return name;
  return prefersEnglish ? draft.fullKana() : draft.fullKana();
}

bool _containsHalfWidth(String value) {
  final halfWidth = RegExp(r'[ -~｡-ﾟ]');
  return halfWidth.hasMatch(value);
}

bool _looksKana(String value) {
  final kana = RegExp(r'^[ぁ-んァ-ンー・ー\s]+$');
  return kana.hasMatch(value);
}
