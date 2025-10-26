import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/sample_counter/application/counter_notifier.dart';
import 'package:app/features/sample_counter/data/local_counter_repository.dart';
import 'package:app/features/sample_counter/domain/counter_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterRepositoryProvider = Provider<CounterRepository>((ref) {
  final store = ref.watch(localCacheStoreProvider);
  return LocalCounterRepository(store);
});

final counterProvider = AsyncNotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);
