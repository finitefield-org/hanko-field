import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/design_creation/data/registrability_check_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final registrabilityCheckRepositoryProvider =
    Provider<RegistrabilityCheckRepository>((ref) {
      final cache = ref.watch(offlineCacheRepositoryProvider);
      return RegistrabilityCheckRepository(cache: cache);
    });
