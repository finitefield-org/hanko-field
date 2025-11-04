import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/shop/application/product_addons_repository_provider.dart';
import 'package:app/features/shop/domain/product_addons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productAddonsProvider = FutureProvider.family<ProductAddons, String>((
  ref,
  productId,
) async {
  final experience = await ref.watch(experienceGateProvider.future);
  final repository = ref.watch(productAddonsRepositoryProvider);
  return repository.fetchAddons(productId: productId, experience: experience);
});
