import 'package:app/features/library/data/fake_library_share_link_repository.dart';
import 'package:app/features/library/domain/library_share_link_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final libraryShareLinkRepositoryProvider = Provider<LibraryShareLinkRepository>(
  (ref) {
    return FakeLibraryShareLinkRepository();
  },
);
