import 'package:app/features/library/data/library_share_link_repository_provider.dart';
import 'package:app/features/library/domain/library_share_link.dart';
import 'package:app/features/library/domain/library_share_link_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final libraryShareLinksControllerProvider =
    NotifierProvider.family<
      LibraryShareLinksController,
      LibraryShareLinksState,
      String
    >(LibraryShareLinksController.new);

class LibraryShareLinksController extends Notifier<LibraryShareLinksState> {
  LibraryShareLinksController(this.designId);

  final String designId;

  late final LibraryShareLinkRepository _repository;
  bool _initialized = false;

  @override
  LibraryShareLinksState build() {
    _repository = ref.read(libraryShareLinkRepositoryProvider);
    if (!_initialized) {
      _initialized = true;
      Future<void>.microtask(_load);
    }
    return const LibraryShareLinksState(isLoading: true);
  }

  Future<void> refresh() => _load(force: true);

  Future<void> _load({bool force = false}) async {
    if (state.isLoading && !force) {
      return;
    }
    state = state.copyWith(isLoading: true, clearFeedback: true);
    try {
      final links = await _repository.fetchLinks(designId);
      final sorted = _sortLinks(links);
      state = state.copyWith(isLoading: false, links: sorted);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load share links.',
      );
    }
  }

  Future<LibraryShareLink?> createLink({Duration? ttl}) async {
    if (state.isCreating) {
      return null;
    }
    state = state.copyWith(isCreating: true, clearFeedback: true);
    try {
      final link = await _repository.createLink(designId, ttl: ttl);
      final updated = _sortLinks([link, ...state.links]);
      state = state.copyWith(
        isCreating: false,
        links: updated,
        feedback: LibraryShareLinksFeedback(
          type: LibraryShareLinksFeedbackType.created,
          linkId: link.id,
        ),
      );
      return link;
    } catch (_) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: 'Unable to create share link.',
      );
      return null;
    }
  }

  Future<void> extendLink(String linkId, {Duration? extension}) async {
    if (state.extending.contains(linkId)) {
      return;
    }
    final pending = Set<String>.from(state.extending)..add(linkId);
    state = state.copyWith(extending: pending, clearFeedback: true);
    try {
      final link = await _repository.extendLink(
        designId,
        linkId,
        extension: extension,
      );
      _replaceLink(link);
      final updatedPending = Set<String>.from(state.extending)..remove(linkId);
      state = state.copyWith(
        extending: updatedPending,
        feedback: LibraryShareLinksFeedback(
          type: LibraryShareLinksFeedbackType.extended,
          linkId: link.id,
        ),
      );
    } catch (_) {
      final updatedPending = Set<String>.from(state.extending)..remove(linkId);
      state = state.copyWith(
        extending: updatedPending,
        errorMessage: 'Unable to extend link.',
      );
    }
  }

  Future<void> revokeLink(String linkId) async {
    if (state.revoking.contains(linkId)) {
      return;
    }
    final pending = Set<String>.from(state.revoking)..add(linkId);
    state = state.copyWith(revoking: pending, clearFeedback: true);
    try {
      final link = await _repository.revokeLink(designId, linkId);
      _replaceLink(link);
      final updatedPending = Set<String>.from(state.revoking)..remove(linkId);
      state = state.copyWith(
        revoking: updatedPending,
        feedback: LibraryShareLinksFeedback(
          type: LibraryShareLinksFeedbackType.revoked,
          linkId: link.id,
        ),
      );
    } catch (_) {
      final updatedPending = Set<String>.from(state.revoking)..remove(linkId);
      state = state.copyWith(
        revoking: updatedPending,
        errorMessage: 'Unable to revoke link.',
      );
    }
  }

  void _replaceLink(LibraryShareLink link) {
    final existing = state.links.toList();
    final index = existing.indexWhere((item) => item.id == link.id);
    if (index == -1) {
      existing.add(link);
    } else {
      existing[index] = link;
    }
    state = state.copyWith(links: _sortLinks(existing));
  }

  List<LibraryShareLink> _sortLinks(List<LibraryShareLink> links) {
    final sorted = List<LibraryShareLink>.from(links);
    sorted.sort(_compareLinks);
    return sorted;
  }

  int _compareLinks(LibraryShareLink a, LibraryShareLink b) {
    int priority(LibraryShareLink link) {
      switch (link.status) {
        case LibraryShareLinkStatus.active:
          return 0;
        case LibraryShareLinkStatus.expired:
          return 1;
        case LibraryShareLinkStatus.revoked:
          return 2;
      }
    }

    final diff = priority(a) - priority(b);
    if (diff != 0) {
      return diff;
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  void clearFeedback() {
    if (state.feedback == null && state.errorMessage == null) {
      return;
    }
    state = state.copyWith(clearFeedback: true);
  }
}

enum LibraryShareLinksFeedbackType { created, extended, revoked }

@immutable
class LibraryShareLinksFeedback {
  const LibraryShareLinksFeedback({required this.type, required this.linkId});

  final LibraryShareLinksFeedbackType type;
  final String linkId;
}

@immutable
class LibraryShareLinksState {
  const LibraryShareLinksState({
    this.links = const <LibraryShareLink>[],
    this.isLoading = false,
    this.isCreating = false,
    this.revoking = const <String>{},
    this.extending = const <String>{},
    this.feedback,
    this.errorMessage,
  });

  final List<LibraryShareLink> links;
  final bool isLoading;
  final bool isCreating;
  final Set<String> revoking;
  final Set<String> extending;
  final LibraryShareLinksFeedback? feedback;
  final String? errorMessage;

  List<LibraryShareLink> get activeLinks => links
      .where((link) => link.status == LibraryShareLinkStatus.active)
      .toList(growable: false);

  List<LibraryShareLink> get historyLinks => links
      .where(
        (link) =>
            link.status == LibraryShareLinkStatus.expired ||
            link.status == LibraryShareLinkStatus.revoked,
      )
      .toList(growable: false);

  LibraryShareLinksState copyWith({
    List<LibraryShareLink>? links,
    bool? isLoading,
    bool? isCreating,
    Set<String>? revoking,
    Set<String>? extending,
    LibraryShareLinksFeedback? feedback,
    String? errorMessage,
    bool clearFeedback = false,
  }) {
    return LibraryShareLinksState(
      links: links != null
          ? List<LibraryShareLink>.unmodifiable(links)
          : this.links,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      revoking: revoking != null
          ? Set<String>.unmodifiable(revoking)
          : this.revoking,
      extending: extending != null
          ? Set<String>.unmodifiable(extending)
          : this.extending,
      feedback: clearFeedback ? null : feedback ?? this.feedback,
      errorMessage: clearFeedback ? null : errorMessage ?? this.errorMessage,
    );
  }
}
