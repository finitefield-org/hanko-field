import 'package:app/features/profile/data/linked_accounts_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final linkedAccountsRepositoryProvider = Provider<LinkedAccountsRepository>((
  ref,
) {
  return FakeLinkedAccountsRepository();
});
