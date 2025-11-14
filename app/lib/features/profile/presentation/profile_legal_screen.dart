import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/features/profile/application/profile_legal_controller.dart';
import 'package:app/features/profile/domain/legal_document.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileLegalScreen extends ConsumerWidget {
  const ProfileLegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(profileLegalControllerProvider);
    final controller = ref.read(profileLegalControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final disableManualRefresh = asyncState.maybeWhen(
      loading: () => true,
      data: (state) => state.isRefreshing,
      orElse: () => false,
    );
    final showRefreshSpinner = asyncState.maybeWhen(
      loading: () => true,
      data: (state) => state.isRefreshing,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.profileLegalTitle),
        actions: [
          IconButton(
            tooltip: l10n.profileLegalDownloadTooltip,
            onPressed: disableManualRefresh ? null : controller.refresh,
            icon: showRefreshSpinner
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_for_offline_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LegalScreenError(
            message: l10n.profileLegalLoadError,
            actionLabel: l10n.profileLegalRetryLabel,
            onRetry: controller.refresh,
          ),
          data: (state) => _LegalScreenBody(
            state: state,
            controller: controller,
            l10n: l10n,
          ),
        ),
      ),
    );
  }
}

class _LegalScreenError extends StatelessWidget {
  const _LegalScreenError({
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton(onPressed: onRetry, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _LegalScreenBody extends StatelessWidget {
  const _LegalScreenBody({
    required this.state,
    required this.controller,
    required this.l10n,
  });

  final ProfileLegalState state;
  final ProfileLegalController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      edgeOffset: AppTokens.spaceL,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (state.fromCache && state.lastSyncedAt != null)
                  _OfflineBanner(
                    l10n: l10n,
                    timestampLabel: _formatTimestamp(
                      state.lastSyncedAt!,
                      locale: state.locale,
                    ),
                  ),
                if (state.lastSyncedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.spaceM),
                    child: Text(
                      l10n.profileLegalSyncedLabel(
                        _formatTimestamp(
                          state.lastSyncedAt!,
                          locale: state.locale,
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                _LegalDocumentList(
                  state: state,
                  l10n: l10n,
                  onSelect: controller.selectDocument,
                ),
                const SizedBox(height: AppTokens.spaceL),
                _LegalDocumentViewer(state: state, l10n: l10n),
                const SizedBox(height: AppTokens.spaceS),
                _LegalFooter(state: state, l10n: l10n),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.l10n, required this.timestampLabel});

  final AppLocalizations l10n;
  final String timestampLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceL),
      padding: const EdgeInsets.all(AppTokens.spaceM),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppTokens.radiusM,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.offline_pin_outlined),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Text(
              l10n.profileLegalOfflineBanner(timestampLabel),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalDocumentList extends StatelessWidget {
  const _LegalDocumentList({
    required this.state,
    required this.l10n,
    required this.onSelect,
  });

  final ProfileLegalState state;
  final AppLocalizations l10n;
  final void Function(String documentId) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceM,
        vertical: AppTokens.spaceS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceM),
            child: Text(
              l10n.profileLegalDocumentsSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (var i = 0; i < state.documents.length; i++)
            Column(
              children: [
                _LegalDocumentTile(
                  document: state.documents[i],
                  state: state,
                  l10n: l10n,
                  onSelect: onSelect,
                  colorScheme: scheme,
                ),
                if (i < state.documents.length - 1) const Divider(height: 1),
              ],
            ),
          if (state.documents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceM),
              child: Text(
                l10n.profileLegalNoDocumentsLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalDocumentTile extends StatelessWidget {
  const _LegalDocumentTile({
    required this.document,
    required this.state,
    required this.l10n,
    required this.onSelect,
    required this.colorScheme,
  });

  final LegalDocument document;
  final ProfileLegalState state;
  final AppLocalizations l10n;
  final void Function(String documentId) onSelect;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => onSelect(document.id),
      selected: state.selectedDocument == document,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceM,
        vertical: AppTokens.spaceS,
      ),
      leading: CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHigh,
        child: Icon(_iconFor(document.type)),
      ),
      title: Text(
        document.title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (document.summary != null)
            Text(
              document.summary!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            l10n.profileLegalUpdatedLabel(
              _formatDate(document.updatedAt, locale: state.locale),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Chip(
        label: Text(l10n.profileLegalVersionChip(document.version)),
      ),
    );
  }

  IconData _iconFor(LegalDocumentType type) {
    switch (type) {
      case LegalDocumentType.terms:
        return Icons.article_outlined;
      case LegalDocumentType.privacy:
        return Icons.privacy_tip_outlined;
      case LegalDocumentType.commercial:
        return Icons.receipt_long_outlined;
      case LegalDocumentType.cancellation:
        return Icons.assignment_return_outlined;
    }
  }
}

class _LegalDocumentViewer extends StatelessWidget {
  const _LegalDocumentViewer({required this.state, required this.l10n});

  final ProfileLegalState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final document = state.selectedDocument;
    if (document == null) {
      return _LegalViewerEmptyState(l10n: l10n);
    }
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(document.title, style: Theme.of(context).textTheme.titleLarge),
          if (document.summary != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceS),
              child: Text(
                document.summary!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppTokens.spaceM),
          LegalDocumentBody(document: document),
        ],
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.state, required this.l10n});

  final ProfileLegalState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final document = state.selectedDocument;
    final hasLink = document?.shareUrl != null;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.open_in_new),
        onPressed: hasLink ? () => _openLink(context, document!) : null,
        label: Text(
          hasLink
              ? l10n.profileLegalOpenInBrowser
              : l10n.profileLegalOpenInBrowserUnavailable,
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, LegalDocument document) async {
    await _launchLegalLink(context, document.shareUrl, l10n);
  }
}

class _LegalViewerEmptyState extends StatelessWidget {
  const _LegalViewerEmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceXL),
      decoration: BoxDecoration(
        borderRadius: AppTokens.radiusL,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Text(
              l10n.profileLegalViewerEmptyState,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class LegalDocumentBody extends StatelessWidget {
  const LegalDocumentBody({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (document.bodyFormat == LegalDocumentBodyFormat.html) {
      return HtmlWidget(
        document.body,
        textStyle: theme.textTheme.bodyMedium,
        onTapUrl: (url) => _openLink(context, url, l10n),
      );
    }
    return MarkdownBody(
      data: document.body,
      styleSheet: MarkdownStyleSheet.fromTheme(theme),
      onTapLink: (_, href, __) {
        _openLink(context, href, l10n);
      },
    );
  }

  Future<bool> _openLink(
    BuildContext context,
    String? link,
    AppLocalizations l10n,
  ) {
    return _launchLegalLink(context, link, l10n);
  }
}

Future<bool> _launchLegalLink(
  BuildContext context,
  String? link,
  AppLocalizations l10n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (link == null || link.isEmpty) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.profileLegalOpenExternalError)),
      );
    return false;
  }
  final uri = Uri.tryParse(link);
  if (uri == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.profileLegalOpenExternalError)),
      );
    return false;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.profileLegalOpenExternalError)),
      );
  }
  return launched;
}

String _formatTimestamp(DateTime timestamp, {required Locale locale}) {
  final format = DateFormat.yMMMd(locale.toLanguageTag()).add_Hm();
  return format.format(timestamp);
}

String _formatDate(DateTime date, {required Locale locale}) {
  final format = DateFormat.yMMMd(locale.toLanguageTag());
  return format.format(date);
}
