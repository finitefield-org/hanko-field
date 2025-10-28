import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/home/data/home_content_repository.dart';
import 'package:app/features/home/domain/home_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeContentRepositoryProvider = Provider<HomeContentRepository>(
  (ref) => const FakeHomeContentRepository(),
);

final homeUsageProvider =
    AsyncNotifierProvider<HomeUsageNotifier, HomeUsageInsights>(
      HomeUsageNotifier.new,
    );

final homeFeaturedItemsProvider =
    AsyncNotifierProvider<HomeFeaturedItemsNotifier, List<HomeFeaturedItem>>(
      HomeFeaturedItemsNotifier.new,
    );

final homeRecentDesignsProvider =
    AsyncNotifierProvider<HomeRecentDesignsNotifier, List<HomeRecentDesign>>(
      HomeRecentDesignsNotifier.new,
    );

final homeTemplateRecommendationsProvider =
    AsyncNotifierProvider<
      HomeTemplateRecommendationsNotifier,
      List<HomeTemplateRecommendation>
    >(HomeTemplateRecommendationsNotifier.new);

class HomeUsageNotifier extends AsyncNotifier<HomeUsageInsights> {
  @override
  Future<HomeUsageInsights> build() async {
    final repository = ref.read(homeContentRepositoryProvider);
    final experience = await ref.watch(experienceGateProvider.future);
    return repository.loadUsageInsights(experience: experience);
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    try {
      final result = await _fetchLatest();
      if (ref.mounted) {
        state = AsyncValue.data(result);
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<HomeUsageInsights> _fetchLatest() async {
    final repository = ref.read(homeContentRepositoryProvider);
    final experience = await ref.read(experienceGateProvider.future);
    return repository.loadUsageInsights(experience: experience);
  }
}

class HomeFeaturedItemsNotifier extends AsyncNotifier<List<HomeFeaturedItem>> {
  @override
  Future<List<HomeFeaturedItem>> build() => _fetch(watchDependencies: true);

  Future<void> reload() async {
    state = const AsyncValue.loading();
    try {
      final result = await _fetch();
      if (ref.mounted) {
        state = AsyncValue.data(result);
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<List<HomeFeaturedItem>> _fetch({
    bool watchDependencies = false,
  }) async {
    final repository = ref.read(homeContentRepositoryProvider);
    final experience = watchDependencies
        ? await ref.watch(experienceGateProvider.future)
        : await ref.read(experienceGateProvider.future);
    final usage = watchDependencies
        ? await ref.watch(homeUsageProvider.future)
        : await ref.read(homeUsageProvider.future);
    return repository.loadFeaturedItems(experience: experience, usage: usage);
  }
}

class HomeRecentDesignsNotifier extends AsyncNotifier<List<HomeRecentDesign>> {
  @override
  Future<List<HomeRecentDesign>> build() => _fetch(watchDependencies: true);

  Future<void> reload() async {
    state = const AsyncValue.loading();
    try {
      final result = await _fetch();
      if (ref.mounted) {
        state = AsyncValue.data(result);
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<List<HomeRecentDesign>> _fetch({
    bool watchDependencies = false,
  }) async {
    final repository = ref.read(homeContentRepositoryProvider);
    final experience = watchDependencies
        ? await ref.watch(experienceGateProvider.future)
        : await ref.read(experienceGateProvider.future);
    final usage = watchDependencies
        ? await ref.watch(homeUsageProvider.future)
        : await ref.read(homeUsageProvider.future);
    return repository.loadRecentDesigns(experience: experience, usage: usage);
  }
}

class HomeTemplateRecommendationsNotifier
    extends AsyncNotifier<List<HomeTemplateRecommendation>> {
  @override
  Future<List<HomeTemplateRecommendation>> build() =>
      _fetch(watchDependencies: true);

  Future<void> reload() async {
    state = const AsyncValue.loading();
    try {
      final result = await _fetch();
      if (ref.mounted) {
        state = AsyncValue.data(result);
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<List<HomeTemplateRecommendation>> _fetch({
    bool watchDependencies = false,
  }) async {
    final repository = ref.read(homeContentRepositoryProvider);
    final experience = watchDependencies
        ? await ref.watch(experienceGateProvider.future)
        : await ref.read(experienceGateProvider.future);
    final usage = watchDependencies
        ? await ref.watch(homeUsageProvider.future)
        : await ref.read(homeUsageProvider.future);
    return repository.loadTemplateRecommendations(
      experience: experience,
      usage: usage,
    );
  }
}
