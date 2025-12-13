// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/data/repositories/design_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:miniriverpod/miniriverpod.dart';

class LibraryDesignDuplicateState {
  const LibraryDesignDuplicateState({
    required this.source,
    required this.name,
    required this.tags,
    required this.copyHistory,
    required this.copyAssets,
    required this.isSubmitting,
    required this.suggestions,
  });

  final Design source;
  final String name;
  final List<String> tags;
  final bool copyHistory;
  final bool copyAssets;
  final bool isSubmitting;
  final List<String> suggestions;

  LibraryDesignDuplicateState copyWith({
    Design? source,
    String? name,
    List<String>? tags,
    bool? copyHistory,
    bool? copyAssets,
    bool? isSubmitting,
    List<String>? suggestions,
  }) {
    return LibraryDesignDuplicateState(
      source: source ?? this.source,
      name: name ?? this.name,
      tags: tags ?? this.tags,
      copyHistory: copyHistory ?? this.copyHistory,
      copyAssets: copyAssets ?? this.copyAssets,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

class LibraryDesignDuplicateViewModel
    extends AsyncProvider<LibraryDesignDuplicateState> {
  LibraryDesignDuplicateViewModel({required this.designId})
    : super.args((designId,), autoDispose: true);

  final String designId;

  late final setNameMut = mutation<String>(#setName);
  late final setTagsMut = mutation<List<String>>(#setTags);
  late final toggleCopyHistoryMut = mutation<bool>(#toggleCopyHistory);
  late final toggleCopyAssetsMut = mutation<bool>(#toggleCopyAssets);
  late final submitMut = mutation<Design>(#submit);

  @override
  Future<LibraryDesignDuplicateState> build(Ref ref) async {
    final repository = ref.watch(designRepositoryProvider);
    final gates = ref.watch(appExperienceGatesProvider);
    final source = await repository.getDesign(designId);

    final rawName = source.input?.rawName.trim();
    final baseName = (rawName == null || rawName.isEmpty)
        ? (gates.prefersEnglish ? 'Design' : '印鑑')
        : rawName;
    final suffix = gates.prefersEnglish ? 'Copy' : 'コピー';
    final proposedName = '$baseName $suffix';

    return LibraryDesignDuplicateState(
      source: source,
      name: proposedName,
      tags: source.tags,
      copyHistory: true,
      copyAssets: true,
      isSubmitting: false,
      suggestions: _seedSuggestions(
        source,
        prefersEnglish: gates.prefersEnglish,
      ),
    );
  }

  Call<String> setName(String value) => mutate(setNameMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return value;
    final next = value.trimLeft();
    ref.state = AsyncData(current.copyWith(name: next));
    return next;
  }, concurrency: Concurrency.restart);

  Call<List<String>> setTags(Iterable<String> tags) =>
      mutate(setTagsMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        final normalized = _normalizeTags(tags);
        if (current == null) return normalized;
        ref.state = AsyncData(current.copyWith(tags: normalized));
        return normalized;
      }, concurrency: Concurrency.restart);

  Call<bool> toggleCopyHistory(bool enabled) =>
      mutate(toggleCopyHistoryMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(current.copyWith(copyHistory: enabled));
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleCopyAssets(bool enabled) =>
      mutate(toggleCopyAssetsMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(current.copyWith(copyAssets: enabled));
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<Design> submit() => mutate(submitMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) throw StateError('Duplicate form is not ready');
    if (current.isSubmitting) throw StateError('Duplicate already in progress');

    ref.state = AsyncData(current.copyWith(isSubmitting: true));
    try {
      final gates = ref.watch(appExperienceGatesProvider);
      final repository = ref.watch(designRepositoryProvider);
      final duplicated = await repository.duplicateDesign(designId);

      final name = current.name.trim();
      final resolvedName = name.isEmpty
          ? (duplicated.input?.rawName.trim().isNotEmpty == true
                ? duplicated.input!.rawName.trim()
                : (gates.prefersEnglish ? 'Design copy' : '印鑑のコピー'))
          : name;

      final input =
          duplicated.input?.copyWith(rawName: resolvedName) ??
          DesignInput(
            sourceType: DesignSourceType.typed,
            rawName: resolvedName,
          );

      final updated = duplicated.copyWith(
        input: input,
        tags: current.tags,
        assets: current.copyAssets ? duplicated.assets : null,
        ai: current.copyHistory ? duplicated.ai : null,
        hash: current.copyHistory ? duplicated.hash : null,
        version: 1,
      );

      final saved = await repository.updateDesign(updated);
      return saved;
    } catch (e, stack) {
      ref.state = AsyncError(
        e,
        stack,
        previous: AsyncData(current.copyWith(isSubmitting: false)),
      );
      rethrow;
    } finally {
      final latest = ref.watch(this).valueOrNull;
      if (latest != null && latest.isSubmitting) {
        ref.state = AsyncData(latest.copyWith(isSubmitting: false));
      }
    }
  }, concurrency: Concurrency.dropLatest);
}

List<String> _normalizeTags(Iterable<String> tags) {
  final normalized = tags
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .map((value) => value.startsWith('#') ? value.substring(1) : value)
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  final unique = <String>[];
  for (final tag in normalized) {
    if (unique.firstWhereOrNull((value) => value == tag) != null) continue;
    unique.add(tag);
  }
  return unique;
}

List<String> _seedSuggestions(Design source, {required bool prefersEnglish}) {
  final suggestions = <String>[];
  suggestions.add(source.shape.toJson());
  suggestions.add(source.style.writing.toJson());
  suggestions.add('${source.size.mm.round()}mm');
  final type = source.input?.sourceType;
  if (type != null) {
    suggestions.add(type.toJson());
  }
  if (!prefersEnglish) {
    suggestions.add('マイ印鑑');
  }
  return _normalizeTags(suggestions);
}
