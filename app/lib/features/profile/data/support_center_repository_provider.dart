import 'package:app/features/profile/data/support_center_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportCenterRepositoryProvider = Provider<SupportCenterRepository>((
  ref,
) {
  return FakeSupportCenterRepository();
});
