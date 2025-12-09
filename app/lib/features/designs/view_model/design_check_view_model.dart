// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/data/models/registrability_models.dart';
import 'package:app/features/designs/data/repositories/registrability_check_repository.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/designs/view_model/design_editor_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class RegistrabilityCheckState {
  const RegistrabilityCheckState({
    required this.report,
    required this.isRefreshing,
    required this.usingCache,
    required this.feedbackId,
    this.feedbackMessage,
  });

  final RegistrabilityReport report;
  final bool isRefreshing;
  final bool usingCache;
  final String? feedbackMessage;
  final int feedbackId;

  RegistrabilityCheckState copyWith({
    RegistrabilityReport? report,
    bool? isRefreshing,
    bool? usingCache,
    String? feedbackMessage,
    int? feedbackId,
  }) {
    return RegistrabilityCheckState(
      report: report ?? this.report,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      usingCache: usingCache ?? this.usingCache,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      feedbackId: feedbackId ?? this.feedbackId,
    );
  }
}

class RegistrabilityCheckViewModel
    extends AsyncProvider<RegistrabilityCheckState> {
  RegistrabilityCheckViewModel() : super.args(null, autoDispose: false);

  late final refreshMut = mutation<RegistrabilityReport?>(#refresh);

  late RegistrabilityCheckRepository _repository;
  late AppExperienceGates _gates;
  final _logger = Logger('RegistrabilityCheckViewModel');
  int _feedbackCounter = 0;

  @override
  Future<RegistrabilityCheckState> build(Ref ref) async {
    _repository = ref.watch(registrabilityCheckRepositoryProvider);
    _gates = ref.watch(appExperienceGatesProvider);

    final payload = _payloadFrom(ref);
    final cached = await _repository.loadCached(payload.designId);

    try {
      final report = await _repository.runCheck(payload);
      return RegistrabilityCheckState(
        report: report,
        isRefreshing: false,
        usingCache: false,
        feedbackId: _feedbackCounter,
      );
    } catch (e, stack) {
      _logger.warning('Initial registrability check failed', e, stack);
      if (cached != null) {
        return RegistrabilityCheckState(
          report: cached,
          isRefreshing: false,
          usingCache: true,
          feedbackId: ++_feedbackCounter,
          feedbackMessage: _gates.prefersEnglish
              ? 'Showing cached result. Re-run when online.'
              : '保存された結果を表示しています。オンラインで再チェックしてください。',
        );
      }
      throw Exception(
        _gates.prefersEnglish
            ? 'Registrability check unavailable'
            : '実印チェックを実行できませんでした',
      );
    }
  }

  Call<RegistrabilityReport?> refresh() => mutate(refreshMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      ref.state = AsyncData(
        current.copyWith(isRefreshing: true, feedbackMessage: null),
      );
    }

    final payload = _payloadFrom(ref);
    final cached = await _repository.loadCached(payload.designId);

    try {
      final report = await _repository.runCheck(payload);
      final base = current ?? _stateFromReport(report);
      ref.state = AsyncData(
        base.copyWith(
          report: report,
          isRefreshing: false,
          usingCache: false,
          feedbackMessage: _gates.prefersEnglish
              ? 'Registrability check updated'
              : 'チェック結果を更新しました',
          feedbackId: ++_feedbackCounter,
        ),
      );
      return report;
    } catch (e, stack) {
      _logger.warning('Failed to refresh registrability check', e, stack);
      if (cached != null) {
        ref.state = AsyncData(
          (current ?? _stateFromReport(cached)).copyWith(
            report: cached,
            isRefreshing: false,
            usingCache: true,
            feedbackMessage: _gates.prefersEnglish
                ? 'Network issue. Showing cached result.'
                : 'ネットワークに接続できません。保存済みの結果を表示します。',
            feedbackId: ++_feedbackCounter,
          ),
        );
        return cached;
      }

      if (current != null) {
        ref.state = AsyncData(
          current.copyWith(
            isRefreshing: false,
            feedbackMessage: e.toString(),
            feedbackId: ++_feedbackCounter,
          ),
        );
        return current.report;
      }

      ref.state = AsyncError<RegistrabilityCheckState>(e, stack);
      return null;
    }
  }, concurrency: Concurrency.dropLatest);

  RegistrabilityPayload _payloadFrom(Ref ref) {
    final creation = ref.watch(designCreationViewModel).valueOrNull;
    final editor = ref.watch(designEditorViewModel).valueOrNull;

    final prefersEnglish = _gates.prefersEnglish;
    final savedRawName = creation?.savedInput?.rawName;
    final name = savedRawName?.trim();
    final fallbackName =
        creation?.nameDraft.fullName(prefersEnglish: prefersEnglish) ??
        (prefersEnglish ? 'Taro Yamada' : '山田太郎');

    final displayName = (name != null && name.isNotEmpty) ? name : fallbackName;

    final writing =
        creation?.selectedStyle?.writing ??
        creation?.previewStyle ??
        WritingStyle.tensho;
    final shape = creation?.selectedShape ?? SealShape.round;
    final size = creation?.selectedSize?.mm ?? 15.0;
    final stroke =
        creation?.selectedStyle?.stroke?.weight ?? editor?.strokeWeight ?? 2.4;
    final margin =
        creation?.selectedStyle?.layout?.margin ?? editor?.margin ?? 12.0;
    final rotation = editor?.rotation ?? 0.0;

    final designId = (savedRawName != null && savedRawName.isNotEmpty)
        ? 'design-${savedRawName.hashCode}'
        : 'design-current';

    return RegistrabilityPayload(
      designId: designId,
      displayName: displayName,
      writing: writing,
      shape: shape,
      sizeMm: size,
      strokeWeight: stroke,
      margin: margin,
      rotation: rotation,
    );
  }

  RegistrabilityCheckState _stateFromReport(RegistrabilityReport report) {
    return RegistrabilityCheckState(
      report: report,
      isRefreshing: false,
      usingCache: report.fromCache,
      feedbackId: _feedbackCounter,
    );
  }
}

final registrabilityCheckViewModel = RegistrabilityCheckViewModel();
