import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

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
      title: 'Hanko Field',
      debugShowCheckedModeBanner: false,
      theme: buildHfTheme(),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  void _selectLocale(WidgetRef ref, AppLocale locale) {
    ref.invoke(appLocaleViewModel.selectLocale(locale));
    ref.invoke(orderViewModel.selectLocale(locale.code));
  }

  Widget _buildPage(
    BuildContext context,
    WidgetRef ref,
    PageEntry page,
    AppLocale locale,
  ) {
    if (page.key == AppPageKey.order) {
      return OrderPage(
        locale: locale,
        onSelectLocale: (nextLocale) => _selectLocale(ref, nextLocale),
        onOpenPaymentSuccess: (sessionId) {
          ref.invoke(appNavViewModel.showPaymentSuccess(sessionId: sessionId));
        },
        onOpenPaymentFailure: () {
          ref.invoke(appNavViewModel.showPaymentFailure());
        },
      );
    }

    if (page.key.startsWith(AppPageKey.paymentSuccess)) {
      final sessionId = page.data is String ? page.data as String : null;
      return PaymentSuccessPage(
        locale: locale,
        onSelectLocale: (nextLocale) => _selectLocale(ref, nextLocale),
        sessionId: sessionId,
        onBackToTop: () {
          ref.invoke(appNavViewModel.popToRoot());
        },
      );
    }

    if (page.key.startsWith(AppPageKey.paymentFailure)) {
      return PaymentFailurePage(
        locale: locale,
        onSelectLocale: (nextLocale) => _selectLocale(ref, nextLocale),
        onBackToTop: () {
          ref.invoke(appNavViewModel.popToRoot());
        },
      );
    }

    return const Scaffold(body: Center(child: Text('Unknown page')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(appNavViewModel);
    final locale = ref.watch(appLocaleViewModel);
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
          buildPage: (context, page) => _buildPage(context, ref, page, locale),
          onPopTop: () => ref.invoke(appNavViewModel.popTop()),
        ),
      ),
    );
  }
}
