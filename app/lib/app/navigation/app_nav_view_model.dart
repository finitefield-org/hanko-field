import 'package:declarative_nav/declarative_nav.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'app_nav_models.dart';

class AppNavViewModel extends Provider<AppNavState> {
  AppNavViewModel() : super.args(null);

  @override
  AppNavState build(Ref ref) {
    return const AppNavState(
      pages: [PageEntry(key: AppPageKey.top, name: '/')],
      serial: 0,
    );
  }

  late final showDesignMut = mutation<void>(#showDesign);
  late final showPaymentSuccessMut = mutation<void>(#showPaymentSuccess);
  late final showPaymentFailureMut = mutation<void>(#showPaymentFailure);
  late final popTopMut = mutation<void>(#popTop);
  late final popToRootMut = mutation<void>(#popToRoot);

  Call<void, AppNavState> showDesign() {
    return mutate(showDesignMut, (ref) async {
      final current = ref.watch(this);
      if (current.pages.isNotEmpty &&
          current.pages.last.key == AppPageKey.order) {
        return;
      }

      ref.state = current.copyWith(
        pages: [
          ...current.pages,
          const PageEntry(key: AppPageKey.order, name: '/design'),
        ],
      );
    });
  }

  Call<void, AppNavState> showPaymentSuccess({
    String? sessionId,
    String? orderId,
  }) {
    return mutate(showPaymentSuccessMut, (ref) async {
      final current = ref.watch(this);
      final nextSerial = current.serial + 1;
      ref.state = current.copyWith(
        serial: nextSerial,
        pages: [
          ...current.pages,
          PageEntry(
            key: '${AppPageKey.paymentSuccess}_$nextSerial',
            name: '/payment/success',
            data: PaymentPageData(orderId: orderId, sessionId: sessionId),
          ),
        ],
      );
    });
  }

  Call<void, AppNavState> showPaymentFailure({String? orderId}) {
    return mutate(showPaymentFailureMut, (ref) async {
      final current = ref.watch(this);
      final nextSerial = current.serial + 1;
      ref.state = current.copyWith(
        serial: nextSerial,
        pages: [
          ...current.pages,
          PageEntry(
            key: '${AppPageKey.paymentFailure}_$nextSerial',
            name: '/payment/failure',
            data: PaymentPageData(orderId: orderId),
          ),
        ],
      );
    });
  }

  Call<void, AppNavState> popTop() {
    return mutate(popTopMut, (ref) async {
      final current = ref.watch(this);
      if (current.pages.length <= 1) {
        return;
      }
      ref.state = current.copyWith(
        pages: current.pages.sublist(0, current.pages.length - 1),
      );
    });
  }

  Call<void, AppNavState> popToRoot() {
    return mutate(popToRootMut, (ref) async {
      final current = ref.watch(this);
      if (current.pages.length <= 1) {
        return;
      }
      ref.state = current.copyWith(pages: [current.pages.first]);
    });
  }
}

final appNavViewModel = AppNavViewModel();
