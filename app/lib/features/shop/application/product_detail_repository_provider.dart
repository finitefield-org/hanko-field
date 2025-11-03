import 'package:app/features/shop/data/product_detail_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productDetailRepositoryProvider = Provider<ProductDetailRepository>(
  (ref) => const FakeProductDetailRepository(),
);
