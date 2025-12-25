// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/permissions/view_model/permissions_onboarding_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/security/storage_permission_client.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class PermissionsOnboardingPage extends ConsumerWidget {
  const PermissionsOnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final state = ref.watch(permissionsOnboardingViewModel);
    final requestAllState = ref.watch(
      permissionsOnboardingViewModel.requestAllMut,
    );
    final requestStorageState = ref.watch(
      permissionsOnboardingViewModel.requestStorageMut,
    );
    final requestNotificationsState = ref.watch(
      permissionsOnboardingViewModel.requestNotificationsMut,
    );

    final isRequesting =
        requestAllState is PendingMutationState ||
        requestStorageState is PendingMutationState ||
        requestNotificationsState is PendingMutationState;

    final data = state.valueOrNull;

    if (state is AsyncLoading<PermissionsOnboardingState> && data == null) {
      return Scaffold(
        backgroundColor: tokens.colors.background,
        appBar: AppTopBar(title: l10n.permissionsTitle, showBack: true),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (state is AsyncError<PermissionsOnboardingState> && data == null) {
      return Scaffold(
        backgroundColor: tokens.colors.background,
        appBar: AppTopBar(title: l10n.permissionsTitle, showBack: true),
        body: Padding(
          padding: EdgeInsets.all(tokens.spacing.xl),
          child: AppEmptyState(
            title: l10n.onboardingErrorTitle,
            message: state.error.toString(),
            icon: Icons.error_outline,
            actionLabel: l10n.onboardingRetry,
            onAction: () => ref.refreshValue(
              permissionsOnboardingViewModel,
              keepPrevious: false,
            ),
          ),
        ),
      );
    }

    final permissionState =
        data ??
        const PermissionsOnboardingState(
          storageStatus: StoragePermissionStatus.denied,
          notificationStatus: PermissionAccessStatus.unknown,
        );

    final personaLine = gates.emphasizeInternationalFlows
        ? l10n.permissionsPersonaInternational
        : l10n.permissionsPersonaDomestic;

    final storageAccess = _storageAccess(permissionState.storageStatus);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppTopBar(title: l10n.permissionsTitle, showBack: true),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(bottom: tokens.spacing.xl),
          children: [
            Container(
              width: double.infinity,
              color: tokens.colors.surface,
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: _PermissionsHeroCard(
                title: l10n.permissionsHeroTitle,
                body: l10n.permissionsHeroBody,
                personaLine: personaLine,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.permissionsSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.lg),
                  _PermissionCard(
                    icon: Icons.photo_camera_outlined,
                    title: l10n.permissionsPhotosTitle,
                    body: l10n.permissionsPhotosBody,
                    assists: [
                      l10n.permissionsPhotosAssist1,
                      l10n.permissionsPhotosAssist2,
                    ],
                    status: storageAccess,
                    l10n: l10n,
                    fallback: _needsFallback(storageAccess)
                        ? l10n.permissionsFallbackPhotos
                        : null,
                    actionLabel: l10n.permissionsItemActionAllow,
                    onRequest: isRequesting
                        ? null
                        : () => ref.invoke(
                            permissionsOnboardingViewModel.requestStorage(),
                          ),
                  ),
                  SizedBox(height: tokens.spacing.md),
                  _PermissionCard(
                    icon: Icons.folder_open_outlined,
                    title: l10n.permissionsStorageTitle,
                    body: l10n.permissionsStorageBody,
                    assists: [
                      l10n.permissionsStorageAssist1,
                      l10n.permissionsStorageAssist2,
                    ],
                    status: storageAccess,
                    l10n: l10n,
                    fallback: _needsFallback(storageAccess)
                        ? l10n.permissionsFallbackStorage
                        : null,
                    actionLabel: l10n.permissionsItemActionAllow,
                    onRequest: isRequesting
                        ? null
                        : () => ref.invoke(
                            permissionsOnboardingViewModel.requestStorage(),
                          ),
                  ),
                  SizedBox(height: tokens.spacing.md),
                  _PermissionCard(
                    icon: Icons.notifications_active_outlined,
                    title: l10n.permissionsNotificationsTitle,
                    body: l10n.permissionsNotificationsBody,
                    assists: [
                      l10n.permissionsNotificationsAssist1,
                      l10n.permissionsNotificationsAssist2,
                    ],
                    status: permissionState.notificationStatus,
                    l10n: l10n,
                    fallback: _needsFallback(permissionState.notificationStatus)
                        ? l10n.permissionsFallbackNotifications
                        : null,
                    actionLabel: l10n.permissionsItemActionAllow,
                    onRequest: isRequesting
                        ? null
                        : () => ref.invoke(
                            permissionsOnboardingViewModel
                                .requestNotifications(),
                          ),
                  ),
                  SizedBox(height: tokens.spacing.xl),
                  AppButton(
                    label: l10n.permissionsCtaGrantAll,
                    onPressed: isRequesting
                        ? null
                        : () => ref.invoke(
                            permissionsOnboardingViewModel.requestAll(),
                          ),
                    isLoading: requestAllState is PendingMutationState,
                    expand: true,
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  AppButton(
                    label: l10n.permissionsCtaNotNow,
                    variant: AppButtonVariant.ghost,
                    onPressed: isRequesting ? null : () => context.pop(),
                    expand: true,
                  ),
                  SizedBox(height: tokens.spacing.md),
                  Center(
                    child: TextButton(
                      onPressed: isRequesting
                          ? null
                          : () => context.go(AppRoutePaths.profileLegal),
                      child: Text(l10n.permissionsFooterPolicy),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionsHeroCard extends StatelessWidget {
  const _PermissionsHeroCard({
    required this.title,
    required this.body,
    required this.personaLine,
  });

  final String title;
  final String body;
  final String personaLine;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final primary = tokens.colors.primary;
    final secondary = tokens.colors.secondary;

    return Material(
      color: tokens.colors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(tokens.radii.lg),
      shadowColor: tokens.colors.onSurface.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 12,
                    child: _HeroShape(
                      size: 92,
                      color: primary.withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 8,
                    child: _HeroShape(
                      size: 110,
                      color: secondary.withValues(alpha: 0.18),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(tokens.spacing.md),
                      decoration: BoxDecoration(
                        color: tokens.colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(tokens.radii.md),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_outlined),
                          SizedBox(height: 8),
                          Icon(Icons.folder_open_outlined),
                          SizedBox(height: 8),
                          Icon(Icons.notifications_active_outlined),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.md),
            Text(title, style: theme.textTheme.titleLarge),
            SizedBox(height: tokens.spacing.xs),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(height: tokens.spacing.sm),
            Row(
              children: [
                Icon(
                  Icons.person_pin_circle_outlined,
                  size: tokens.spacing.md,
                  color: tokens.colors.primary,
                ),
                SizedBox(width: tokens.spacing.xs),
                Expanded(
                  child: Text(
                    personaLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroShape extends StatelessWidget {
  const _HeroShape({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.assists,
    required this.status,
    required this.l10n,
    required this.actionLabel,
    required this.onRequest,
    this.fallback,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> assists;
  final PermissionAccessStatus status;
  final AppLocalizations l10n;
  final String actionLabel;
  final VoidCallback? onRequest;
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(tokens.radii.md),
                ),
                child: Icon(icon, color: tokens.colors.primary),
              ),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: assists
                .map(
                  (assist) => InputChip(
                    label: Text(assist),
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.colors.onSurface,
                    ),
                    backgroundColor: tokens.colors.surfaceVariant,
                    side: BorderSide(
                      color: tokens.colors.outline.withValues(alpha: 0.4),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.xs,
            children: [
              _StatusChip(status: status, l10n: l10n),
              ActionChip(
                label: Text(actionLabel),
                onPressed: status.isGranted ? null : onRequest,
                avatar: Icon(
                  Icons.lock_open_rounded,
                  size: tokens.spacing.md,
                  color: status.isGranted
                      ? tokens.colors.onSurface.withValues(alpha: 0.5)
                      : tokens.colors.primary,
                ),
              ),
            ],
          ),
          if (fallback != null) ...[
            SizedBox(height: tokens.spacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: tokens.spacing.md,
                  color: tokens.colors.warning,
                ),
                SizedBox(width: tokens.spacing.xs),
                Expanded(
                  child: Text(
                    fallback!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final PermissionAccessStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final color = _statusColor(status, tokens);

    return Chip(
      label: Text(_statusLabel(status, l10n)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      avatar: Icon(_statusIcon(status), size: tokens.spacing.md, color: color),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

bool _needsFallback(PermissionAccessStatus status) {
  return status == PermissionAccessStatus.denied ||
      status == PermissionAccessStatus.restricted;
}

PermissionAccessStatus _storageAccess(StoragePermissionStatus status) {
  return switch (status) {
    StoragePermissionStatus.granted => PermissionAccessStatus.granted,
    StoragePermissionStatus.denied => PermissionAccessStatus.denied,
    StoragePermissionStatus.restricted => PermissionAccessStatus.restricted,
  };
}

String _statusLabel(PermissionAccessStatus status, AppLocalizations l10n) {
  return switch (status) {
    PermissionAccessStatus.granted => l10n.permissionsStatusGranted,
    PermissionAccessStatus.denied => l10n.permissionsStatusDenied,
    PermissionAccessStatus.restricted => l10n.permissionsStatusRestricted,
    PermissionAccessStatus.unknown => l10n.permissionsStatusUnknown,
  };
}

IconData _statusIcon(PermissionAccessStatus status) {
  return switch (status) {
    PermissionAccessStatus.granted => Icons.check_circle_outline,
    PermissionAccessStatus.denied => Icons.block,
    PermissionAccessStatus.restricted => Icons.lock_outline,
    PermissionAccessStatus.unknown => Icons.help_outline,
  };
}

Color _statusColor(PermissionAccessStatus status, DesignTokens tokens) {
  return switch (status) {
    PermissionAccessStatus.granted => tokens.colors.success,
    PermissionAccessStatus.denied => tokens.colors.error,
    PermissionAccessStatus.restricted => tokens.colors.warning,
    PermissionAccessStatus.unknown => tokens.colors.outline,
  };
}
