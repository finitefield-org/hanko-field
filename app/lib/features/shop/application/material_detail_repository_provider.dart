import 'package:app/features/shop/data/material_detail_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final materialDetailRepositoryProvider = Provider<MaterialDetailRepository>(
  (ref) => const FakeMaterialDetailRepository(),
);
