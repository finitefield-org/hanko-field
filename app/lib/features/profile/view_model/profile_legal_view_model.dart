// ignore_for_file: public_member_api_docs

import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/content/data/repositories/cached_content_repository.dart';
import 'package:app/features/content/data/repositories/content_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class LegalDocumentDefinition {
  const LegalDocumentDefinition({
    required this.slug,
    required this.icon,
    required this.fallbackTitleEn,
    required this.fallbackTitleJa,
  });

  final String slug;
  final IconData icon;
  final String fallbackTitleEn;
  final String fallbackTitleJa;

  String fallbackTitle({required bool prefersEnglish}) {
    return prefersEnglish ? fallbackTitleEn : fallbackTitleJa;
  }
}

class LegalDocumentEntry {
  const LegalDocumentEntry({required this.definition, required this.page});

  final LegalDocumentDefinition definition;
  final PageContent? page;
}

class ProfileLegalState {
  const ProfileLegalState({
    required this.documents,
    required this.selectedSlug,
    required this.lang,
    required this.prefersEnglish,
  });

  final List<LegalDocumentEntry> documents;
  final String selectedSlug;
  final String lang;
  final bool prefersEnglish;

  LegalDocumentEntry? selectedDocument() {
    for (final document in documents) {
      if (document.definition.slug == selectedSlug) {
        return document;
      }
    }
    return documents.isEmpty ? null : documents.first;
  }

  ProfileLegalState copyWith({String? selectedSlug}) {
    return ProfileLegalState(
      documents: documents,
      selectedSlug: selectedSlug ?? this.selectedSlug,
      lang: lang,
      prefersEnglish: prefersEnglish,
    );
  }
}

final profileLegalViewModel = ProfileLegalViewModel();

class ProfileLegalViewModel extends AsyncProvider<ProfileLegalState> {
  ProfileLegalViewModel() : super.args(null, autoDispose: true);

  late final selectDocumentMut = mutation<String>(#selectDocument);
  late final prefetchMut = mutation<void>(#prefetch);

  @override
  Future<ProfileLegalState> build(
    Ref<AsyncValue<ProfileLegalState>> ref,
  ) async {
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final lang = prefersEnglish ? 'en' : 'ja';
    final repository = ref.watch(contentRepositoryProvider);

    final documents = await _loadDocuments(repository: repository, lang: lang);

    final initial = documents.firstWhere(
      (doc) => doc.page != null,
      orElse: () => documents.first,
    );

    return ProfileLegalState(
      documents: documents,
      selectedSlug: initial.definition.slug,
      lang: lang,
      prefersEnglish: prefersEnglish,
    );
  }

  Call<String, AsyncValue<ProfileLegalState>> selectDocument(String slug) =>
      mutate(selectDocumentMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return slug;
        if (current.selectedSlug == slug) return slug;
        ref.state = AsyncData(current.copyWith(selectedSlug: slug));
        return slug;
      });

  Call<void, AsyncValue<ProfileLegalState>> prefetch() =>
      mutate(prefetchMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        final repository = ref.watch(contentRepositoryProvider);
        final lang = current?.lang ?? _resolveLang(ref);
        final errors = <Object>[];
        for (final document in _legalDocuments) {
          try {
            await repository.getPage(document.slug, lang: lang);
          } catch (e) {
            errors.add(e);
          }
        }

        if (errors.isNotEmpty) {
          throw StateError('Failed to cache ${errors.length} legal documents');
        }
      }, concurrency: Concurrency.dropLatest);
}

final _logger = Logger('ProfileLegalViewModel');

const _legalDocuments = <LegalDocumentDefinition>[
  LegalDocumentDefinition(
    slug: 'legal/privacy-policy',
    icon: Icons.privacy_tip_outlined,
    fallbackTitleEn: 'Privacy Policy',
    fallbackTitleJa: 'プライバシーポリシー',
  ),
  LegalDocumentDefinition(
    slug: 'legal/terms',
    icon: Icons.gavel_outlined,
    fallbackTitleEn: 'Terms of Service',
    fallbackTitleJa: '利用規約',
  ),
  LegalDocumentDefinition(
    slug: 'legal/commercial-transactions',
    icon: Icons.receipt_long_outlined,
    fallbackTitleEn: 'Commercial Transactions',
    fallbackTitleJa: '特定商取引法に基づく表記',
  ),
];

Future<List<LegalDocumentEntry>> _loadDocuments({
  required ContentRepository repository,
  required String lang,
}) async {
  final entries = <LegalDocumentEntry>[];
  final errors = <Object>[];

  for (final document in _legalDocuments) {
    try {
      final page = await repository.getPage(document.slug, lang: lang);
      entries.add(LegalDocumentEntry(definition: document, page: page));
    } catch (e, stack) {
      _logger.warning('Legal page fetch failed: ${document.slug}', e, stack);
      entries.add(LegalDocumentEntry(definition: document, page: null));
      errors.add(e);
    }
  }

  if (errors.length == _legalDocuments.length && errors.isNotEmpty) {
    throw errors.first;
  }

  return entries;
}

String _resolveLang(Ref<AsyncValue<ProfileLegalState>> ref) {
  final gates = ref.watch(appExperienceGatesProvider);
  return gates.prefersEnglish ? 'en' : 'ja';
}
