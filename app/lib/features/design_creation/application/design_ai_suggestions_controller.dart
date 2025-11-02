import 'dart:async';

import 'package:app/features/design_creation/application/ai_suggestion_repository_provider.dart';
import 'package:app/features/design_creation/application/design_ai_suggestions_state.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/data/ai_suggestion_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designAiSuggestionsControllerProvider =
    NotifierProvider<DesignAiSuggestionsController, DesignAiSuggestionsState>(
      DesignAiSuggestionsController.new,
      name: 'designAiSuggestionsControllerProvider',
    );

enum DesignAiActionStatus { success, failure, rateLimited }

class DesignAiActionResult {
  const DesignAiActionResult._(this.status, {this.message, this.retryAfter});

  const DesignAiActionResult.success({String? message})
    : this._(DesignAiActionStatus.success, message: message);

  const DesignAiActionResult.failure({String? message})
    : this._(DesignAiActionStatus.failure, message: message);

  const DesignAiActionResult.rateLimited(Duration retryAfter, {String? message})
    : this._(
        DesignAiActionStatus.rateLimited,
        message: message,
        retryAfter: retryAfter,
      );

  final DesignAiActionStatus status;
  final String? message;
  final Duration? retryAfter;

  bool get isSuccess => status == DesignAiActionStatus.success;
  bool get isRateLimited => status == DesignAiActionStatus.rateLimited;
}

class DesignAiSuggestionsController extends Notifier<DesignAiSuggestionsState> {
  static const _designId = 'draft-ai';
  static const _pollInterval = Duration(seconds: 5);

  Timer? _pollTimer;
  late final DesignAiSuggestionRepository _repository;

  @override
  DesignAiSuggestionsState build() {
    _repository = ref.read(designAiSuggestionRepositoryProvider);
    ref.onDispose(() => _pollTimer?.cancel());
    Future.microtask(() async {
      await _refresh(initial: true);
      if (!ref.mounted) {
        return;
      }
      _startPolling();
    });
    return const DesignAiSuggestionsState(isLoading: true);
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(_refresh());
    });
  }

  Future<void> _refresh({bool initial = false}) async {
    if (!ref.mounted) {
      return;
    }
    if (initial) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final suggestions = await _repository.fetchSuggestions(_designId);
      if (!ref.mounted) {
        return;
      }
      final now = DateTime.now();
      final shouldClearRateLimit =
          state.rateLimitedUntil != null &&
          now.isAfter(state.rateLimitedUntil!);
      state = state.copyWith(
        isLoading: false,
        suggestions: suggestions,
        lastUpdated: now,
        clearError: true,
        clearRateLimit: shouldClearRateLimit,
      );
    } on DesignAiSuggestionException catch (e) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> manualRefresh() => _refresh();

  Future<DesignAiActionResult> requestSuggestions() async {
    if (state.isRequesting) {
      return const DesignAiActionResult.success();
    }
    final remaining = state.rateLimitRemaining(DateTime.now());
    if (remaining != null) {
      return DesignAiActionResult.rateLimited(remaining);
    }
    state = state.copyWith(isRequesting: true, clearError: true);
    try {
      await _repository.requestSuggestions(designId: _designId);
      if (!ref.mounted) {
        return const DesignAiActionResult.success();
      }
      state = state.copyWith(isRequesting: false);
      await _refresh();
      return const DesignAiActionResult.success();
    } on DesignAiSuggestionRateLimitException catch (e) {
      if (!ref.mounted) {
        return DesignAiActionResult.rateLimited(
          e.retryAfter,
          message: e.message,
        );
      }
      state = state.copyWith(
        isRequesting: false,
        rateLimitedUntil: DateTime.now().add(e.retryAfter),
        errorMessage: e.message,
      );
      return DesignAiActionResult.rateLimited(e.retryAfter, message: e.message);
    } on DesignAiSuggestionException catch (e) {
      if (!ref.mounted) {
        return DesignAiActionResult.failure(message: e.message);
      }
      state = state.copyWith(isRequesting: false, errorMessage: e.message);
      return DesignAiActionResult.failure(message: e.message);
    } catch (e) {
      if (!ref.mounted) {
        return DesignAiActionResult.failure(message: e.toString());
      }
      state = state.copyWith(isRequesting: false, errorMessage: e.toString());
      return DesignAiActionResult.failure(message: e.toString());
    }
  }

  Future<DesignAiActionResult> acceptSuggestion(String suggestionId) async {
    if (state.pendingActionIds.contains(suggestionId)) {
      return const DesignAiActionResult.failure();
    }
    final pending = Set<String>.from(state.pendingActionIds)..add(suggestionId);
    state = state.copyWith(pendingActionIds: pending, clearError: true);
    try {
      final updated = await _repository.acceptSuggestion(
        designId: _designId,
        suggestionId: suggestionId,
      );
      if (!ref.mounted) {
        return const DesignAiActionResult.success();
      }
      final current = state.suggestions;
      final merged = current
          .map((item) => item.id == suggestionId ? updated : item)
          .toList(growable: false);
      final pendingAfter = Set<String>.from(state.pendingActionIds)
        ..remove(suggestionId);
      state = state.copyWith(
        suggestions: merged,
        pendingActionIds: pendingAfter,
        clearError: true,
      );
      ref
          .read(designCreationControllerProvider.notifier)
          .setStyleSelection(
            shape: updated.shape,
            writingStyle: updated.style.writing,
            templateRef: updated.style.templateRef ?? updated.id,
            fontRef: updated.style.fontRef,
            previewUrl: updated.proposedPreviewUrl,
            templateTitle: updated.title,
          );
      return const DesignAiActionResult.success();
    } on DesignAiSuggestionException catch (e) {
      if (!ref.mounted) {
        return DesignAiActionResult.failure(message: e.message);
      }
      final pendingAfter = Set<String>.from(state.pendingActionIds)
        ..remove(suggestionId);
      state = state.copyWith(
        pendingActionIds: pendingAfter,
        errorMessage: e.message,
      );
      return DesignAiActionResult.failure(message: e.message);
    } catch (e) {
      if (!ref.mounted) {
        return DesignAiActionResult.failure(message: e.toString());
      }
      final pendingAfter = Set<String>.from(state.pendingActionIds)
        ..remove(suggestionId);
      state = state.copyWith(
        pendingActionIds: pendingAfter,
        errorMessage: e.toString(),
      );
      return DesignAiActionResult.failure(message: e.toString());
    }
  }

  Future<DesignAiActionResult> rejectSuggestion(String suggestionId) async {
    if (state.pendingActionIds.contains(suggestionId)) {
      return const DesignAiActionResult.failure();
    }
    final pending = Set<String>.from(state.pendingActionIds)..add(suggestionId);
    state = state.copyWith(pendingActionIds: pending, clearError: true);
    try {
      final updated = await _repository.rejectSuggestion(
        designId: _designId,
        suggestionId: suggestionId,
      );
      if (!ref.mounted) {
        return const DesignAiActionResult.success();
      }
      final current = state.suggestions;
      final merged = current
          .map((item) => item.id == suggestionId ? updated : item)
          .toList(growable: false);
      final pendingAfter = Set<String>.from(state.pendingActionIds)
        ..remove(suggestionId);
      state = state.copyWith(
        suggestions: merged,
        pendingActionIds: pendingAfter,
        clearError: true,
      );
      return const DesignAiActionResult.success();
    } on DesignAiSuggestionException catch (e) {
      if (!ref.mounted) {
        return DesignAiActionResult.failure(message: e.message);
      }
      final pendingAfter = Set<String>.from(state.pendingActionIds)
        ..remove(suggestionId);
      state = state.copyWith(
        pendingActionIds: pendingAfter,
        errorMessage: e.message,
      );
      return DesignAiActionResult.failure(message: e.message);
    } catch (e) {
      if (!ref.mounted) {
        return DesignAiActionResult.failure(message: e.toString());
      }
      final pendingAfter = Set<String>.from(state.pendingActionIds)
        ..remove(suggestionId);
      state = state.copyWith(
        pendingActionIds: pendingAfter,
        errorMessage: e.toString(),
      );
      return DesignAiActionResult.failure(message: e.toString());
    }
  }

  void setFilter(DesignAiSuggestionFilter filter) {
    if (state.filter == filter) {
      return;
    }
    state = state.copyWith(filter: filter);
  }
}
