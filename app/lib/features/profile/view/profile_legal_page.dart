// ignore_for_file: public_member_api_docs

import 'package:app/features/content/data/models/page_presentation.dart';
import 'package:app/features/profile/view_model/profile_legal_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/content/rich_content.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileLegalPage extends ConsumerWidget {
  const ProfileLegalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final state = ref.watch(profileLegalViewModel);
    final downloadState = ref.watch(profileLegalViewModel.prefetchMut);
    final isDownloading = downloadState is PendingMutationState;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileLegalTitle),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.profileLegalDownloadTooltip,
            onPressed: isDownloading
                ? null
                : () async {
                    try {
                      await ref.invoke(profileLegalViewModel.prefetch());
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.profileLegalDownloadComplete),
                        ),
                      );
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.profileLegalDownloadFailed),
                        ),
                      );
                    }
                  },
            icon: isDownloading
                ? SizedBox(
                    width: tokens.spacing.md,
                    height: tokens.spacing.md,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
          SizedBox(width: tokens.spacing.sm),
        ],
      ),
      body: switch (state) {
        AsyncLoading() => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: AppEmptyState(
              title: l10n.profileLegalLoadFailedTitle,
              message: error.toString(),
              icon: Icons.policy_outlined,
              actionLabel: l10n.profileRetry,
              onAction: () => ref.invalidate(profileLegalViewModel),
            ),
          ),
        ),
        AsyncData(:final value) => RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(profileLegalViewModel);
          },
          child: _LegalBody(
            state: value,
            onSelect: (slug) {
              ref.invoke(profileLegalViewModel.selectDocument(slug));
            },
          ),
        ),
      },
    );
  }
}

class _LegalBody extends StatelessWidget {
  const _LegalBody({required this.state, required this.onSelect});

  final ProfileLegalState state;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final selected = state.selectedDocument();

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          l10n.profileLegalDocumentsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.md),
        ...state.documents.map(
          (document) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.sm),
            child: _LegalDocumentTile(
              document: document,
              lang: state.lang,
              prefersEnglish: state.prefersEnglish,
              isSelected: selected?.definition.slug == document.definition.slug,
              onTap: () => onSelect(document.definition.slug),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.lg),
        Text(
          l10n.profileLegalContentTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.md),
        _LegalDocumentCard(
          document: selected,
          lang: state.lang,
          prefersEnglish: state.prefersEnglish,
        ),
        SizedBox(height: tokens.spacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: selected == null
                ? null
                : () => _openExternalUri(
                    legalShareUri(selected.definition.slug, state.lang),
                  ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.profileLegalOpenInBrowser),
          ),
        ),
      ],
    );
  }
}

class _LegalDocumentTile extends StatelessWidget {
  const _LegalDocumentTile({
    required this.document,
    required this.lang,
    required this.prefersEnglish,
    required this.isSelected,
    required this.onTap,
  });

  final LegalDocumentEntry document;
  final String lang;
  final bool prefersEnglish;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final page = document.page;
    final translation = page == null
        ? null
        : pageTranslationForLang(page, lang);
    final title =
        translation?.title ??
        document.definition.fallbackTitle(prefersEnglish: prefersEnglish);
    final version = page?.version ?? l10n.profileLegalVersionUnknown;
    final borderColor = isSelected
        ? tokens.colors.primary
        : tokens.colors.outline.withValues(alpha: 0.3);
    final background = isSelected
        ? tokens.colors.surfaceVariant.withValues(alpha: 0.6)
        : tokens.colors.surface;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.md),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.lg,
            vertical: tokens.spacing.md,
          ),
          child: Row(
            children: [
              Icon(
                document.definition.icon,
                color: isSelected
                    ? tokens.colors.primary
                    : tokens.colors.onSurface,
              ),
              SizedBox(width: tokens.spacing.md),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Chip(label: Text(version)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalDocumentCard extends StatelessWidget {
  const _LegalDocumentCard({
    required this.document,
    required this.lang,
    required this.prefersEnglish,
  });

  final LegalDocumentEntry? document;
  final String lang;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);

    if (document == null) {
      return _EmptyLegalCard(message: l10n.profileLegalNoDocument);
    }

    final page = document!.page;
    final translation = page == null
        ? null
        : pageTranslationForLang(page, lang);
    final title =
        translation?.title ??
        document!.definition.fallbackTitle(prefersEnglish: prefersEnglish);
    final body = translation?.body ?? '';
    final version = page?.version;

    return Material(
      color: tokens.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        side: BorderSide(color: tokens.colors.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                if (version != null && version.trim().isNotEmpty)
                  Chip(label: Text(version)),
              ],
            ),
            SizedBox(height: tokens.spacing.md),
            if (page == null)
              _EmptyLegalCard(message: l10n.profileLegalUnavailable)
            else if (body.trim().isEmpty)
              _EmptyLegalCard(message: l10n.profileLegalNoContent)
            else
              AppRichContent(content: body),
          ],
        ),
      ),
    );
  }
}

class _EmptyLegalCard extends StatelessWidget {
  const _EmptyLegalCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Container(
      padding: EdgeInsets.all(tokens.spacing.lg),
      decoration: BoxDecoration(
        color: tokens.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: Text(message),
    );
  }
}

Uri legalShareUri(String slug, String lang) {
  final trimmed = slug.trim();
  final normalized = trimmed.startsWith('legal/')
      ? trimmed.substring('legal/'.length)
      : trimmed;
  final qp = lang.trim().isEmpty ? null : <String, String>{'lang': lang.trim()};
  return Uri.https('hanko.app', '/legal/$normalized', qp);
}

Future<void> _openExternalUri(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
