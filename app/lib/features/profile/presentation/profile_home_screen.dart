import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/features/profile/application/profile_home_controller.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileHomeScreen extends ConsumerWidget {
  const ProfileHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(profileHomeControllerProvider);
    final l10n = AppLocalizations.of(context);

    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ProfileErrorView(
        message: l10n.profileHomeLoadError,
        actionLabel: l10n.profileHomeRetryLabel,
        onRetry: () =>
            ref.read(profileHomeControllerProvider.notifier).reload(),
      ),
      data: (state) => RefreshIndicator(
        onRefresh: () =>
            ref.read(profileHomeControllerProvider.notifier).reload(),
        edgeOffset: AppTokens.spaceL,
        displacement: AppTokens.spaceXL,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceM,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ProfileHeaderCard(state: state, l10n: l10n),
                  const SizedBox(height: AppTokens.spaceL),
                  _PersonaToggleCard(state: state),
                  const SizedBox(height: AppTokens.spaceXL),
                  Text(
                    l10n.profileHomeQuickLinksTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTokens.spaceS),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppTokens.spaceL,
                  mainAxisSpacing: AppTokens.spaceL,
                  childAspectRatio: 1.35,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final link = _quickLinks[index];
                  return _QuickLinkCard(
                    icon: link.icon,
                    title: link.titleBuilder(l10n),
                    subtitle: link.subtitleBuilder(l10n),
                    onTap: () => _openQuickLink(ref, link.routeSegments),
                  );
                }, childCount: _quickLinks.length),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppTokens.spaceXL * 2),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuickLink(WidgetRef ref, List<String> segments) {
    ref.read(appStateProvider.notifier).push(ProfileSectionRoute(segments));
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.state, required this.l10n});

  final ProfileHomeState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final membershipLabel = _membershipLabel(l10n, state.membershipStatus);
    final membershipIcon = _membershipIcon(state.membershipStatus);
    final identityLine = state.profile.email ?? state.identity?.email;

    return AppCard(
      variant: AppCardVariant.filled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarStack(
                imageUrl: state.profile.avatarUrl ?? state.identity?.photoUrl,
                displayName: state.profile.displayName ?? 'Hanko',
                onChangePhoto: () => _showChangePhotoMessage(context),
                tooltip: l10n.profileHomeAvatarButtonTooltip,
              ),
              const SizedBox(width: AppTokens.spaceL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.profile.displayName ??
                          l10n.profileHomeFallbackDisplayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (identityLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                        child: Text(
                          identityLine,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.spaceS),
                      child: Chip(
                        avatar: Icon(membershipIcon, size: 18),
                        label: Text(membershipLabel),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: scheme.secondaryContainer,
                        labelStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            l10n.profileHomeHeaderDescription,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showChangePhotoMessage(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.profileHomeAvatarUpdateMessage)),
    );
  }

  String _membershipLabel(
    AppLocalizations l10n,
    ProfileMembershipStatus status,
  ) {
    return switch (status) {
      ProfileMembershipStatus.active => l10n.profileHomeMembershipActive,
      ProfileMembershipStatus.suspended => l10n.profileHomeMembershipSuspended,
      ProfileMembershipStatus.staff => l10n.profileHomeMembershipStaff,
      ProfileMembershipStatus.admin => l10n.profileHomeMembershipAdmin,
    };
  }

  IconData _membershipIcon(ProfileMembershipStatus status) {
    return switch (status) {
      ProfileMembershipStatus.active => Icons.verified_user_outlined,
      ProfileMembershipStatus.suspended => Icons.error_outline,
      ProfileMembershipStatus.staff => Icons.support_agent,
      ProfileMembershipStatus.admin => Icons.shield_outlined,
    };
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({
    required this.imageUrl,
    required this.displayName,
    required this.onChangePhoto,
    required this.tooltip,
  });

  final String? imageUrl;
  final String displayName;
  final VoidCallback onChangePhoto;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final trimmed = displayName.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CircleAvatar(
              radius: 44,
              backgroundImage: imageUrl == null
                  ? null
                  : NetworkImage(imageUrl!),
              child: imageUrl == null
                  ? Text(
                      initials.toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: -6,
            right: -6,
            child: Tooltip(
              message: tooltip,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                onPressed: onChangePhoto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaToggleCard extends ConsumerWidget {
  const _PersonaToggleCard({required this.state});

  final ProfileHomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(profileHomeControllerProvider.notifier);

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileHomePersonaTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            l10n.profileHomePersonaSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.spaceM),
          SegmentedButton<UserPersona>(
            segments: [
              ButtonSegment(
                value: UserPersona.japanese,
                label: Text(l10n.profileHomePersonaDomestic),
                icon: const Icon(Icons.home_outlined),
              ),
              ButtonSegment(
                value: UserPersona.foreigner,
                label: Text(l10n.profileHomePersonaInternational),
                icon: const Icon(Icons.public_outlined),
              ),
            ],
            showSelectedIcon: false,
            selected: {state.profile.persona},
            onSelectionChanged: state.isSavingPersona
                ? null
                : (selection) async {
                    final persona = selection.first;
                    try {
                      await controller.changePersona(persona);
                    } catch (_) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.profileHomePersonaUpdateError),
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _QuickLinkDefinition {
  const _QuickLinkDefinition({
    required this.icon,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.routeSegments,
  });

  final IconData icon;
  final String Function(AppLocalizations) titleBuilder;
  final String Function(AppLocalizations) subtitleBuilder;
  final List<String> routeSegments;
}

final List<_QuickLinkDefinition> _quickLinks = [
  _QuickLinkDefinition(
    icon: Icons.language_outlined,
    titleBuilder: (l10n) => l10n.profileHomeQuickLinkLocaleTitle,
    subtitleBuilder: (l10n) => l10n.profileHomeQuickLinkLocaleSubtitle,
    routeSegments: ['locale'],
  ),
  _QuickLinkDefinition(
    icon: Icons.location_on_outlined,
    titleBuilder: (l10n) => l10n.profileHomeQuickLinkAddressesTitle,
    subtitleBuilder: (l10n) => l10n.profileHomeQuickLinkAddressesSubtitle,
    routeSegments: ['addresses'],
  ),
  _QuickLinkDefinition(
    icon: Icons.credit_card,
    titleBuilder: (l10n) => l10n.profileHomeQuickLinkPaymentsTitle,
    subtitleBuilder: (l10n) => l10n.profileHomeQuickLinkPaymentsSubtitle,
    routeSegments: ['payments'],
  ),
  _QuickLinkDefinition(
    icon: Icons.notifications_active_outlined,
    titleBuilder: (l10n) => l10n.profileHomeQuickLinkNotificationsTitle,
    subtitleBuilder: (l10n) => l10n.profileHomeQuickLinkNotificationsSubtitle,
    routeSegments: ['notifications'],
  ),
  _QuickLinkDefinition(
    icon: Icons.support_outlined,
    titleBuilder: (l10n) => l10n.profileHomeQuickLinkSupportTitle,
    subtitleBuilder: (l10n) => l10n.profileHomeQuickLinkSupportSubtitle,
    routeSegments: ['support'],
  ),
];

class _QuickLinkCard extends StatelessWidget {
  const _QuickLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: onTap,
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: AppTokens.radiusS,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceS),
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: AppTokens.spaceM),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorView extends StatelessWidget {
  const _ProfileErrorView({
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
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton(onPressed: onRetry, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
