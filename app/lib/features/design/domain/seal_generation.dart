import 'kanji_candidate.dart';
import 'seal_style_selection.dart';

const sealGenerationMaxAttempts = 3;

class SealGenerationRequest {
  const SealGenerationRequest({
    required this.inputName,
    required this.candidate,
    required this.style,
    this.attemptNumber = 1,
    this.maxAttempts = sealGenerationMaxAttempts,
  }) : assert(attemptNumber >= 1),
       assert(maxAttempts >= 1);

  final String inputName;
  final KanjiCandidate candidate;
  final SealStyleSelection style;
  final int attemptNumber;
  final int maxAttempts;

  bool get hasReachedLimit => attemptNumber >= maxAttempts;

  SealGenerationRequest nextAttempt() {
    return SealGenerationRequest(
      inputName: inputName,
      candidate: candidate,
      style: style,
      attemptNumber: attemptNumber + 1,
      maxAttempts: maxAttempts,
    );
  }
}

class SealGenerationResult {
  const SealGenerationResult({
    required this.request,
    required this.requestId,
    required this.variants,
  });

  final SealGenerationRequest request;
  final String requestId;
  final List<SealDesignVariant> variants;
}

class SealDesignVariant {
  const SealDesignVariant({
    required this.id,
    required this.storagePath,
    required this.downloadUrl,
    required this.label,
    required this.width,
    required this.height,
  });

  final String id;
  final String storagePath;
  final String downloadUrl;
  final String label;
  final int width;
  final int height;
}

typedef SealDesignsGenerator =
    Future<SealGenerationResult> Function(SealGenerationRequest request);
