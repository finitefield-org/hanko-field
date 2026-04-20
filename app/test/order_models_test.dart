import 'package:flutter_test/flutter_test.dart';

import 'package:hankofield/features/order/domain/order_models.dart';

void main() {
  test('stone listings use stone shape as the listing shape', () {
    const listing = StoneListingOption(
      key: 'wildcard_01',
      listingCode: 'WLD-0001',
      title: 'Wildcard listing',
      description: '',
      story: '',
      stoneShape: 'square',
      price: 0,
      photoUrl: '',
      photoAlt: '',
      hasPhoto: false,
    );

    expect(listing.supportsShape(SealShape.square), isTrue);
    expect(listing.supportsShape(SealShape.round), isFalse);
  });
}
