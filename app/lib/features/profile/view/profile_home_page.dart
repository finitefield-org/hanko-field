// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/profile/view_model/profile_home_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/buttons/app_button.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:app/ui/feedback/app_skeleton.dart';
import 'package:app/ui/overlays/app_modal.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final _logger = Logger('ProfileHomePage');

class ProfileHomePage extends ConsumerWidget {
  const ProfileHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final navigation = context.navigation;

    final state = ref.watch(profileHomeViewModel);
    final personaUpdate = ref.watch(profileHomeViewModel.updatePersonaMut);
    final refreshState = ref.watch(profileHomeViewModel.refreshMut);
    final isBusy =
        personaUpdate is PendingMutationState ||
        refreshState is PendingMutationState;

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          try {
            await ref.invoke(profileHomeViewModel.refresh());
          } catch (_) {}
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.large(
              title: Text(l10n.profileTitle),
              leading: switch (state) {
                AsyncData(:final value) => IconButton(
                  tooltip: l10n.profileAvatarUpdateTooltip,
                  onPressed: isBusy
                      ? null
                      : () => unawaited(_showAvatarUpdateSheet(context)),
                  icon: _AvatarCircle(url: value.avatarUrl, size: 32),
                ),
                _ => IconButton(
                  tooltip: l10n.profileAvatarUpdateTooltip,
                  onPressed: isBusy
                      ? null
                      : () => unawaited(_showAvatarUpdateSheet(context)),
                  icon: const _AvatarCircle(url: null, size: 32),
                ),
              },
              actions: [
                IconButton(
                  tooltip: l10n.profileAvatarUpdateTooltip,
                  onPressed: isBusy
                      ? null
                      : () => unawaited(_showAvatarUpdateSheet(context)),
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
                SizedBox(width: tokens.spacing.sm),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              sliver: switch (state) {
                AsyncLoading() => SliverToBoxAdapter(
                  child: _ProfileLoading(tokens: tokens),
                ),
                AsyncError(:final error, :final stack) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    title: l10n.profileLoadFailedTitle,
                    message: kDebugMode
                        ? '${l10n.profileLoadFailedMessage}\n\n$error'
                        : l10n.profileLoadFailedMessage,
                    icon: Icons.person_off_outlined,
                    actionLabel: l10n.profileRetry,
                    onAction: () {
                      _logger.warning('Profile load failed', error, stack);
                      ref.invalidate(profileHomeViewModel);
                    },
                  ),
                ),
                AsyncData(:final value) => SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    _ProfileHeaderCard(state: value),
                    SizedBox(height: tokens.spacing.lg),
                    _PersonaToggleCard(
                      persona: value.persona,
                      isBusy: isBusy,
                      onChanged: (persona) async {
                        try {
                          await ref.invoke(
                            profileHomeViewModel.updatePersona(persona),
                          );
                        } catch (_) {}
                      },
                    ),
                    SizedBox(height: tokens.spacing.lg),
                    Text(
                      l10n.profileQuickLinksTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: tokens.spacing.md),
                    _QuickLinksGrid(
                      onNavigate: navigation.go,
                      disabled: isBusy,
                    ),
                    SizedBox(height: tokens.spacing.lg),
                    Text(
                      l10n.profileSettingsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: tokens.spacing.md),
                    _SettingsList(onNavigate: navigation.go, disabled: isBusy),
                    SizedBox(height: tokens.spacing.xl),
                    if (!value.isAuthenticated)
                      AppButton(
                        label: l10n.profileSignInCta,
                        onPressed: isBusy
                            ? null
                            : () => navigation.go(AppRoutePaths.auth),
                        variant: AppButtonVariant.primary,
                        expand: true,
                      ),
                    if (value.isAuthenticated)
                      AppListTile(
                        title: Text(l10n.profileAccountSecurityTitle),
                        subtitle: Text(l10n.profileAccountSecuritySubtitle),
                        leading: const Icon(Icons.security_outlined),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: isBusy
                            ? null
                            : () =>
                                  unawaited(_showSecurityPlaceholder(context)),
                      ),
                  ]),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSkeletonBlock(
          width: 240,
          height: 28,
          borderRadius: BorderRadius.circular(tokens.radii.md),
        ),
        SizedBox(height: tokens.spacing.md),
        const AppListSkeleton(items: 2, itemHeight: 96),
        SizedBox(height: tokens.spacing.lg),
        const AppListSkeleton(items: 4, itemHeight: 72),
      ],
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.state});

  final ProfileHomeState state;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final statusLabel = !state.isAuthenticated
        ? l10n.profileStatusSignedOut
        : state.isAnonymous
        ? l10n.profileStatusGuest
        : l10n.profileStatusMember;

    final statusColor = !state.isAuthenticated
        ? colorScheme.surfaceContainerHighest
        : state.isAnonymous
        ? colorScheme.tertiary
        : colorScheme.primary;

    final statusTextColor = !state.isAuthenticated
        ? colorScheme.onSurface
        : state.isAnonymous
        ? colorScheme.onTertiary
        : colorScheme.onPrimary;

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Row(
        children: [
          _AvatarCircle(url: state.avatarUrl, size: 56),
          SizedBox(width: tokens.spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.displayName, style: theme.textTheme.titleLarge),
                if (state.email != null && state.email!.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    state.email!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(statusLabel),
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: statusTextColor,
                    ),
                    backgroundColor: statusColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaToggleCard extends StatelessWidget {
  const _PersonaToggleCard({
    required this.persona,
    required this.isBusy,
    required this.onChanged,
  });

  final UserPersona persona;
  final bool isBusy;
  final ValueChanged<UserPersona> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profilePersonaTitle, style: theme.textTheme.titleMedium),
          SizedBox(height: tokens.spacing.xs),
          Text(
            l10n.profilePersonaSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          SegmentedButton<UserPersona>(
            segments: [
              ButtonSegment(
                value: UserPersona.japanese,
                label: Text(l10n.profilePersonaJapanese),
                icon: const Icon(Icons.verified_outlined),
              ),
              ButtonSegment(
                value: UserPersona.foreigner,
                label: Text(l10n.profilePersonaForeigner),
                icon: const Icon(Icons.public_outlined),
              ),
            ],
            selected: {persona},
            showSelectedIcon: false,
            onSelectionChanged: isBusy
                ? null
                : (selection) {
                    if (selection.isEmpty) return;
                    onChanged(selection.first);
                  },
          ),
        ],
      ),
    );
  }
}

class _QuickLinksGrid extends StatelessWidget {
  const _QuickLinksGrid({required this.onNavigate, required this.disabled});

  final ValueChanged<String> onNavigate;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final items = [
      _QuickLink(
        title: l10n.profileQuickOrdersTitle,
        subtitle: l10n.profileQuickOrdersSubtitle,
        icon: Icons.receipt_long_outlined,
        route: AppRoutePaths.orders,
      ),
      _QuickLink(
        title: l10n.profileQuickLibraryTitle,
        subtitle: l10n.profileQuickLibrarySubtitle,
        icon: Icons.collections_bookmark_outlined,
        route: AppRoutePaths.library,
      ),
      _QuickLink(
        title: l10n.profileAddressesTitle,
        subtitle: l10n.profileAddressesSubtitle,
        icon: Icons.location_on_outlined,
        route: AppRoutePaths.profileAddresses,
      ),
      _QuickLink(
        title: l10n.profileSupportTitle,
        subtitle: l10n.profileSupportSubtitle,
        icon: Icons.support_agent_outlined,
        route: AppRoutePaths.profileSupport,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisExtent: 120,
            crossAxisSpacing: tokens.spacing.md,
            mainAxisSpacing: tokens.spacing.md,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return AppCard(
              onTap: disabled ? null : () => onNavigate(item.route),
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, color: Theme.of(context).colorScheme.primary),
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    item.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickLink {
  const _QuickLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({required this.onNavigate, required this.disabled});

  final ValueChanged<String> onNavigate;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final items = [
      (
        title: l10n.profileAddressesTitle,
        subtitle: l10n.profileAddressesSubtitle,
        icon: Icons.location_on_outlined,
        route: AppRoutePaths.profileAddresses,
      ),
      (
        title: l10n.profilePaymentsTitle,
        subtitle: l10n.profilePaymentsSubtitle,
        icon: Icons.credit_card_outlined,
        route: AppRoutePaths.profilePayments,
      ),
      (
        title: l10n.profileNotificationsTitle,
        subtitle: l10n.profileNotificationsSubtitle,
        icon: Icons.notifications_outlined,
        route: AppRoutePaths.profileNotifications,
      ),
      (
        title: l10n.profileLocaleTitle,
        subtitle: l10n.profileLocaleSubtitle,
        icon: Icons.language_outlined,
        route: AppRoutePaths.profileLocale,
      ),
      (
        title: l10n.profileLegalTitle,
        subtitle: l10n.profileLegalSubtitle,
        icon: Icons.gavel_outlined,
        route: AppRoutePaths.profileLegal,
      ),
      (
        title: l10n.profileSupportTitle,
        subtitle: l10n.profileSupportSubtitle,
        icon: Icons.support_agent_outlined,
        route: AppRoutePaths.profileSupport,
      ),
      (
        title: l10n.profileGuidesTitle,
        subtitle: l10n.profileGuidesSubtitle,
        icon: Icons.menu_book_outlined,
        route: '${AppRoutePaths.profile}/guides',
      ),
      (
        title: l10n.profileHowtoTitle,
        subtitle: l10n.profileHowtoSubtitle,
        icon: Icons.play_circle_outline,
        route: '${AppRoutePaths.profile}/howto',
      ),
      (
        title: l10n.profileLinkedAccountsTitle,
        subtitle: l10n.profileLinkedAccountsSubtitle,
        icon: Icons.link_outlined,
        route: AppRoutePaths.profileLinkedAccounts,
      ),
      (
        title: l10n.profileExportTitle,
        subtitle: l10n.profileExportSubtitle,
        icon: Icons.download_outlined,
        route: AppRoutePaths.profileExport,
      ),
      (
        title: l10n.profileDeleteTitle,
        subtitle: l10n.profileDeleteSubtitle,
        icon: Icons.delete_outline,
        route: AppRoutePaths.profileDelete,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: tokens.spacing.md),
          AppListTile(
            title: Text(items[i].title),
            subtitle: Text(items[i].subtitle),
            leading: Icon(items[i].icon),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: disabled ? null : () => onNavigate(items[i].route),
          ),
        ],
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final uri = url == null || url!.trim().isEmpty ? null : Uri.tryParse(url!);
    final hasImage =
        uri != null &&
        uri.isAbsolute &&
        (uri.scheme == 'http' || uri.scheme == 'https');

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colorScheme.surfaceContainerHighest,
      foregroundImage: hasImage ? NetworkImage(url!) : null,
      child: hasImage
          ? null
          : Icon(Icons.person, size: size * 0.55, color: colorScheme.primary),
    );
  }
}

Future<void> _showAvatarUpdateSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppModal<void>(
    context: context,
    title: l10n.profileAvatarUpdateTitle,
    primaryAction: l10n.profileAvatarUpdateOk,
    onPrimaryPressed: () => Navigator.of(context).maybePop(),
    body: Text(l10n.profileAvatarUpdateBody),
  );
}

Future<void> _showSecurityPlaceholder(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppModal<void>(
    context: context,
    title: l10n.profileAccountSecurityTitle,
    primaryAction: l10n.profileAvatarUpdateOk,
    onPrimaryPressed: () => Navigator.of(context).maybePop(),
    body: Text(l10n.profileAccountSecurityBody),
  );
}
