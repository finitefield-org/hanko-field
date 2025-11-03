import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/shop/application/shop_home_repository_provider.dart';
import 'package:app/features/shop/domain/shop_home_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShopHomeController extends AsyncNotifier<ShopHomeState> {
  @override
  Future<ShopHomeState> build() => _load();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<ShopHomeState> _load() async {
    final experience = await ref.watch(experienceGateProvider.future);
    final repository = ref.watch(shopHomeRepositoryProvider);

    final categoriesFuture = repository.fetchCategories(experience: experience);
    final promotionsFuture = repository.fetchPromotions(experience: experience);
    final materialsFuture = repository.fetchRecommendedMaterials(
      experience: experience,
    );
    final guidesFuture = repository.fetchGuideLinks(experience: experience);

    final categories = await categoriesFuture;
    final promotions = await promotionsFuture;
    final materials = await materialsFuture;
    final guides = await guidesFuture;

    return ShopHomeState(
      context: ShopHomeContext(experience: experience),
      categories: categories,
      promotions: promotions,
      materials: materials,
      guides: guides,
    );
  }
}

final shopHomeControllerProvider =
    AsyncNotifierProvider<ShopHomeController, ShopHomeState>(
      ShopHomeController.new,
    );
