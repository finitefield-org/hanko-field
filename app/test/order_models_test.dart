import 'package:flutter_test/flutter_test.dart';

import 'package:hankofield/features/order/domain/order_models.dart';

void main() {
  test(
    'stone listings without seal shape restrictions support both shapes',
    () {
      const listing = StoneListingOption(
        key: 'wildcard_01',
        listingCode: 'WLD-0001',
        title: 'Wildcard listing',
        description: '',
        story: '',
        supportedSealShapes: [],
        price: 0,
        photoUrl: '',
        photoAlt: '',
        hasPhoto: false,
      );

      expect(listing.supportsShape(SealShape.square), isTrue);
      expect(listing.supportsShape(SealShape.round), isTrue);
    },
  );
}
