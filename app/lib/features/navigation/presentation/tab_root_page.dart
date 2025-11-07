import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/core/ui/widgets/app_help_overlay.dart';
import 'package:app/core/ui/widgets/app_top_app_bar.dart';
import 'package:app/features/home/presentation/home_screen.dart';
import 'package:app/features/library/presentation/library_list_screen.dart';
import 'package:app/features/orders/presentation/orders_list_screen.dart';
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

    final experienceAsync = ref.watch(experienceGateProvider);
    final experience = experienceAsync.asData?.value;

    switch (tab) {
      case AppTab.shop:
        return const ShopHomeScreen();
      case AppTab.orders:
        return const OrdersListScreen();
      case AppTab.library:
        return const LibraryListScreen();
      case AppTab.profile:
        final subtitle = _composeSubtitle(
          '設定ページも Deep Link へ対応',
          experience?.profileSubtitle,
        );
        final chips = <String>[
          if (experience != null) ...[
            '言語: ${experience.locale.toLanguageTag()}',
            '地域: ${experience.regionLabel}',
            'ペルソナ: ${experience.personaLabel}',
          ],
        ];
        final sections = [
          ['addresses'],
          ['payments'],
          ['notifications'],
          ['support'],
        ];
        return _buildList(
          context,
          title: tab.headline,
          subtitle: subtitle,
          chips: chips,
          children: [
            for (final section in sections)
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(section.join(' / ')),
                onTap: () => _push(ref, ProfileSectionRoute(section)),
              ),
          ],
        );
      case AppTab.creation:
        return const SizedBox.shrink();
    }
  }

  Widget _buildList(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
    List<String> chips = const [],
  }) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        ListTile(
          title: Text(title, style: theme.textTheme.titleLarge),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final chip in chips) Chip(label: Text(chip))],
                ),
              ],
            ],
          ),
          isThreeLine: chips.isNotEmpty,
        ),
        ...children,
      ],
    );
  }

  String _composeSubtitle(String base, String? gatingDescription) {
    if (gatingDescription == null || gatingDescription.isEmpty) {
      return base;
    }
    if (gatingDescription == base) {
      return base;
    }
    return '$base\n$gatingDescription';
  }

  void _push(WidgetRef ref, IndependentRoute route) {
    ref.read(appStateProvider.notifier).push(route);
  }
}
