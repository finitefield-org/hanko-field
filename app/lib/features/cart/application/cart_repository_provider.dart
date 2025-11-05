import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/cart/data/cart_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return FakeCartRepository(cache);
});
