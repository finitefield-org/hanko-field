import 'package:flutter_test/flutter_test.dart';

import 'package:hankofield/features/order/domain/order_models.dart';
import 'package:hankofield/features/order/presentation/order_view_model.dart';

OrderScreenState _state({
  required SealShape shape,
  required String selectedStoneListingKey,
}) {
  return OrderScreenState(
    catalog: const CatalogData(
      fonts: [
        FontOption(
          key: 'font_01',
          label: 'Font 01',
          family: 'Font 01',
          kanjiStyle: KanjiStyle.japanese,
        ),
      ],
      stoneListings: [
        StoneListingOption(
          key: 'square_only',
          listingCode: 'SQ-001',
          title: 'Square-only listing',
          description: '',
          story: '',
          stoneShape: 'square',
          price: 1234,
          photoUrl: '',
          photoAlt: '',
          hasPhoto: false,
        ),
        StoneListingOption(
          key: 'round_only',
          listingCode: 'RD-001',
          title: 'Round-only listing',
          description: '',
          story: '',
          stoneShape: 'round',
          price: 2345,
          photoUrl: '',
          photoAlt: '',
          hasPhoto: false,
        ),
      ],
      countries: [CountryOption(code: 'jp', label: 'Japan', shipping: 0)],
    ),
    isLoadingCatalog: false,
    catalogError: '',
    locale: 'en',
    currency: 'JPY',
    step: OrderStep.listing,
    sealLine1: 'AB',
    sealLine2: '',
    sealTextError: '',
    kanjiStyle: KanjiStyle.japanese,
    selectedFontKey: 'font_01',
    shape: shape,
    selectedStoneListingKey: selectedStoneListingKey,
    selectedCountryCode: 'jp',
    realName: 'Taro Yamada',
    candidateGender: CandidateGender.unspecified,
    suggestions: const [],
    selectedSuggestionIndex: null,
    suggestionsError: '',
    isGeneratingSuggestions: false,
    recipientName: 'Taro Yamada',
    email: 'taro@example.com',
    phone: '09000000000',
    postalCode: '1000001',
    stateName: 'Tokyo',
    city: 'Chiyoda',
    addressLine1: '1-1',
    addressLine2: '',
    termsAgreed: true,
    isSubmittingPurchase: false,
    purchaseResult: null,
    purchaseError: '',
  );
}

void main() {
  test('selected listing must stay within the visible shape-filtered set', () {
    final state = _state(
      shape: SealShape.round,
      selectedStoneListingKey: 'square_only',
    );

    expect(state.visibleStoneListings.map((listing) => listing.key), [
      'round_only',
    ]);
    expect(state.selectedStoneListingOrNull, isNull);
    expect(state.subtotal, 0);
    expect(state.purchaseValidationGroups, hasLength(1));
    expect(state.purchaseValidationGroups.single.label, 'Listing');
    expect(
      state.purchaseValidationGroups.single.items.single,
      'No listing is available for the selected shape.',
    );
  });
}
