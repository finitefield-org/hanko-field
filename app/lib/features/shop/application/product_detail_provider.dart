import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/shop/application/product_detail_repository_provider.dart';
import 'package:app/features/shop/domain/product_detail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productDetailProvider = FutureProvider.family<ProductDetail, String>((
  ref,
  productId,
) async {
  final experience = await ref.watch(experienceGateProvider.future);
  final repository = ref.watch(productDetailRepositoryProvider);
  return repository.fetchProductDetail(
    productId: productId,
    experience: experience,
  );
});
