import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/profile/data/legal_documents_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final legalDocumentsRepositoryProvider = Provider<LegalDocumentsRepository>((
  ref,
) {
  final cache = ref.watch(offlineCacheRepositoryProvider);
  return FakeLegalDocumentsRepository(cache: cache);
});
