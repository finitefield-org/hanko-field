// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

enum AppTab {
  design(
    label: '作成',
    location: AppRoutePaths.design,
    icon: Icons.brush_outlined,
    selectedIcon: Icons.brush,
  ),
  shop(
    label: 'ショップ',
    location: AppRoutePaths.shop,
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront,
  ),
  orders(
    label: '注文',
    location: AppRoutePaths.orders,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  ),
  library(
    label: 'マイ印鑑',
    location: AppRoutePaths.library,
    icon: Icons.collections_bookmark_outlined,
    selectedIcon: Icons.collections_bookmark,
  ),
  profile(
    label: 'プロフィール',
    location: AppRoutePaths.profile,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  );

  const AppTab({
    required this.label,
    required this.location,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String location;
  final IconData icon;
  final IconData selectedIcon;
}

class AppRoutePaths {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const locale = '/locale';
  static const persona = '/persona';
  static const auth = '/auth';

  static const design = '/design';
  static const designNew = '/design/new';
  static const designInput = '/design/input';
  static const designKanjiMap = '/design/input/kanji-map';
  static const designStyle = '/design/style';
  static const designEditor = '/design/editor';
  static const designAi = '/design/ai';
  static const designCheck = '/design/check';
  static const designPreview = '/design/preview';
  static const designExport = '/design/export';
  static const designVersions = '/design/versions';
  static const designShare = '/design/share';
  static const home = '/home';

  static const shop = '/shop';
  static const materialDetail = '/materials/:materialId';
  static const productDetail = '/products/:productId';
  static const productAddons = '/products/:productId/addons';
  static const cart = '/cart';
  static const checkoutAddress = '/checkout/address';
  static const checkoutShipping = '/checkout/shipping';
  static const checkoutPayment = '/checkout/payment';
  static const checkoutReview = '/checkout/review';
  static const checkoutComplete = '/checkout/complete';

  static const orders = '/orders';
  static const orderDetail = '/orders/:orderId';
  static const orderProduction = '/orders/:orderId/production';
  static const orderTracking = '/orders/:orderId/tracking';
  static const orderInvoice = '/orders/:orderId/invoice';
  static const orderReorder = '/orders/:orderId/reorder';

  static const library = '/library';
  static const libraryDetail = '/library/:designId';
  static const libraryVersions = '/library/:designId/versions';
  static const libraryDuplicate = '/library/:designId/duplicate';
  static const libraryExport = '/library/:designId/export';
  static const libraryShares = '/library/:designId/shares';

  static const guides = '/guides';
  static const guideDetail = '/guides/:slug';
  static const kanjiDictionary = '/kanji/dictionary';
  static const howto = '/howto';
  static const profile = '/profile';
  static const profileAddresses = '/profile/addresses';
  static const profilePayments = '/profile/payments';
  static const profileNotifications = '/profile/notifications';
  static const profileLocale = '/profile/locale';
  static const profileLegal = '/profile/legal';
  static const profileSupport = '/profile/support';
  static const profileLinkedAccounts = '/profile/linked-accounts';
  static const profileExport = '/profile/export';
  static const profileDelete = '/profile/delete';

  static const notifications = '/notifications';
  static const search = '/search';
  static const supportFaq = '/support/faq';
  static const supportContact = '/support/contact';
  static const supportChat = '/support/chat';
  static const status = '/status';
  static const permissions = '/permissions';
  static const changelog = '/updates/changelog';
  static const appUpdate = '/app-update';
  static const offline = '/offline';
  static const error = '/error';
}
