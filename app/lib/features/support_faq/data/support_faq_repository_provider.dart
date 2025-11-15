import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/support_faq/data/fake_support_faq_repository.dart';
import 'package:app/features/support_faq/data/support_faq_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportFaqRepositoryProvider = Provider<SupportFaqRepository>((ref) {
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return FakeSupportFaqRepository(cache: cache);
});
