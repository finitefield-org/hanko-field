import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/core/ui/widgets/app_help_overlay.dart';
import 'package:app/core/ui/widgets/app_top_app_bar.dart';
import 'package:app/features/home/presentation/home_screen.dart';
import 'package:app/features/library/presentation/library_list_screen.dart';
import 'package:app/features/orders/presentation/orders_list_screen.dart';
import 'package:app/features/profile/presentation/profile_home_screen.dart';
import 'package:app/features/shop/presentation/shop_home_screen.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 各タブのルート画面
class AppTabRootPage extends ConsumerWidget {
  const AppTabRootPage({required this.tab, super.key});

  final AppTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appStateProvider.notifier);
    final l10n = AppLocalizations.of(context);

    void openNotifications() {
      notifier.push(const NotificationsRoute());
    }

    void openSearch() {
      notifier.push(const GlobalSearchRoute());
    }

    void openHelp() {
      showHelpOverlay(context, contextLabel: tab.headline);
    }

    return AppShortcutRegistrar(
      onNotificationsTap: openNotifications,
      onSearchTap: openSearch,
      onHelpTap: openHelp,
      child: Scaffold(
        appBar: AppTopAppBar(
          title: tab == AppTab.creation ? l10n.homeAppBarTitle : tab.label,
          centerTitle: tab == AppTab.creation ? true : null,
          helpContextLabel: tab.headline,
          onNotificationsTap: openNotifications,
          onSearchTap: openSearch,
          onHelpTap: openHelp,
        ),
        body: _TabBody(tab: tab, ref: ref),
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab, required this.ref});

  final AppTab tab;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (tab == AppTab.creation) {
      return const HomeScreen();
    }

    switch (tab) {
      case AppTab.shop:
        return const ShopHomeScreen();
      case AppTab.orders:
        return const OrdersListScreen();
      case AppTab.library:
        return const LibraryListScreen();
      case AppTab.profile:
        return const ProfileHomeScreen();
      case AppTab.creation:
        return const SizedBox.shrink();
    }
  }
}
