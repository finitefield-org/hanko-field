// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_update_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class NavigationShellScaffold extends ConsumerStatefulWidget {
  const NavigationShellScaffold({
    super.key,
    required this.navigationShell,
    required this.navigatorForIndex,
  });

  final StatefulNavigationShell navigationShell;
  final GlobalKey<NavigatorState> Function(int index) navigatorForIndex;

  @override
  ConsumerState<NavigationShellScaffold> createState() =>
      _NavigationShellScaffoldState();
}

class _NavigationShellScaffoldState
    extends ConsumerState<NavigationShellScaffold> {
  String? _dismissedUpdateVersion;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    final updateStatus = ref.watch(appUpdateStatusProvider).valueOrNull;
    final latestVersion = updateStatus?.latestVersion ?? '';
    final showUpdateReminder =
        updateStatus?.isUpdateRecommended == true &&
        updateStatus?.isUpdateRequired != true &&
        latestVersion.isNotEmpty &&
        _dismissedUpdateVersion != latestVersion;
    Widget tabIcon(AppTab tab, {required bool selected}) {
      final icon = Icon(selected ? tab.selectedIcon : tab.icon);
      if (tab != AppTab.profile || unread <= 0) return icon;
      return Badge.count(
        count: unread,
        backgroundColor: tokens.colors.primary,
        textColor: tokens.colors.onPrimary,
        offset: const Offset(6, -4),
        child: icon,
      );
    }

    final destinations = AppTab.values
        .map(
          (tab) => NavigationDestination(
            icon: tabIcon(tab, selected: false),
            selectedIcon: tabIcon(tab, selected: true),
            label: tab.label,
          ),
        )
        .toList();

    final banner = showUpdateReminder
        ? MaterialBanner(
            backgroundColor: tokens.colors.surfaceVariant,
            leading: Icon(
              Icons.system_update_alt_rounded,
              color: tokens.colors.primary,
            ),
            content: Text(l10n.appUpdateReminder(latestVersion)),
            actions: [
              TextButton(
                onPressed: () {
                  GoRouter.of(context).push(AppRoutePaths.appUpdate);
                },
                child: Text(l10n.appUpdateBannerAction),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _dismissedUpdateVersion = latestVersion);
                },
                child: Text(l10n.appUpdateLater),
              ),
            ],
          )
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final navigator = widget
            .navigatorForIndex(widget.navigationShell.currentIndex)
            .currentState;

        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }

        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        body: banner == null
            ? widget.navigationShell
            : Column(
                children: [
                  banner,
                  Expanded(child: widget.navigationShell),
                ],
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) {
            final isReselect = index == widget.navigationShell.currentIndex;
            widget.navigationShell.goBranch(index, initialLocation: isReselect);
          },
          height: 74,
          backgroundColor: tokens.colors.surface,
          indicatorColor: tokens.colors.surfaceVariant,
          destinations: destinations,
        ),
      ),
    );
  }
}
