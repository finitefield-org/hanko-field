import 'package:app/core/domain/repositories/design_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/library/data/fake_design_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designRepositoryProvider = Provider<DesignRepository>((ref) {
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return FakeDesignRepository(cache: cache);
});
