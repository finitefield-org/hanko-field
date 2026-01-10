// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/app_router.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/cart/view/cart_page.dart';
import 'package:app/features/catalog/view/material_detail_page.dart';
import 'package:app/features/catalog/view/product_addons_page.dart';
import 'package:app/features/catalog/view/product_detail_page.dart';
import 'package:app/features/catalog/view/shop_home_page.dart';
import 'package:app/features/checkout/view/checkout_address_page.dart';
import 'package:app/features/checkout/view/checkout_complete_page.dart';
import 'package:app/features/checkout/view/checkout_payment_page.dart';
import 'package:app/features/checkout/view/checkout_review_page.dart';
import 'package:app/features/checkout/view/checkout_shipping_page.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view/design_ai_page.dart';
import 'package:app/features/designs/view/design_check_page.dart';
import 'package:app/features/designs/view/design_editor_page.dart';
import 'package:app/features/designs/view/design_export_page.dart';
import 'package:app/features/designs/view/design_input_page.dart';
import 'package:app/features/designs/view/design_preview_page.dart';
import 'package:app/features/designs/view/design_share_page.dart';
import 'package:app/features/designs/view/design_style_selection_page.dart';
import 'package:app/features/designs/view/design_type_selection_page.dart';
import 'package:app/features/designs/view/design_versions_page.dart';
import 'package:app/features/designs/view/kanji_mapping_page.dart';
import 'package:app/features/guides/view/guide_detail_page.dart';
import 'package:app/features/guides/view/guides_list_page.dart';
import 'package:app/features/home/view/home_page.dart';
import 'package:app/features/howto/view/howto_page.dart';
import 'package:app/features/kanji_dictionary/view/kanji_dictionary_page.dart';
import 'package:app/features/library/view/library_design_detail_page.dart';
import 'package:app/features/library/view/library_design_duplicate_page.dart';
import 'package:app/features/library/view/library_design_export_page.dart';
import 'package:app/features/library/view/library_design_shares_page.dart';
import 'package:app/features/library/view/library_design_versions_page.dart';
import 'package:app/features/library/view/library_list_page.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/features/orders/view/order_detail_page.dart';
import 'package:app/features/orders/view/order_invoice_page.dart';
import 'package:app/features/orders/view/order_production_timeline_page.dart';
import 'package:app/features/orders/view/order_reorder_page.dart';
import 'package:app/features/orders/view/order_tracking_page.dart';
import 'package:app/features/orders/view/orders_page.dart';
import 'package:app/features/profile/view/profile_addresses_page.dart';
import 'package:app/features/profile/view/profile_delete_page.dart';
import 'package:app/features/profile/view/profile_export_page.dart';
import 'package:app/features/profile/view/profile_home_page.dart';
import 'package:app/features/profile/view/profile_legal_page.dart';
import 'package:app/features/profile/view/profile_linked_accounts_page.dart';
import 'package:app/features/profile/view/profile_locale_page.dart';
import 'package:app/features/profile/view/profile_notifications_page.dart';
import 'package:app/features/profile/view/profile_payments_page.dart';
import 'package:app/features/profile/view/profile_support_page.dart';
import 'package:app/features/shell/view/tab_placeholder_page.dart';
import 'package:app/features/support/view/faq_page.dart';
import 'package:app/features/support/view/support_chat_page.dart';
import 'package:app/features/support/view/support_contact_page.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_update_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miniriverpod/miniriverpod.dart';

class NavigationShellScaffold extends ConsumerStatefulWidget {
  const NavigationShellScaffold({super.key});

  @override
  ConsumerState<NavigationShellScaffold> createState() =>
      _NavigationShellScaffoldState();
}

class _NavigationShellScaffoldState
    extends ConsumerState<NavigationShellScaffold> {
  static const _tabDesign = TabId('design');
  static const _tabShop = TabId('shop');
  static const _tabOrders = TabId('orders');
  static const _tabLibrary = TabId('library');
  static const _tabProfile = TabId('profile');

  String? _dismissedUpdateVersion;

  List<DeclarativeTabItem> _tabItems(DesignTokens tokens, int unreadCount) {
    Widget tabIcon(AppTab tab, {required bool selected}) {
      final icon = Icon(selected ? tab.selectedIcon : tab.icon);
      if (tab != AppTab.profile || unreadCount <= 0) return icon;
      return Badge.count(
        count: unreadCount,
        backgroundColor: tokens.colors.primary,
        textColor: tokens.colors.onPrimary,
        offset: const Offset(6, -4),
        child: icon,
      );
    }

    return AppTab.values
        .map(
          (tab) => DeclarativeTabItem(
            tab: _tabIdFor(tab),
            item: BottomNavigationBarItem(
              icon: tabIcon(tab, selected: false),
              activeIcon: tabIcon(tab, selected: true),
              label: tab.label,
            ),
          ),
        )
        .toList();
  }

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

    final nav = ref.watch(appNavigationProvider);
    final pagesByTab = {
      for (final entry in nav.pagesByTab.entries)
        _tabIdFor(entry.key): entry.value,
    };

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
                onPressed: () => context.push(AppRoutePaths.appUpdate),
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

    final tabs = DeclarativeTabsScaffold(
      items: _tabItems(tokens, unread),
      currentTab: _tabIdFor(nav.currentTab),
      onSelectTab: (tab) =>
          ref.invoke(appNavigationProvider.selectTab(_appTabFor(tab))),
      pagesByTab: pagesByTab,
      setPagesForTab: (tab, pages) =>
          ref.invoke(appNavigationProvider.setPages(_appTabFor(tab), pages)),
      buildPage: (context, tab, page) =>
          _buildPage(context, _appTabFor(tab), page),
      onBackAtRoot: () => SystemNavigator.pop(),
    );

    if (banner == null) return tabs;

    return Stack(
      children: [
        tabs,
        Positioned(left: 0, right: 0, top: 0, child: SafeArea(child: banner)),
      ],
    );
  }

  TabId _tabIdFor(AppTab tab) {
    return switch (tab) {
      AppTab.design => _tabDesign,
      AppTab.shop => _tabShop,
      AppTab.orders => _tabOrders,
      AppTab.library => _tabLibrary,
      AppTab.profile => _tabProfile,
    };
  }

  AppTab _appTabFor(TabId tab) {
    return switch (tab) {
      _tabDesign => AppTab.design,
      _tabShop => AppTab.shop,
      _tabOrders => AppTab.orders,
      _tabLibrary => AppTab.library,
      _tabProfile => AppTab.profile,
      _ => AppTab.design,
    };
  }

  Widget _buildPage(BuildContext context, AppTab tab, PageEntry page) {
    final uri = Uri.parse(page.name);
    final path = uri.path;

    if (tab == AppTab.design) {
      if (path == AppRoutePaths.home) return const HomePage();
      if (path == AppRoutePaths.design) {
        return const TabPlaceholderPage(
          title: '作成',
          routePath: AppRoutePaths.design,
          detail: 'Design tab root',
        );
      }
      if (path == AppRoutePaths.designNew) {
        return const DesignTypeSelectionPage();
      }
      if (path == AppRoutePaths.designInput) {
        final mode = uri.queryParameters['mode'];
        DesignSourceType? sourceType;
        if (mode != null) {
          try {
            sourceType = DesignSourceTypeX.fromJson(mode);
          } catch (_) {}
        }
        return DesignInputPage(sourceType: sourceType);
      }
      if (path == AppRoutePaths.designKanjiMap) {
        return const KanjiMappingPage();
      }
      if (path == AppRoutePaths.designStyle) {
        final mode = uri.queryParameters['mode'];
        DesignSourceType? sourceType;
        if (mode != null) {
          try {
            sourceType = DesignSourceTypeX.fromJson(mode);
          } catch (_) {}
        }
        final filters =
            uri.queryParameters['filters']
                ?.split(',')
                .where((value) => value.trim().isNotEmpty)
                .map((value) => value.trim())
                .toSet() ??
            const <String>{};
        return DesignStyleSelectionPage(
          sourceType: sourceType,
          queryFilters: filters,
        );
      }
      if (path == AppRoutePaths.designEditor) return const DesignEditorPage();
      if (path == AppRoutePaths.designAi) return const DesignAiPage();
      if (path == AppRoutePaths.designCheck) return const DesignCheckPage();
      if (path == AppRoutePaths.designPreview) return const DesignPreviewPage();
      if (path == AppRoutePaths.designExport) return const DesignExportPage();
      if (path == AppRoutePaths.designVersions) {
        return const DesignVersionsPage();
      }
      if (path == AppRoutePaths.designShare) return const DesignSharePage();
    }

    if (tab == AppTab.shop) {
      if (path == AppRoutePaths.shop) return const ShopHomePage();
      if (path == AppRoutePaths.cart) return const CartPage();
      if (path == AppRoutePaths.checkoutAddress) {
        return const CheckoutAddressPage();
      }
      if (path == AppRoutePaths.checkoutShipping) {
        return const CheckoutShippingPage();
      }
      if (path == AppRoutePaths.checkoutPayment) {
        return const CheckoutPaymentPage();
      }
      if (path == AppRoutePaths.checkoutReview) {
        return const CheckoutReviewPage();
      }
      if (path == AppRoutePaths.checkoutComplete) {
        final orderId = uri.queryParameters['orderId'];
        final orderNumber = uri.queryParameters['orderNumber'];
        return CheckoutCompletePage(orderId: orderId, orderNumber: orderNumber);
      }
      final shopSegments = uri.pathSegments;
      if (shopSegments.length == 2 && shopSegments.first == 'materials') {
        return MaterialDetailPage(materialId: shopSegments[1]);
      }
      if (shopSegments.length == 2 && shopSegments.first == 'products') {
        return ProductDetailPage(productId: shopSegments[1]);
      }
      if (shopSegments.length == 3 &&
          shopSegments.first == 'products' &&
          shopSegments[2] == 'addons') {
        return ProductAddonsPage(productId: shopSegments[1]);
      }
    }

    if (tab == AppTab.orders) {
      if (path == AppRoutePaths.orders) return const OrdersPage();
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments.first == 'orders') {
        final orderId = segments[1];
        if (segments.length == 2) {
          return OrderDetailPage(orderId: orderId);
        }
        if (segments.length == 3) {
          final child = segments[2];
          if (child == 'production') {
            return OrderProductionTimelinePage(orderId: orderId);
          }
          if (child == 'tracking') {
            return OrderTrackingPage(orderId: orderId);
          }
          if (child == 'invoice') {
            return OrderInvoicePage(orderId: orderId);
          }
          if (child == 'reorder') {
            return OrderReorderPage(orderId: orderId);
          }
        }
      }
    }

    if (tab == AppTab.library) {
      if (path == AppRoutePaths.library) return const LibraryListPage();
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments.first == 'library') {
        final designId = segments[1];
        if (segments.length == 2) {
          return LibraryDesignDetailPage(designId: designId);
        }
        if (segments.length == 3) {
          final child = segments[2];
          if (child == 'versions') {
            return LibraryDesignVersionsPage(designId: designId);
          }
          if (child == 'duplicate') {
            return LibraryDesignDuplicatePage(designId: designId);
          }
          if (child == 'export') {
            return LibraryDesignExportPage(designId: designId);
          }
          if (child == 'shares') {
            return LibraryDesignSharesPage(designId: designId);
          }
        }
      }
    }

    if (tab == AppTab.profile) {
      if (path == AppRoutePaths.profile) return const ProfileHomePage();
      if (path == '${AppRoutePaths.profile}/guides') {
        return const GuidesListPage();
      }
      final segments = uri.pathSegments;
      if (segments.length == 3 &&
          segments.first == 'profile' &&
          segments[1] == 'guides') {
        return GuideDetailPage(
          slug: segments[2],
          lang: uri.queryParameters['lang'],
        );
      }
      if (path == '${AppRoutePaths.profile}/kanji/dictionary') {
        final initialQuery = uri.queryParameters['q'];
        final insertField = parseNameFieldParam(
          uri.queryParameters['insertField'],
        );
        final returnTo = uri.queryParameters['returnTo'];
        return KanjiDictionaryPage(
          initialQuery: initialQuery,
          insertField: insertField,
          returnTo: returnTo,
        );
      }
      if (path == '${AppRoutePaths.profile}/howto') return const HowtoPage();
      if (path == AppRoutePaths.profileAddresses) {
        return const ProfileAddressesPage();
      }
      if (path == AppRoutePaths.profilePayments) {
        return const ProfilePaymentsPage();
      }
      if (path == AppRoutePaths.profileNotifications) {
        return const ProfileNotificationsPage();
      }
      if (path == AppRoutePaths.profileLocale) return const ProfileLocalePage();
      if (path == AppRoutePaths.profileLegal) return const ProfileLegalPage();
      if (path == AppRoutePaths.profileSupport) {
        return const ProfileSupportPage();
      }
      if (path == AppRoutePaths.profileLinkedAccounts) {
        return const ProfileLinkedAccountsPage();
      }
      if (path == AppRoutePaths.profileExport) return const ProfileExportPage();
      if (path == AppRoutePaths.profileDelete) return const ProfileDeletePage();
    }

    if (path == AppRoutePaths.supportFaq) return const FaqPage();
    if (path == AppRoutePaths.supportContact) return const SupportContactPage();
    if (path == AppRoutePaths.supportChat) return const SupportChatPage();

    return TabPlaceholderPage(
      title: 'Not found',
      routePath: page.name,
      detail: 'No route matched this path.',
      showBack: true,
    );
  }
}
