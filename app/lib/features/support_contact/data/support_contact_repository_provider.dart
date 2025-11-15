import 'package:app/features/profile/data/support_center_repository_provider.dart';
import 'package:app/features/support_contact/data/fake_support_contact_repository.dart';
import 'package:app/features/support_contact/data/support_contact_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportContactRepositoryProvider = Provider<SupportContactRepository>((
  ref,
) {
  final supportCenterRepository = ref.read(supportCenterRepositoryProvider);
  return FakeSupportContactRepository(
    supportCenterRepository: supportCenterRepository,
  );
});
