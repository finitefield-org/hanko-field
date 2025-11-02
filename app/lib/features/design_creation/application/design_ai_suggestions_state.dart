import 'package:app/features/design_creation/domain/ai_suggestion.dart';
import 'package:flutter/foundation.dart';

enum DesignAiSuggestionFilter { queued, ready, applied }

@immutable
class DesignAiSuggestionsState {
  const DesignAiSuggestionsState({
    this.isLoading = false,
    this.isRequesting = false,
    this.suggestions = const <DesignAiSuggestion>[],
    this.filter = DesignAiSuggestionFilter.ready,
    this.errorMessage,
    this.rateLimitedUntil,
    this.pendingActionIds = const <String>{},
    this.lastUpdated,
  });

  final bool isLoading;
  final bool isRequesting;
  final List<DesignAiSuggestion> suggestions;
  final DesignAiSuggestionFilter filter;
  final String? errorMessage;
  final DateTime? rateLimitedUntil;
  final Set<String> pendingActionIds;
  final DateTime? lastUpdated;

  List<DesignAiSuggestion> get queuedSuggestions => suggestions
      .where(
        (suggestion) => suggestion.status == DesignAiSuggestionStatus.queued,
      )
      .toList(growable: false);

  List<DesignAiSuggestion> get readySuggestions => suggestions
      .where(
        (suggestion) => suggestion.status == DesignAiSuggestionStatus.ready,
      )
      .toList(growable: false);

  List<DesignAiSuggestion> get appliedSuggestions => suggestions
      .where(
        (suggestion) => suggestion.status == DesignAiSuggestionStatus.applied,
      )
      .toList(growable: false);

  int get queuedCount => queuedSuggestions.length;
  int get readyCount => readySuggestions.length;
  int get appliedCount => appliedSuggestions.length;

  List<DesignAiSuggestion> get visibleSuggestions => switch (filter) {
    DesignAiSuggestionFilter.queued => queuedSuggestions,
    DesignAiSuggestionFilter.ready => readySuggestions,
    DesignAiSuggestionFilter.applied => appliedSuggestions,
  };

  Duration? rateLimitRemaining(DateTime now) {
    if (rateLimitedUntil == null) {
      return null;
    }
    final remaining = rateLimitedUntil!.difference(now);
    if (remaining.isNegative) {
      return null;
    }
    return remaining;
  }

  DesignAiSuggestionsState copyWith({
    bool? isLoading,
    bool? isRequesting,
    List<DesignAiSuggestion>? suggestions,
    DesignAiSuggestionFilter? filter,
    String? errorMessage,
    bool clearError = false,
    DateTime? rateLimitedUntil,
    bool clearRateLimit = false,
    Set<String>? pendingActionIds,
    DateTime? lastUpdated,
  }) {
    return DesignAiSuggestionsState(
      isLoading: isLoading ?? this.isLoading,
      isRequesting: isRequesting ?? this.isRequesting,
      suggestions: suggestions == null
          ? this.suggestions
          : List<DesignAiSuggestion>.unmodifiable(suggestions),
      filter: filter ?? this.filter,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      rateLimitedUntil: clearRateLimit
          ? null
          : rateLimitedUntil ?? this.rateLimitedUntil,
      pendingActionIds: pendingActionIds == null
          ? this.pendingActionIds
          : Set<String>.unmodifiable(pendingActionIds),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignAiSuggestionsState &&
            other.isLoading == isLoading &&
            other.isRequesting == isRequesting &&
            listEquals(other.suggestions, suggestions) &&
            other.filter == filter &&
            other.errorMessage == errorMessage &&
            other.rateLimitedUntil == rateLimitedUntil &&
            setEquals(other.pendingActionIds, pendingActionIds) &&
            other.lastUpdated == lastUpdated);
  }

  @override
  int get hashCode => Object.hash(
    isLoading,
    isRequesting,
    Object.hashAll(suggestions),
    filter,
    errorMessage,
    rateLimitedUntil,
    Object.hashAll(pendingActionIds),
    lastUpdated,
  );
}
