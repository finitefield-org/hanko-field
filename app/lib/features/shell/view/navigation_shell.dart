// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class NavigationShellScaffold extends ConsumerWidget {
  const NavigationShellScaffold({
    super.key,
    required this.navigationShell,
    required this.navigatorForIndex,
  });

  final StatefulNavigationShell navigationShell;
  final GlobalKey<NavigatorState> Function(int index) navigatorForIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final destinations = AppTab.values
        .map(
          (tab) => NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
          ),
        )
        .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final navigator = navigatorForIndex(
          navigationShell.currentIndex,
        ).currentState;

        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }

        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            final isReselect = index == navigationShell.currentIndex;
            navigationShell.goBranch(index, initialLocation: isReselect);
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
