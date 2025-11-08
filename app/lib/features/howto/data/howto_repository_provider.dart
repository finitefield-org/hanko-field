import 'package:app/features/howto/data/fake_howto_repository.dart';
import 'package:app/features/howto/data/howto_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final howToRepositoryProvider = Provider<HowToRepository>((ref) {
  return const FakeHowToRepository();
});
