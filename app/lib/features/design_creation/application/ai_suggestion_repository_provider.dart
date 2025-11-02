import 'package:app/features/design_creation/data/ai_suggestion_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designAiSuggestionRepositoryProvider =
    Provider<DesignAiSuggestionRepository>((ref) {
      return DesignAiSuggestionRepository();
    });
