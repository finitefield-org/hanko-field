import 'package:app/features/shop/data/shop_home_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shopHomeRepositoryProvider = Provider<ShopHomeRepository>(
  (ref) => const FakeShopHomeRepository(),
);
