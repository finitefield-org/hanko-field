import 'package:app/core/model/enums.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/cart/view/cart_page.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/features/checkout/view/checkout_review_page.dart';
import 'package:app/features/checkout/view_model/checkout_review_view_model.dart';
import 'package:app/features/checkout/view_model/checkout_shipping_view_model.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view/design_input_page.dart';
import 'package:app/features/designs/view/design_type_selection_page.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';

import '../test/helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('design creation flow reaches name input', (tester) async {
    const state = DesignCreationState(
      selectedType: DesignSourceType.typed,
      activeFilters: {'personal'},
      storagePermissionGranted: false,
      nameDraft: NameInputDraft(),
      previewStyle: WritingStyle.tensho,
      savedInput: null,
      selectedShape: null,
      selectedSize: null,
      selectedStyle: null,
      selectedTemplate: null,
    );
    final designOverride = Provider<AsyncValue<DesignCreationState>>(
      (_) => const AsyncData<DesignCreationState>(state),
    );

    final router = GoRouter(
      initialLocation: AppRoutePaths.designNew,
      routes: [
        GoRoute(
          path: AppRoutePaths.designNew,
          builder: (_, __) => const DesignTypeSelectionPage(),
        ),
        GoRoute(
          path: AppRoutePaths.designInput,
          builder: (_, __) => const DesignInputPage(),
        ),
      ],
    );

    final overrides = [
      ...buildTestOverrides(),
      designCreationViewModel.overrideWith(designOverride),
    ];

    await tester.pumpWidget(
      buildTestRouterApp(router: router, overrides: overrides),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start with text'));
    await tester.pumpAndSettle();

    expect(find.text('Enter name'), findsOneWidget);
  });

  testWidgets('checkout flow enables place order after terms accepted', (
    tester,
  ) async {
    final cartState = _sampleCartState();
    final reviewState = _sampleCheckoutReviewState(cartState);

    final router = GoRouter(
      initialLocation: AppRoutePaths.cart,
      routes: [
        GoRoute(path: AppRoutePaths.cart, builder: (_, __) => const CartPage()),
        GoRoute(
          path: AppRoutePaths.checkoutAddress,
          builder: (_, __) => const CheckoutReviewPage(),
        ),
      ],
    );

    final AsyncValue<CartState> asyncCartState = AsyncData<CartState>(
      cartState,
    );
    final AsyncValue<CheckoutReviewState> asyncReviewState =
        AsyncData<CheckoutReviewState>(reviewState);
    final overrides = [
      ...buildTestOverrides(),
      cartViewModel.overrideWithValue(asyncCartState),
      checkoutReviewViewModel.overrideWithValue(asyncReviewState),
    ];

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        buildTestRouterApp(router: router, overrides: overrides),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      expect(find.text('Review order'), findsOneWidget);

      final placeOrderButton = find.widgetWithText(TextButton, 'Place order');
      final before = tester.widget<TextButton>(placeOrderButton);
      expect(before.onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      final after = tester.widget<TextButton>(placeOrderButton);
      expect(after.onPressed, isNotNull);
    });
  });
}

CartState _sampleCartState() {
  return const CartState(
    lines: [
      CartLineItem(
        id: 'line-1',
        title: 'Classic seal',
        variantLabel: '15mm • Round',
        thumbnailUrl: 'https://example.com/item.png',
        basePrice: Money(amount: 12000, currency: 'JPY'),
        quantity: 1,
        addonOptions: [],
        selectedAddonIds: {},
        leadTimeMinDays: 2,
        leadTimeMaxDays: 4,
      ),
    ],
    estimate: CartEstimate(
      minDays: 2,
      maxDays: 4,
      methodLabel: 'Standard',
      international: false,
    ),
  );
}

CheckoutReviewState _sampleCheckoutReviewState(CartState cart) {
  return CheckoutReviewState(
    cart: cart,
    isInternational: false,
    address: UserAddress(
      recipient: 'Alex Sato',
      line1: '1-2-3 Ginza',
      city: 'Tokyo',
      postalCode: '100-0000',
      country: 'JP',
      createdAt: DateTime(2024, 1, 1),
    ),
    shipping: ShippingOption(
      id: 'ship-standard',
      label: 'Standard',
      carrier: 'Yamato',
      cost: cart.shipping,
      minDays: 2,
      maxDays: 4,
      international: false,
    ),
    payment: PaymentMethod(
      provider: PaymentProvider.stripe,
      methodType: PaymentMethodType.card,
      providerRef: 'pm_1',
      brand: 'visa',
      last4: '4242',
      expMonth: 12,
      expYear: 2030,
      createdAt: DateTime(2024, 1, 1),
    ),
    shippingCost: cart.shipping,
    tax: cart.tax,
    total: cart.total,
  );
}
