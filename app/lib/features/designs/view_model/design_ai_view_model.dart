// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum AiSuggestionFilter { queued, ready, applied }

class AiQueueItem {
  const AiQueueItem({
    required this.jobRef,
    required this.method,
    required this.model,
    required this.enqueuedAt,
    required this.readyAt,
  });

  final String jobRef;
  final AiSuggestionMethod method;
  final String model;
  final DateTime enqueuedAt;
  final DateTime readyAt;

  Duration get eta => readyAt.difference(DateTime.now());
}

class AiSuggestionsState {
  const AiSuggestionsState({
    required this.suggestions,
    required this.queue,
    required this.filter,
    required this.queueLength,
    required this.isRequesting,
    required this.isPolling,
    required this.lastUpdatedAt,
    required this.feedbackId,
    this.feedbackMessage,
    this.rateLimitedUntil,
  });

  final List<AiSuggestion> suggestions;
  final List<AiQueueItem> queue;
  final AiSuggestionFilter filter;
  final int queueLength;
  final bool isRequesting;
  final bool isPolling;
  final DateTime? lastUpdatedAt;
  final String? feedbackMessage;
  final int feedbackId;
  final DateTime? rateLimitedUntil;

  AiSuggestionsState copyWith({
    List<AiSuggestion>? suggestions,
    List<AiQueueItem>? queue,
    AiSuggestionFilter? filter,
    int? queueLength,
    bool? isRequesting,
    bool? isPolling,
    DateTime? lastUpdatedAt,
    String? feedbackMessage,
    int? feedbackId,
    DateTime? rateLimitedUntil,
  }) {
    return AiSuggestionsState(
      suggestions: suggestions ?? this.suggestions,
      queue: queue ?? this.queue,
      filter: filter ?? this.filter,
      queueLength: queueLength ?? this.queueLength,
      isRequesting: isRequesting ?? this.isRequesting,
      isPolling: isPolling ?? this.isPolling,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      feedbackId: feedbackId ?? this.feedbackId,
      rateLimitedUntil: rateLimitedUntil ?? this.rateLimitedUntil,
    );
  }
}

class AiSuggestionsViewModel extends AsyncProvider<AiSuggestionsState> {
  AiSuggestionsViewModel() : super.args(null, autoDispose: false);

  late final requestMut = mutation<bool>(#requestSuggestions);
  late final pollMut = mutation<void>(#poll);
  late final acceptMut = mutation<AiSuggestion?>(#acceptSuggestion);
  late final rejectMut = mutation<AiSuggestion?>(#rejectSuggestion);
  late final setFilterMut = mutation<AiSuggestionFilter>(#setFilter);

  final _logger = Logger('AiSuggestionsViewModel');
  late _AiSuggestionDataSource _dataSource;
  late AppExperienceGates _gates;
  Timer? _pollTimer;

  @override
  Future<AiSuggestionsState> build(Ref ref) async {
    ref.onDispose(() => _pollTimer?.cancel());

    _gates = ref.watch(appExperienceGatesProvider);
    _dataSource = _AiSuggestionDataSource(gates: _gates, logger: _logger);
    _schedulePolling(ref);

    final suggestions = await _dataSource.fetch();
    final queue = _dataSource.queueSnapshot();

    return AiSuggestionsState(
      suggestions: suggestions,
      queue: queue,
      filter: queue.isNotEmpty
          ? AiSuggestionFilter.queued
          : AiSuggestionFilter.ready,
      queueLength: queue.length,
      isRequesting: false,
      isPolling: false,
      lastUpdatedAt: DateTime.now(),
      feedbackId: 0,
      feedbackMessage: null,
      rateLimitedUntil: _dataSource.rateLimitedUntil,
    );
  }

  Call<bool> requestSuggestions([
    AiSuggestionMethod method = AiSuggestionMethod.balance,
  ]) => mutate(requestMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      ref.state = AsyncData(
        current.copyWith(isRequesting: true, feedbackMessage: null),
      );
    } else {
      ref.state = const AsyncLoading<AiSuggestionsState>();
    }

    try {
      await _dataSource.enqueue(method: method);
      final queue = _dataSource.queueSnapshot();
      final suggestions = await _dataSource.fetch();
      final base =
          current ??
          AiSuggestionsState(
            suggestions: suggestions,
            queue: queue,
            filter: AiSuggestionFilter.queued,
            queueLength: queue.length,
            isRequesting: false,
            isPolling: false,
            lastUpdatedAt: DateTime.now(),
            feedbackId: 0,
            feedbackMessage: null,
            rateLimitedUntil: _dataSource.rateLimitedUntil,
          );

      ref.state = AsyncData(
        base.copyWith(
          suggestions: suggestions,
          queue: queue,
          queueLength: queue.length,
          isRequesting: false,
          filter: AiSuggestionFilter.queued,
          lastUpdatedAt: DateTime.now(),
          feedbackMessage: _gates.prefersEnglish
              ? 'Requested AI refinement'
              : 'AI提案をリクエストしました',
          feedbackId: (current?.feedbackId ?? 0) + 1,
          rateLimitedUntil: _dataSource.rateLimitedUntil,
        ),
      );
      return true;
    } on _RateLimitException catch (e, stack) {
      _logger.fine('AI suggestion rate limited', e, stack);
      _emitError(ref, e.message, until: e.until);
      return false;
    } catch (e, stack) {
      _logger.warning('Failed to request AI suggestions', e, stack);
      _emitError(
        ref,
        _gates.prefersEnglish
            ? 'Something went wrong. Try again shortly.'
            : 'しばらくしてから再度お試しください。',
      );
      return false;
    }
  }, concurrency: Concurrency.dropLatest);

  Call<void> poll() => mutate(pollMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    if (current.isPolling) return;

    ref.state = AsyncData(current.copyWith(isPolling: true));

    try {
      final suggestions = await _dataSource.fetch();
      final queue = _dataSource.queueSnapshot();
      ref.state = AsyncData(
        current.copyWith(
          suggestions: suggestions,
          queue: queue,
          queueLength: queue.length,
          isPolling: false,
          lastUpdatedAt: DateTime.now(),
          rateLimitedUntil: _dataSource.rateLimitedUntil,
        ),
      );
    } catch (e, stack) {
      _logger.warning('Polling AI suggestions failed', e, stack);
      _emitError(ref, e.toString());
    }
  }, concurrency: Concurrency.restart);

  Call<AiSuggestion?> acceptSuggestion(String suggestionId) =>
      mutate(acceptMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return null;

        try {
          final applied = await _dataSource.accept(suggestionId);
          final updated = current.suggestions
              .map((s) => s.id == applied.id ? applied : s)
              .toList();

          ref.state = AsyncData(
            current.copyWith(
              suggestions: updated,
              filter: AiSuggestionFilter.applied,
              feedbackMessage: _gates.prefersEnglish
                  ? 'Applied AI proposal to draft'
                  : 'AI提案をドラフトに反映しました',
              feedbackId: current.feedbackId + 1,
              lastUpdatedAt: DateTime.now(),
            ),
          );
          return applied;
        } catch (e, stack) {
          _logger.warning('Failed to apply suggestion', e, stack);
          _emitError(
            ref,
            _gates.prefersEnglish
                ? 'Could not apply suggestion'
                : '提案を適用できませんでした',
          );
          return null;
        }
      }, concurrency: Concurrency.dropLatest);

  Call<AiSuggestion?> rejectSuggestion(String suggestionId) =>
      mutate(rejectMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return null;

        try {
          final rejected = await _dataSource.reject(suggestionId);
          final updated = current.suggestions
              .map((s) => s.id == rejected.id ? rejected : s)
              .toList();

          ref.state = AsyncData(
            current.copyWith(
              suggestions: updated,
              filter: AiSuggestionFilter.applied,
              feedbackMessage: _gates.prefersEnglish
                  ? 'Dismissed AI proposal'
                  : 'AI提案を却下しました',
              feedbackId: current.feedbackId + 1,
              lastUpdatedAt: DateTime.now(),
            ),
          );
          return rejected;
        } catch (e, stack) {
          _logger.warning('Failed to reject suggestion', e, stack);
          _emitError(
            ref,
            _gates.prefersEnglish
                ? 'Could not reject suggestion'
                : '提案を却下できませんでした',
          );
          return null;
        }
      }, concurrency: Concurrency.dropLatest);

  Call<AiSuggestionFilter> setFilter(AiSuggestionFilter filter) =>
      mutate(setFilterMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return filter;
        ref.state = AsyncData(current.copyWith(filter: filter));
        return filter;
      }, concurrency: Concurrency.dropLatest);

  void _schedulePolling(Ref ref) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      ref.invoke(poll());
    });
  }

  void _emitError(Ref ref, String message, {DateTime? until}) {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    ref.state = AsyncData(
      current.copyWith(
        feedbackMessage: message,
        feedbackId: current.feedbackId + 1,
        isRequesting: false,
        isPolling: false,
        rateLimitedUntil: until ?? current.rateLimitedUntil,
      ),
    );
  }
}

class _PendingJob {
  const _PendingJob({
    required this.jobRef,
    required this.method,
    required this.model,
    required this.enqueuedAt,
    required this.readyAt,
  });

  final String jobRef;
  final AiSuggestionMethod method;
  final String model;
  final DateTime enqueuedAt;
  final DateTime readyAt;
}

class _AiSuggestionDataSource {
  _AiSuggestionDataSource({required this.gates, Logger? logger})
    : _logger = logger ?? Logger('_AiSuggestionDataSource') {
    _seed();
  }

  final AppExperienceGates gates;
  final Logger _logger;

  final Random _rng = Random(7);
  final List<AiSuggestion> _suggestions = <AiSuggestion>[];
  final List<_PendingJob> _queue = <_PendingJob>[];
  int _baseVersion = 3;
  DateTime? _rateLimitedUntil;

  DateTime? get rateLimitedUntil => _rateLimitedUntil;

  Future<List<AiSuggestion>> fetch() async {
    _completeJobs();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    return _sortedSuggestions();
  }

  List<AiQueueItem> queueSnapshot() {
    _completeJobs();
    return _queue
        .map(
          (job) => AiQueueItem(
            jobRef: job.jobRef,
            method: job.method,
            model: job.model,
            enqueuedAt: job.enqueuedAt,
            readyAt: job.readyAt,
          ),
        )
        .toList();
  }

  Future<_PendingJob> enqueue({
    AiSuggestionMethod method = AiSuggestionMethod.balance,
    String? model,
  }) async {
    _completeJobs();
    final now = DateTime.now();

    if (_rateLimitedUntil != null && now.isBefore(_rateLimitedUntil!)) {
      throw _RateLimitException(
        message: gates.prefersEnglish
            ? 'Too many requests. Please wait a moment.'
            : 'リクエストが多すぎます。少し待ってからお試しください。',
        until: _rateLimitedUntil!,
      );
    }

    _rateLimitedUntil = now.add(const Duration(seconds: 12));

    final job = _PendingJob(
      jobRef: 'job-${now.microsecondsSinceEpoch}',
      method: method,
      model: model ?? 'balance-v2-light',
      enqueuedAt: now,
      readyAt: now.add(Duration(seconds: 5 + _queue.length * 2)),
    );
    _queue.add(job);
    return job;
  }

  Future<AiSuggestion> accept(String suggestionId) async {
    _completeJobs();
    final index = _suggestions.indexWhere((s) => s.id == suggestionId);
    if (index == -1) throw StateError('Unknown suggestion id $suggestionId');
    final current = _suggestions[index];

    final applied = current.copyWith(
      status: AiSuggestionStatus.applied,
      acceptedAt: DateTime.now(),
      acceptedBy: 'current-user',
      result: AiSuggestionResult(
        appliesToHash: current.baseHash,
        resultHash: 'hash-v${_baseVersion + 1}',
        newVersion: _baseVersion + 1,
      ),
      updatedAt: DateTime.now(),
    );
    _baseVersion += 1;
    _suggestions[index] = applied;
    return applied;
  }

  Future<AiSuggestion> reject(String suggestionId) async {
    _completeJobs();
    final index = _suggestions.indexWhere((s) => s.id == suggestionId);
    if (index == -1) throw StateError('Unknown suggestion id $suggestionId');
    final current = _suggestions[index];

    final rejected = current.copyWith(
      status: AiSuggestionStatus.rejected,
      rejectionReason: gates.prefersEnglish ? 'Looks off' : '今回の意図と合わないため',
      updatedAt: DateTime.now(),
    );
    _suggestions[index] = rejected;
    return rejected;
  }

  void _completeJobs() {
    if (_queue.isEmpty) return;
    final now = DateTime.now();
    final ready = _queue.where((job) => !job.readyAt.isAfter(now)).toList();
    if (ready.isEmpty) return;

    for (final job in ready) {
      _queue.remove(job);
      _suggestions.add(_buildSuggestion(job));
    }
    _logger.finer('Completed ${ready.length} AI suggestion jobs');
  }

  List<AiSuggestion> _sortedSuggestions() {
    final sorted = List<AiSuggestion>.of(_suggestions);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  AiSuggestion _buildSuggestion(_PendingJob job) {
    final now = DateTime.now();
    final pair = _previewPair();
    final tags = gates.prefersEnglish
        ? const ['Balance', 'Noise reduction', 'Registrability']
        : const ['バランス補正', 'ノイズ除去', '公的手続き向け'];

    const delta = AiSuggestionDelta(
      absolute: {'strokeWeight': -0.3, 'margin': 1.2},
      relative: {'contrast': 0.08, 'rotation': -2.5},
      jsonPatch: [
        {'op': 'replace', 'path': '/style/stroke/weight', 'value': 2.6},
      ],
    );

    return AiSuggestion(
      id: 's-${job.jobRef}',
      jobRef: job.jobRef,
      designRef: 'design-current',
      method: job.method,
      model: job.model,
      baseVersion: _baseVersion,
      baseHash: 'hash-v$_baseVersion',
      score: 0.74 + _rng.nextDouble() * 0.12,
      scores: AiScores(
        balance: 0.86,
        legibility: 0.71,
        traditionMatch: gates.prefersEnglish ? 0.62 : 0.68,
      ),
      diagnostics: [
        AiDiagnostic(
          code: 'contrast',
          detail: gates.prefersEnglish
              ? 'Raised stroke contrast by 12%'
              : '線のコントラストを12%向上',
        ),
        AiDiagnostic(
          code: 'centerOffset',
          detail: gates.prefersEnglish
              ? 'Re-centered the family name block'
              : '姓のブロック位置を中心に調整',
        ),
      ],
      registrability: true,
      tags: tags,
      delta: delta,
      preview: AiSuggestionPreview(
        previewUrl: pair.$2,
        diffUrl: pair.$1,
        svgUrl: 'https://example.com/svg/${job.jobRef}',
      ),
      status: AiSuggestionStatus.proposed,
      createdAt: now,
      createdBy: 'ai-refiner',
      updatedAt: now,
      expiresAt: now.add(const Duration(hours: 6)),
    );
  }

  (String, String) _previewPair() {
    final pairs = [
      (
        'https://images.unsplash.com/photo-1618004912476-29818d81ae2e?auto=format&fit=crop&w=800&q=60',
        'https://images.unsplash.com/photo-1523419400524-2230bcb00c05?auto=format&fit=crop&w=800&q=60',
      ),
      (
        'https://images.unsplash.com/photo-1508050919630-b135583b29ab?auto=format&fit=crop&w=800&q=60',
        'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=800&q=60',
      ),
      (
        'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?auto=format&fit=crop&w=800&q=60',
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=800&q=60',
      ),
    ];

    return pairs[_rng.nextInt(pairs.length)];
  }

  void _seed() {
    final now = DateTime.now();
    final pair = _previewPair();

    _suggestions.addAll([
      AiSuggestion(
        id: 's-initial-ready',
        jobRef: 'job-initial-ready',
        designRef: 'design-current',
        method: AiSuggestionMethod.balance,
        model: 'balance-v2-light',
        baseVersion: _baseVersion,
        baseHash: 'hash-v$_baseVersion',
        score: 0.81,
        scores: const AiScores(
          balance: 0.88,
          legibility: 0.74,
          styleMatch: 0.69,
        ),
        diagnostics: [
          AiDiagnostic(
            code: 'kerning',
            detail: gates.prefersEnglish ? 'Tightened kerning 6%' : '字間を6%圧縮',
          ),
        ],
        registrability: true,
        tags: gates.prefersEnglish
            ? const ['Balance', 'Seal ready']
            : const ['バランス補正', '印影調整'],
        delta: const AiSuggestionDelta(
          absolute: {'margin': 1.0},
          relative: {'contrast': 0.1},
        ),
        preview: AiSuggestionPreview(
          previewUrl: pair.$2,
          diffUrl: pair.$1,
          svgUrl: 'https://example.com/svg/job-initial-ready',
        ),
        status: AiSuggestionStatus.proposed,
        createdAt: now.subtract(const Duration(minutes: 6)),
        createdBy: 'ai-refiner',
        updatedAt: now.subtract(const Duration(minutes: 2)),
      ),
      AiSuggestion(
        id: 's-applied-latest',
        jobRef: 'job-applied-latest',
        designRef: 'design-current',
        method: AiSuggestionMethod.generateCandidates,
        model: 'candidates-v1',
        baseVersion: _baseVersion,
        baseHash: 'hash-v$_baseVersion',
        score: 0.78,
        scores: const AiScores(
          balance: 0.8,
          legibility: 0.76,
          traditionMatch: 0.7,
        ),
        diagnostics: [
          AiDiagnostic(
            code: 'rotation',
            detail: gates.prefersEnglish
                ? 'Rotation flattened for registrability'
                : '印影の傾きを抑え実印向けに調整',
          ),
        ],
        registrability: true,
        tags: gates.prefersEnglish
            ? const ['Applied', 'Tradition']
            : const ['適用済み', '篆書ベース'],
        delta: const AiSuggestionDelta(absolute: {'rotation': -3.0}),
        preview: AiSuggestionPreview(
          previewUrl: pair.$1,
          diffUrl: pair.$2,
          svgUrl: 'https://example.com/svg/job-applied-latest',
        ),
        status: AiSuggestionStatus.applied,
        createdAt: now.subtract(const Duration(hours: 3)),
        createdBy: 'ai-refiner',
        acceptedAt: now.subtract(const Duration(hours: 2)),
        acceptedBy: 'me',
        result: const AiSuggestionResult(
          appliesToHash: 'hash-v3',
          resultHash: 'hash-v4',
          newVersion: 4,
        ),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);

    _queue.add(
      _PendingJob(
        jobRef: 'job-seeded-queue',
        method: AiSuggestionMethod.registrabilityCheck,
        model: 'reg-check',
        enqueuedAt: now,
        readyAt: now.add(const Duration(seconds: 8)),
      ),
    );
  }
}

class _RateLimitException implements Exception {
  _RateLimitException({required this.message, required this.until});

  final String message;
  final DateTime until;

  @override
  String toString() => message;
}

final designAiViewModel = AiSuggestionsViewModel();
