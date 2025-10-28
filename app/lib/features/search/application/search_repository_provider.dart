import 'package:app/features/search/data/search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => const SearchRepository(),
);
