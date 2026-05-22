import 'kanji_candidate.dart';
import 'seal_style_selection.dart';

const sealGenerationMaxAttempts = 3;

class SealGenerationRequest {
  const SealGenerationRequest({
    required this.candidate,
    required this.style,
    this.attemptNumber = 1,
    this.maxAttempts = sealGenerationMaxAttempts,
  }) : assert(attemptNumber >= 1),
       assert(maxAttempts >= 1);

  final KanjiCandidate candidate;
  final SealStyleSelection style;
  final int attemptNumber;
  final int maxAttempts;

  bool get hasReachedLimit => attemptNumber >= maxAttempts;

  SealGenerationRequest nextAttempt() {
    return SealGenerationRequest(
      candidate: candidate,
      style: style,
      attemptNumber: attemptNumber + 1,
      maxAttempts: maxAttempts,
    );
  }
}

typedef SealDesignsGenerator =
    Future<void> Function(SealGenerationRequest request);
