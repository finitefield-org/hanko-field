// ignore_for_file: public_member_api_docs

import 'package:app/core/network/network_providers.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/core/storage/onboarding_preferences.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class OfflinePage extends ConsumerWidget {
  const OfflinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(onboardingPreferencesProvider).valueOrNull;
    final lastSync = prefs?.offlineCacheSeededAt;
    final hasCachedLibrary = lastSync != null;

    final title = l10n.offlineTitle;
    final message = l10n.offlineMessage;
    final retryLabel = l10n.offlineRetry;
    final cachedLabel = l10n.offlineOpenCachedLibrary;
    final cacheHint = l10n.offlineCacheHint;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.xl,
            tokens.spacing.xl,
            tokens.spacing.xl,
            tokens.spacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ElevatedOfflineCard(
                title: title,
                message: message,
                syncLabel: _syncLabel(context, lastSync),
              ),
              SizedBox(height: tokens.spacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () =>
                      ref.container.read(connectivityStatusProvider).refresh(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.refresh_rounded),
                      SizedBox(width: tokens.spacing.sm),
                      Text(retryLabel),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.spacing.sm),
              TextButton.icon(
                onPressed: hasCachedLibrary
                    ? () => ref.container
                          .read(navigationControllerProvider)
                          .go(AppRoutePaths.library)
                    : null,
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: Text(cachedLabel),
              ),
              if (!hasCachedLibrary) ...[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  cacheHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _DisabledNavigationBar(tokens: tokens),
    );
  }

  String _syncLabel(BuildContext context, DateTime? lastSync) {
    final l10n = AppLocalizations.of(context);
    if (lastSync == null) {
      return l10n.offlineLastSyncUnavailable;
    }
    final local = lastSync.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(local);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return l10n.offlineLastSyncLabel(date, time);
  }
}

class _ElevatedOfflineCard extends StatelessWidget {
  const _ElevatedOfflineCard({
    required this.title,
    required this.message,
    required this.syncLabel,
  });

  final String title;
  final String message;
  final String syncLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Card(
      elevation: 2,
      surfaceTintColor: tokens.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          children: [
            _OfflineIllustration(tokens: tokens),
            SizedBox(height: tokens.spacing.lg),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: tokens.spacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(height: tokens.spacing.md),
            InputChip(
              avatar: Icon(
                Icons.history_rounded,
                size: 18,
                color: tokens.colors.primary,
              ),
              label: Text(syncLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineIllustration extends StatelessWidget {
  const _OfflineIllustration({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: tokens.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: tokens.spacing.lg,
            top: tokens.spacing.md,
            child: _bubble(tokens.colors.primary.withValues(alpha: 0.16)),
          ),
          Positioned(
            right: tokens.spacing.xl,
            bottom: tokens.spacing.md,
            child: _bubble(tokens.colors.secondary.withValues(alpha: 0.2)),
          ),
          Container(
            padding: EdgeInsets.all(tokens.spacing.lg),
            decoration: BoxDecoration(
              color: tokens.colors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tokens.colors.onSurface.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.signal_wifi_off_rounded,
              size: 42,
              color: tokens.colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DisabledNavigationBar extends StatelessWidget {
  const _DisabledNavigationBar({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final destinations = AppTab.values
        .map(
          (tab) => NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
          ),
        )
        .toList();

    return SafeArea(
      top: false,
      child: Opacity(
        opacity: 0.45,
        child: IgnorePointer(
          child: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            height: 74,
            backgroundColor: tokens.colors.surface,
            indicatorColor: tokens.colors.surfaceVariant,
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
