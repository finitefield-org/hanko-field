import 'dart:async';

import '../domain/seal_generation.dart';

Future<void> generateSealDesignsWithDefaultApi(
  SealGenerationRequest request,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  throw UnsupportedError('Seal design generation is not connected yet.');
}
