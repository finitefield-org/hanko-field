import 'package:app/features/design_creation/data/design_version_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designVersionRepositoryProvider = Provider<DesignVersionRepository>((
  ref,
) {
  return DesignVersionRepository();
});
