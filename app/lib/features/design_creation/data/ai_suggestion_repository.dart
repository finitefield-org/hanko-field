import 'dart:async';
import 'dart:math';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/features/design_creation/domain/ai_suggestion.dart';

class DesignAiSuggestionException implements Exception {
  const DesignAiSuggestionException(this.message);

  final String message;

  @override
  String toString() => 'DesignAiSuggestionException($message)';
}

class DesignAiSuggestionRateLimitException extends DesignAiSuggestionException {
  const DesignAiSuggestionRateLimitException({
    required String message,
    required this.retryAfter,
  }) : super(message);

  final Duration retryAfter;
}

class DesignAiSuggestionRepository {
  DesignAiSuggestionRepository();

  static const _minReadyDelay = Duration(seconds: 6);
  static const _maxReadyDelay = Duration(seconds: 14);
  static const _rateLimitWindow = Duration(seconds: 15);

  final _random = Random();
  final Map<String, List<DesignAiSuggestion>> _suggestionsByDesign = {};
  final Map<String, DateTime> _lastRequestAt = {};
  int _jobSeed = 0;
  int _sequence = 0;
  final Map<String, Future<void>> _operationLocks = {};

  Future<String> requestSuggestions({required String designId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    return _runSynchronized(designId, () async {
      final now = DateTime.now();
      final last = _lastRequestAt[designId];
      if (last != null && now.difference(last) < _rateLimitWindow) {
        final retryAfter = _rateLimitWindow - now.difference(last);
        throw DesignAiSuggestionRateLimitException(
          message: 'Rate limited',
          retryAfter: retryAfter,
        );
      }

      final newSuggestions = [
        _generateSuggestion(designId: designId),
        _generateSuggestion(designId: designId),
      ];

      final existing = _suggestionsByDesign.putIfAbsent(
        designId,
        () => <DesignAiSuggestion>[],
      );
      existing.addAll(newSuggestions);
      _lastRequestAt[designId] = now;
      return 'job-$designId-${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}';
    });
  }

  Future<List<DesignAiSuggestion>> fetchSuggestions(String designId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _runSynchronized(designId, () async {
      final entries = _suggestionsByDesign[designId];
      if (entries == null) {
        return const [];
      }

      final now = DateTime.now();
      for (var index = 0; index < entries.length; index++) {
        final suggestion = entries[index];
        if (suggestion.status == DesignAiSuggestionStatus.queued &&
            suggestion.readyAt != null &&
            now.isAfter(suggestion.readyAt!)) {
          entries[index] = suggestion.copyWith(
            status: DesignAiSuggestionStatus.ready,
            completedAt: suggestion.completedAt ?? now,
          );
        }
      }
      entries.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return List<DesignAiSuggestion>.unmodifiable(entries);
    });
  }

  Future<DesignAiSuggestion> acceptSuggestion({
    required String designId,
    required String suggestionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return _runSynchronized(designId, () async {
      final entries = _suggestionsByDesign[designId];
      if (entries == null) {
        throw const DesignAiSuggestionException('Suggestion not found');
      }
      final index = entries.indexWhere((item) => item.id == suggestionId);
      if (index == -1) {
        throw const DesignAiSuggestionException('Suggestion not found');
      }
      final suggestion = entries[index];
      if (suggestion.status != DesignAiSuggestionStatus.ready) {
        throw const DesignAiSuggestionException(
          'Suggestion is not ready to accept',
        );
      }
      final applied = suggestion.copyWith(
        status: DesignAiSuggestionStatus.applied,
        appliedAt: DateTime.now(),
      );
      entries[index] = applied;
      return applied;
    });
  }

  Future<DesignAiSuggestion> rejectSuggestion({
    required String designId,
    required String suggestionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _runSynchronized(designId, () async {
      final entries = _suggestionsByDesign[designId];
      if (entries == null) {
        throw const DesignAiSuggestionException('Suggestion not found');
      }
      final index = entries.indexWhere((item) => item.id == suggestionId);
      if (index == -1) {
        throw const DesignAiSuggestionException('Suggestion not found');
      }
      final suggestion = entries[index];
      final rejected = suggestion.copyWith(
        status: DesignAiSuggestionStatus.rejected,
        completedAt: suggestion.completedAt ?? DateTime.now(),
      );
      entries[index] = rejected;
      return rejected;
    });
  }

  Future<T> _runSynchronized<T>(
    String designId,
    Future<T> Function() operation,
  ) {
    final previous = _operationLocks[designId] ?? Future<void>.value();
    final completer = Completer<void>();
    final queued = previous.whenComplete(() => completer.future);
    _operationLocks[designId] = queued;
    return previous.then((_) => operation()).whenComplete(() {
      completer.complete();
      if (identical(_operationLocks[designId], queued)) {
        _operationLocks.remove(designId);
      }
    });
  }

  DesignAiSuggestion _generateSuggestion({required String designId}) {
    final now = DateTime.now();
    final blueprint = _SuggestionBlueprint
        .samples[_jobSeed % _SuggestionBlueprint.samples.length];
    final suggestionId =
        'aisg-$designId-${_sequence++}-${_random.nextInt(1 << 20)}';
    final jobRef = 'job-$designId-${_jobSeed++}-${now.microsecondsSinceEpoch}';
    final readyDelay =
        _random.nextInt(
          _maxReadyDelay.inSeconds - _minReadyDelay.inSeconds + 1,
        ) +
        _minReadyDelay.inSeconds;
    final readyAt = now.add(Duration(seconds: readyDelay));
    return DesignAiSuggestion(
      id: suggestionId,
      title: blueprint.title,
      summary: blueprint.summary,
      score: blueprint.score,
      tags: blueprint.tags,
      status: DesignAiSuggestionStatus.queued,
      baselinePreviewUrl: blueprint.baselinePreviewUrl,
      proposedPreviewUrl: blueprint.proposedPreviewUrl,
      shape: blueprint.shape,
      style: blueprint.style,
      requestedAt: now,
      readyAt: readyAt,
      jobRef: jobRef,
    );
  }
}

class _SuggestionBlueprint {
  const _SuggestionBlueprint({
    required this.title,
    required this.summary,
    required this.score,
    required this.tags,
    required this.baselinePreviewUrl,
    required this.proposedPreviewUrl,
    required this.shape,
    required this.style,
  });

  final String title;
  final String summary;
  final double score;
  final List<String> tags;
  final String baselinePreviewUrl;
  final String proposedPreviewUrl;
  final DesignShape shape;
  final DesignStyle style;

  static final samples = <_SuggestionBlueprint>[
    _SuggestionBlueprint(
      title: 'Balance outer strokes',
      summary:
          'Strengthens outer strokes and increases margin to avoid ink bleed.',
      score: 0.86,
      tags: ['Balance', 'Legibility'],
      baselinePreviewUrl:
          'https://images.unsplash.com/photo-1503602642458-232111445657?w=640',
      proposedPreviewUrl:
          'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=640',
      shape: DesignShape.round,
      style: DesignStyle(
        writing: DesignWritingStyle.tensho,
        fontRef: 'jp_tensho_classic',
        templateRef: 'tpl_ai_balance_round',
        stroke: const DesignStroke(weight: 2.8),
        layout: const DesignLayout(
          margin: 5.5,
          alignment: DesignCanvasAlignment.center,
          rotation: 0,
          grid: 'classic_grid',
        ),
      ),
    ),
    _SuggestionBlueprint(
      title: 'Sharpen inner curves',
      summary:
          'Refines curved strokes with subtle rotation for improved legibility.',
      score: 0.91,
      tags: ['Precision', 'Legibility'],
      baselinePreviewUrl:
          'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=640',
      proposedPreviewUrl:
          'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=640',
      shape: DesignShape.square,
      style: DesignStyle(
        writing: DesignWritingStyle.reisho,
        fontRef: 'jp_reisho_fine',
        templateRef: 'tpl_ai_curves_square',
        stroke: const DesignStroke(weight: 2.2),
        layout: const DesignLayout(
          margin: 4.0,
          alignment: DesignCanvasAlignment.center,
          rotation: 2,
          grid: 'square_guides',
        ),
      ),
    ),
    _SuggestionBlueprint(
      title: 'Gift-friendly flourish',
      summary:
          'Adds soft baseline flourish and loosens spacing for a gift appeal.',
      score: 0.78,
      tags: ['Gift', 'Expressive'],
      baselinePreviewUrl:
          'https://images.unsplash.com/photo-1448932223592-d1fc686e76ea?w=640',
      proposedPreviewUrl:
          'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=640',
      shape: DesignShape.round,
      style: DesignStyle(
        writing: DesignWritingStyle.gyosho,
        fontRef: 'jp_kana_flow',
        templateRef: 'tpl_ai_gift_round',
        stroke: const DesignStroke(weight: 2.4),
        layout: const DesignLayout(
          margin: 6.0,
          alignment: DesignCanvasAlignment.center,
          rotation: -3,
          grid: 'circular_guides',
        ),
      ),
    ),
  ];
}
