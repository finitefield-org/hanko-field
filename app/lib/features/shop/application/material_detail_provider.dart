import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/shop/application/material_detail_repository_provider.dart';
import 'package:app/features/shop/domain/material_detail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final materialDetailProvider = FutureProvider.family<MaterialDetail, String>((
  ref,
  materialId,
) async {
  final experience = await ref.watch(experienceGateProvider.future);
  final repository = ref.watch(materialDetailRepositoryProvider);
  return repository.fetchMaterialDetail(
    materialId: materialId,
    experience: experience,
  );
});
