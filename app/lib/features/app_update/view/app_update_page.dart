// ignore_for_file: public_member_api_docs

import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_update_provider.dart';
import 'package:app/shared/providers/feature_flags_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdatePage extends ConsumerStatefulWidget {
  const AppUpdatePage({super.key});

  @override
  ConsumerState<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends ConsumerState<AppUpdatePage> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(appUpdateStatusProvider);
    final status = state.valueOrNull;
    final canPop = status?.isUpdateRequired != true;
    final title = status?.isUpdateRequired == true
        ? l10n.appUpdateCardRequiredTitle
        : l10n.appUpdateTitle;

    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: tokens.colors.background,
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: canPop,
          title: Text(title),
          actions: [
            TextButton(
              onPressed: _isRefreshing ? null : _refresh,
              child: Text(l10n.appUpdateCheckAgain),
            ),
          ],
        ),
        body: switch (state) {
          AsyncLoading() => const _LoadingBody(),
          AsyncError(:final error) => _ErrorBody(
            error: error,
            onRetry: _refresh,
          ),
          AsyncData(:final value) => _AppUpdateContent(
            status: value,
            onUpdateNow: () => _openStore(value),
            onContinue: canPop ? () => Navigator.of(context).maybePop() : null,
          ),
        },
      ),
    );
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await ref.invoke(featureFlagsProvider.refresh());
      if (mounted) {
        ref.invalidate(appUpdateStatusProvider);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _openStore(AppUpdateStatus status) async {
    final candidates = <Uri>[
      if (status.storePrimaryUrl != null) status.storePrimaryUrl!,
      if (status.storeFallbackUrl != null) status.storeFallbackUrl!,
    ];
    for (final uri in candidates) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).appUpdateStoreOpenFailed),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: tokens.spacing.xl,
            height: tokens.spacing.xl,
            child: CircularProgressIndicator.adaptive(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          Text(AppLocalizations.of(context).appUpdateChecking),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: AppLocalizations.of(context).appUpdateVerifyFailedTitle,
      message: error.toString(),
      icon: Icons.update_disabled_outlined,
      actionLabel: AppLocalizations.of(context).appUpdateRetry,
      onAction: onRetry,
    );
  }
}

class _AppUpdateContent extends StatelessWidget {
  const _AppUpdateContent({
    required this.status,
    required this.onUpdateNow,
    required this.onContinue,
  });

  final AppUpdateStatus status;
  final VoidCallback onUpdateNow;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isRequired = status.isUpdateRequired;
    final canOpenStore = status.hasStoreLinks;
    final surfaceColor = isRequired ? scheme.errorContainer : scheme.surface;
    final outlineColor = isRequired ? scheme.error : scheme.outline;
    final contentColor = isRequired
        ? scheme.onErrorContainer
        : scheme.onSurface;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.md,
          tokens.spacing.lg,
          tokens.spacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MaterialBanner(
              backgroundColor: scheme.surfaceContainerHighest,
              leading: Icon(
                Icons.system_update_alt_rounded,
                color: scheme.error,
              ),
              content: Text(
                isRequired
                    ? l10n.appUpdateBannerRequired
                    : l10n.appUpdateBannerOptional,
              ),
              actions: [
                TextButton(
                  onPressed: canOpenStore ? onUpdateNow : null,
                  child: Text(l10n.appUpdateBannerAction),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.lg),
            Card(
              color: surfaceColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radii.lg),
                side: BorderSide(color: outlineColor),
              ),
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRequired
                          ? l10n.appUpdateCardRequiredTitle
                          : l10n.appUpdateCardOptionalTitle,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: contentColor),
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    Text(
                      l10n.appUpdateCurrentVersion(status.currentVersion),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: contentColor),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      l10n.appUpdateMinimumVersion(status.minSupportedVersion),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: contentColor),
                    ),
                    if (status.latestVersion.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        l10n.appUpdateLatestVersion(status.latestVersion),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: contentColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton(
              onPressed: canOpenStore ? onUpdateNow : null,
              child: Text(l10n.appUpdateNow),
            ),
            TextButton(
              onPressed: canOpenStore ? onUpdateNow : null,
              child: Text(l10n.appUpdateOpenStore),
            ),
            if (onContinue != null) ...[
              SizedBox(height: tokens.spacing.sm),
              TextButton(
                onPressed: onContinue,
                child: Text(l10n.appUpdateContinue),
              ),
            ],
            if (!canOpenStore) ...[
              SizedBox(height: tokens.spacing.md),
              Text(
                l10n.appUpdateStoreUnavailable,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
