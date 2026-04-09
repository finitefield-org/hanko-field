import 'dart:async';

import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'config/app_runtime_config.dart';
import '../features/legal/presentation/legal_notice_page.dart';
import '../features/legal/presentation/terms_page.dart';
import '../features/top/presentation/top_page.dart';
import '../features/order/data/order_draft_storage.dart';
import '../features/order/presentation/order_page.dart';
import '../features/order/presentation/order_view_model.dart';
import '../features/payment/presentation/payment_failure_page.dart';
import '../features/payment/presentation/payment_success_page.dart';
import 'localization/app_locale_view_model.dart';
import 'navigation/app_nav_models.dart';
import 'navigation/app_nav_view_model.dart';
import 'theme/hf_theme.dart';

class HankoApp extends StatelessWidget {
  const HankoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STONE SIGNATURE',
      debugShowCheckedModeBanner: false,
      theme: buildHfTheme(),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;

    unawaited(ref.read(orderDraftStorageProvider).pruneExpired());
    ref.invoke(appNavViewModel.popToRoot());
  }

  void _selectLocale(WidgetRef ref, AppLocale locale) {
    ref.invoke(appLocaleViewModel.selectLocale(locale));
    ref.invoke(orderViewModel.selectLocale(locale.code));
  }

  Widget _buildPage(
    BuildContext context,
    WidgetRef ref,
    PageEntry page,
    AppLocale locale,
    bool showConfirmationLinks,
  ) {
    final openLegalNotice = () => ref.invoke(appNavViewModel.showLegalNotice());
    final openTerms = () => ref.invoke(appNavViewModel.showTerms());
    final popTop = () => ref.invoke(appNavViewModel.popTop());
    final popToRoot = () => ref.invoke(appNavViewModel.popToRoot());

    if (page.key == AppPageKey.top) {
      return TopPage(
        locale: locale,
        onSelectLocale: (nextLocale) => _selectLocale(ref, nextLocale),
        onStartDesign: () {
          ref.invoke(appNavViewModel.showDesign());
        },
        onOpenLegalNotice: openLegalNotice,
        onOpenTerms: openTerms,
      );
    }

    if (page.key == AppPageKey.order) {
      return OrderPage(
        locale: locale,
        onSelectLocale: (nextLocale) => _selectLocale(ref, nextLocale),
        onBackToTop: () {
          popToRoot();
        },
        onOpenLegalNotice: openLegalNotice,
        onOpenTerms: openTerms,
        onOpenPaymentSuccess: (sessionId, orderId) {
          ref.invoke(
            appNavViewModel.showPaymentSuccess(
              sessionId: sessionId,
              orderId: orderId,
            ),
          );
        },
        onOpenPaymentFailure: (orderId) {
          ref.invoke(appNavViewModel.showPaymentFailure(orderId: orderId));
        },
        showConfirmationLinks: showConfirmationLinks,
      );
    }

    if (page.key == AppPageKey.legalNotice) {
      return LegalNoticePage(
        locale: locale,
        onSelectLocale: (nextLocale) => _selectLocale(ref, nextLocale),
        onBack: popToRoot,
        onOpenLegalNotice: openLegalNotice,
        onOpenTerms: openTerms,
      );
    }

    if (page.key == AppPageKey.terms) {
      return TermsPage(
        locale: locale,
        onSelectLocale: (nextLocale) => _selectLocale(ref, nextLocale),
        onBack: popToRoot,
        onOpenLegalNotice: openLegalNotice,
        onOpenTerms: openTerms,
      );
    }

    if (page.key.startsWith(AppPageKey.paymentSuccess)) {
      final data = page.data is PaymentPageData
          ? page.data as PaymentPageData
          : null;
      return PaymentSuccessPage(
        locale: locale,
        onSelectLocale: (nextLocale) => _selectLocale(ref, nextLocale),
        orderId: data?.orderId,
        sessionId: data?.sessionId,
        onBackToTop: () {
          popToRoot();
        },
        onOpenLegalNotice: openLegalNotice,
        onOpenTerms: openTerms,
      );
    }

    if (page.key.startsWith(AppPageKey.paymentFailure)) {
      final data = page.data is PaymentPageData
          ? page.data as PaymentPageData
          : null;
      return PaymentFailurePage(
        locale: locale,
        onSelectLocale: (nextLocale) => _selectLocale(ref, nextLocale),
        orderId: data?.orderId,
        onBackToTop: () {
          popToRoot();
        },
        onOpenLegalNotice: openLegalNotice,
        onOpenTerms: openTerms,
      );
    }

    return const Scaffold(body: Center(child: Text('Unknown page')));
  }

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(appNavViewModel);
    final locale = ref.watch(appLocaleViewModel);
    final runtime = ref.watch(appRuntimeConfigProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4EFE6), Color(0xFFF2ECE1)],
        ),
      ),
      child: DeclarativePagesBackScope(
        pages: nav.pages,
        popTopPage: () => ref.invoke(appNavViewModel.popTop()),
        isOverlayVisible: false,
        dismissOverlay: () {},
        onBackAtRoot: () => Navigator.maybePop(context),
        child: DeclarativePagesNavigator(
          pages: nav.pages,
          buildPage: (context, page) => _buildPage(
            context,
            ref,
            page,
            locale,
            runtime.showConfirmationLinks,
          ),
          onPopTop: () => ref.invoke(appNavViewModel.popTop()),
        ),
      ),
    );
  }
}
