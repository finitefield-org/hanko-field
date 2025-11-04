import 'package:app/features/shop/data/product_addons_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productAddonsRepositoryProvider = Provider<ProductAddonsRepository>(
  (ref) => const FakeProductAddonsRepository(),
);
