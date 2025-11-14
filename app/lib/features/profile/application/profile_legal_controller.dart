import 'dart:async';
import 'dart:ui';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/profile/data/legal_documents_repository.dart';
import 'package:app/features/profile/data/legal_documents_repository_provider.dart';
import 'package:app/features/profile/domain/legal_document.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfileLegalState {
  const ProfileLegalState({
    required this.documents,
    required this.selectedDocument,
    required this.locale,
    required this.isRefreshing,
    required this.fromCache,
    required this.lastSyncedAt,
  });

  final List<LegalDocument> documents;
  final LegalDocument? selectedDocument;
  final Locale locale;
  final bool isRefreshing;
  final bool fromCache;
  final DateTime? lastSyncedAt;

  bool get hasDocuments => documents.isNotEmpty;

  ProfileLegalState copyWith({
    List<LegalDocument>? documents,
    LegalDocument? selectedDocument,
    Locale? locale,
    bool? isRefreshing,
    bool? fromCache,
    DateTime? lastSyncedAt,
    bool clearSelection = false,
  }) {
    return ProfileLegalState(
      documents: documents ?? this.documents,
      selectedDocument: clearSelection
          ? null
          : selectedDocument ?? this.selectedDocument,
      locale: locale ?? this.locale,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      fromCache: fromCache ?? this.fromCache,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class ProfileLegalController extends AsyncNotifier<ProfileLegalState> {
  LegalDocumentsRepository get _repository =>
      ref.read(legalDocumentsRepositoryProvider);

  @override
  FutureOr<ProfileLegalState> build() async {
    final experience = await ref.watch(experienceGateProvider.future);
    final result = await _repository.fetchDocuments(
      localeTag: experience.locale.toLanguageTag(),
    );
    return _stateFromResult(
      result: result,
      locale: experience.locale,
      preferredDocumentId: null,
    );
  }

  Future<void> refresh() async {
    final previous = state.asData?.value;
    if (previous != null) {
      state = AsyncData(previous.copyWith(isRefreshing: true));
    } else {
      state = const AsyncLoading();
    }
    try {
      final experience = await ref.read(experienceGateProvider.future);
      final result = await _repository.fetchDocuments(
        localeTag: experience.locale.toLanguageTag(),
      );
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(
        _stateFromResult(
          result: result,
          locale: experience.locale,
          preferredDocumentId: previous?.selectedDocument?.id,
        ),
      );
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  void selectDocument(String documentId) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final next = _findDocument(current.documents, documentId);
    if (next == null || next == current.selectedDocument) {
      return;
    }
    state = AsyncData(current.copyWith(selectedDocument: next));
  }

  ProfileLegalState _stateFromResult({
    required LegalDocumentsResult result,
    required Locale locale,
    required String? preferredDocumentId,
  }) {
    final documents = List<LegalDocument>.unmodifiable(result.documents);
    final selected = _initialDocument(
      documents,
      preferredId: preferredDocumentId,
    );
    return ProfileLegalState(
      documents: documents,
      selectedDocument: selected,
      locale: locale,
      isRefreshing: false,
      fromCache: result.fromCache,
      lastSyncedAt: result.fetchedAt,
    );
  }

  LegalDocument? _initialDocument(
    List<LegalDocument> documents, {
    required String? preferredId,
  }) {
    if (documents.isEmpty) {
      return null;
    }
    if (preferredId != null) {
      final preserved = _findDocument(documents, preferredId);
      if (preserved != null) {
        return preserved;
      }
    }
    return documents.first;
  }

  LegalDocument? _findDocument(
    List<LegalDocument> documents,
    String documentId,
  ) {
    for (final doc in documents) {
      if (doc.id == documentId) {
        return doc;
      }
    }
    return null;
  }
}

final profileLegalControllerProvider =
    AsyncNotifierProvider<ProfileLegalController, ProfileLegalState>(
      ProfileLegalController.new,
    );
