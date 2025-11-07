import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/design_repository.dart';
import 'package:app/features/library/data/design_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final libraryDuplicateControllerProvider =
    NotifierProvider.family<
      LibraryDuplicateController,
      LibraryDuplicateState,
      String
    >(
      LibraryDuplicateController.new,
      name: 'libraryDuplicateControllerProvider',
    );

class LibraryDuplicateController extends Notifier<LibraryDuplicateState> {
  LibraryDuplicateController(this.designId);

  final String designId;

  late final DesignRepository _repository;
  bool _bootstrapped = false;

  @override
  LibraryDuplicateState build() {
    _repository = ref.read(designRepositoryProvider);
    if (!_bootstrapped) {
      _bootstrapped = true;
      Future.microtask(_load);
    }
    return LibraryDuplicateState(designId: designId);
  }

  Future<void> refresh() async {
    await _load();
  }

  void updateName(String value) {
    state = state.copyWith(newName: value);
  }

  void updateTagsInput(String value) {
    state = state.copyWith(tagsInput: value, tags: _parseTags(value));
  }

  void toggleCopyHistory(bool value) {
    state = state.copyWith(copyHistory: value);
  }

  void toggleCopyAssets(bool value) {
    state = state.copyWith(copyAssets: value);
  }

  void applySuggestedTag(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) {
      return;
    }
    final tags = {...state.tags.map((t) => t.toLowerCase())};
    if (tags.contains(normalized.toLowerCase())) {
      return;
    }
    final nextTags = [...state.tags, normalized];
    state = state.copyWith(tags: nextTags, tagsInput: nextTags.join(', '));
  }

  Future<Design?> submit() async {
    if (!state.canSubmit) {
      state = state.copyWith(
        errorMessage: state.newName.trim().isEmpty
            ? 'Please provide a name for the duplicate.'
            : state.errorMessage,
      );
      return null;
    }
    final source = state.sourceDesign;
    if (source == null) {
      return null;
    }
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      clearDuplicatedDesign: true,
    );
    try {
      final trimmedName = state.newName.trim();
      final duplicate = await _repository.duplicateDesign(
        source.id,
        name: trimmedName,
        tags: state.tags,
        copyHistory: state.copyHistory,
        copyAssets: state.copyAssets,
      );
      state = state.copyWith(isSubmitting: false, duplicatedDesign: duplicate);
      return duplicate;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to duplicate design. Please try again.',
      );
      return null;
    }
  }

  void clearFeedback() {
    if (state.errorMessage == null && state.duplicatedDesign == null) {
      return;
    }
    state = state.copyWith(errorMessage: null, clearDuplicatedDesign: true);
  }

  Future<void> _load() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearDuplicatedDesign: true,
    );
    try {
      final design = await _repository.fetchDesign(designId);
      final defaultName = _deriveDefaultName(design);
      final defaultTags = _defaultTags(design);
      state = state.copyWith(
        isLoading: false,
        sourceDesign: design,
        newName: defaultName,
        tags: defaultTags,
        tagsInput: defaultTags.join(', '),
        copyHistory: true,
        copyAssets: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load design details. Pull to retry.',
      );
    }
  }

  List<String> _parseTags(String value) {
    return value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  String _deriveDefaultName(Design design) {
    final base = design.input?.rawName.trim();
    if (base != null && base.isNotEmpty) {
      return '$base Copy';
    }
    return '${design.id} Copy';
  }

  List<String> _defaultTags(Design design) {
    final tags = <String>{};
    final persona = design.persona;
    if (persona != null) {
      tags.add(persona == UserPersona.japanese ? 'personal' : 'business');
    }
    tags.add(design.shape == DesignShape.round ? 'round' : 'square');
    tags.add(design.status.name);
    final score = design.ai?.qualityScore;
    if (score != null) {
      tags.add('ai-${score.round()}');
    }
    return tags.toList();
  }
}

class LibraryDuplicateState {
  const LibraryDuplicateState({
    required this.designId,
    this.sourceDesign,
    this.newName = '',
    this.tagsInput = '',
    this.tags = const [],
    this.copyHistory = true,
    this.copyAssets = true,
    this.isLoading = true,
    this.isSubmitting = false,
    this.errorMessage,
    this.duplicatedDesign,
  });

  final String designId;
  final Design? sourceDesign;
  final String newName;
  final String tagsInput;
  final List<String> tags;
  final bool copyHistory;
  final bool copyAssets;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final Design? duplicatedDesign;

  bool get canSubmit =>
      !isLoading && !isSubmitting && newName.trim().isNotEmpty;

  LibraryDuplicateState copyWith({
    Design? sourceDesign,
    bool clearSourceDesign = false,
    String? newName,
    String? tagsInput,
    List<String>? tags,
    bool? copyHistory,
    bool? copyAssets,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearErrorMessage = false,
    Design? duplicatedDesign,
    bool clearDuplicatedDesign = false,
  }) {
    return LibraryDuplicateState(
      designId: designId,
      sourceDesign: clearSourceDesign
          ? null
          : sourceDesign ?? this.sourceDesign,
      newName: newName ?? this.newName,
      tagsInput: tagsInput ?? this.tagsInput,
      tags: tags ?? this.tags,
      copyHistory: copyHistory ?? this.copyHistory,
      copyAssets: copyAssets ?? this.copyAssets,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      duplicatedDesign: clearDuplicatedDesign
          ? null
          : duplicatedDesign ?? this.duplicatedDesign,
    );
  }
}
