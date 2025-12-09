// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/core/model/enums.dart';
import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/designs/data/models/registrability_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class RegistrabilityPayload {
  const RegistrabilityPayload({
    required this.designId,
    required this.displayName,
    required this.writing,
    required this.shape,
    required this.sizeMm,
    this.strokeWeight,
    this.margin,
    this.rotation,
  });

  final String designId;
  final String displayName;
  final WritingStyle writing;
  final SealShape shape;
  final double sizeMm;
  final double? strokeWeight;
  final double? margin;
  final double? rotation;

  Map<String, Object?> toJson() => <String, Object?>{
    'designId': designId,
    'displayName': displayName,
    'writing': writing.toJson(),
    'shape': shape.toJson(),
    'sizeMm': sizeMm,
    'strokeWeight': strokeWeight,
    'margin': margin,
    'rotation': rotation,
  };
}

abstract class RegistrabilityCheckRepository {
  static const fallback = Scope<RegistrabilityCheckRepository>.required(
    'design.registrability.repository',
  );

  Future<RegistrabilityReport> runCheck(RegistrabilityPayload payload);

  Future<RegistrabilityReport?> loadCached(String designId);
}

final registrabilityCheckRepositoryProvider =
    Provider<RegistrabilityCheckRepository>((ref) {
      final cache = ref.watch(designsCacheProvider);
      final gates = ref.watch(appExperienceGatesProvider);
      final logger = Logger('RegistrabilityCheckRepository');
      return LocalRegistrabilityCheckRepository(
        cache: cache,
        gates: gates,
        logger: logger,
      );
    });

class LocalRegistrabilityCheckRepository
    implements RegistrabilityCheckRepository {
  LocalRegistrabilityCheckRepository({
    required LocalCacheStore<JsonMap> cache,
    required AppExperienceGates gates,
    Logger? logger,
  }) : _cache = cache,
       _logger = logger ?? Logger('LocalRegistrabilityCheckRepository'),
       _service = _RegistrabilityService(gates: gates, logger: logger);

  final LocalCacheStore<JsonMap> _cache;
  final Logger _logger;
  final _RegistrabilityService _service;

  @override
  Future<RegistrabilityReport> runCheck(RegistrabilityPayload payload) async {
    final key = LocalCacheKeys.registrabilityCheck(payload.designId);
    final response = await _service.check(payload);

    final report = RegistrabilityReport(
      designId: payload.designId,
      verdict: response.verdict,
      summary: response.summary,
      findings: response.findings,
      guidance: response.guidance,
      checkedAt: DateTime.now(),
      referenceId: response.referenceId,
      latencyMs: response.latencyMs,
      fromCache: false,
      isStale: false,
    );

    unawaited(
      _cache.write(
        key.value,
        report.toJson(),
        policy: CachePolicies.registrability,
        tags: key.tags,
      ),
    );

    return report;
  }

  @override
  Future<RegistrabilityReport?> loadCached(String designId) async {
    final key = LocalCacheKeys.registrabilityCheck(designId);
    try {
      final hit = await _cache.read(
        key.value,
        policy: CachePolicies.registrability,
      );
      if (hit == null) return null;

      final cached = RegistrabilityReport.fromJson(hit.value);
      return cached.copyWith(fromCache: true, isStale: hit.isStale);
    } catch (e, stack) {
      _logger.warning('Failed to load registrability cache', e, stack);
      return null;
    }
  }
}

class _RegistrabilityService {
  _RegistrabilityService({required this.gates, Logger? logger})
    : _logger = logger ?? Logger('_RegistrabilityService');

  final AppExperienceGates gates;
  final Logger _logger;

  Future<_ServiceResponse> check(RegistrabilityPayload payload) async {
    final rng = Random(
      payload.displayName.hashCode ^ payload.designId.hashCode,
    );
    final stopwatch = Stopwatch()..start();

    await Future<void>.delayed(Duration(milliseconds: 420 + rng.nextInt(280)));

    if (rng.nextDouble() < 0.12) {
      _logger.fine('Simulating service outage');
      throw Exception(
        gates.prefersEnglish
            ? 'Registrability service unreachable'
            : '登録可否チェックサービスに接続できません',
      );
    }

    final verdict = _decideVerdict(rng);
    final findings = _buildFindings(rng, payload, verdict);
    final guidance = _guidanceFor(payload, verdict);

    stopwatch.stop();

    return _ServiceResponse(
      verdict: verdict,
      summary: _summaryFor(verdict),
      findings: findings,
      guidance: guidance,
      referenceId:
          'rg-${payload.designId}-${DateTime.now().millisecondsSinceEpoch}',
      latencyMs: stopwatch.elapsedMilliseconds,
    );
  }

  RegistrabilityVerdict _decideVerdict(Random rng) {
    final roll = rng.nextInt(100);
    if (roll < 42) return RegistrabilityVerdict.ok;
    if (roll < 78) return RegistrabilityVerdict.warning;
    return RegistrabilityVerdict.fail;
  }

  List<RegistrabilityFinding> _buildFindings(
    Random rng,
    RegistrabilityPayload payload,
    RegistrabilityVerdict verdict,
  ) {
    final prefersEnglish = gates.prefersEnglish;
    final findings = <RegistrabilityFinding>[];

    if (verdict != RegistrabilityVerdict.ok) {
      findings.add(
        RegistrabilityFinding(
          id: 'similar-mark',
          title: prefersEnglish
              ? 'Similar registered seal detected'
              : '類似する登録印影があります',
          detail: prefersEnglish
              ? 'A prefecture office record shares ${payload.displayName} with similar stroke weight.'
              : '都道府県の登録記録に、同じ氏名で線の太さが近い印影が見つかりました。',
          badge: RegistrabilityBadge.similar,
          severity: RegistrabilitySeverity.caution,
        ),
      );
    }

    if (verdict == RegistrabilityVerdict.fail) {
      findings.add(
        RegistrabilityFinding(
          id: 'conflict',
          title: prefersEnglish
              ? 'Conflict with existing trademark'
              : '既存商標との衝突',
          detail: prefersEnglish
              ? 'Layout matches a registered logo; adjust rotation/margin to avoid rejection.'
              : '版面レイアウトが登録済みのロゴと衝突しています。回転や余白を調整してください。',
          badge: RegistrabilityBadge.conflict,
          severity: RegistrabilitySeverity.critical,
        ),
      );
    }

    findings.add(
      RegistrabilityFinding(
        id: 'glyph-safe',
        title: prefersEnglish ? 'Official glyph set' : '公用字形の使用',
        detail: prefersEnglish
            ? 'Glyphs align with government-approved set for registrations.'
            : '公的登録で推奨される字形セットに準拠しています。',
        badge: RegistrabilityBadge.safe,
        severity: RegistrabilitySeverity.info,
      ),
    );

    if (payload.strokeWeight != null && payload.strokeWeight! > 2.6) {
      findings.add(
        RegistrabilityFinding(
          id: 'stroke-heavy',
          title: prefersEnglish ? 'Stroke weight near limit' : '線の太さが上限に近いです',
          detail: prefersEnglish
              ? 'Heavier strokes may blur on bank paperwork; consider reducing by 5%.'
              : '銀行手続きで滲みやすい太さです。5%ほど細くすると安全です。',
          badge: RegistrabilityBadge.similar,
          severity: RegistrabilitySeverity.caution,
        ),
      );
    }

    return findings;
  }

  List<String> _guidanceFor(
    RegistrabilityPayload payload,
    RegistrabilityVerdict verdict,
  ) {
    final prefersEnglish = gates.prefersEnglish;
    final base = <String>[
      prefersEnglish
          ? 'Keep rotation within ±3° for official filings.'
          : '公的提出では回転角は±3°以内に抑えてください。',
      prefersEnglish
          ? 'Ensure margin of at least 1.2mm to avoid smudging.'
          : '滲み防止のため1.2mm以上の余白を確保してください。',
    ];

    if (payload.margin != null && payload.margin! < 10) {
      base.add(
        prefersEnglish
            ? 'Increase margin slightly; current design is quite dense.'
            : '余白が少ないため、わずかに広げると安心です。',
      );
    }

    if (verdict == RegistrabilityVerdict.fail) {
      base.add(
        prefersEnglish
            ? 'Use a different template or tweak stroke contrast to differentiate.'
            : 'テンプレート変更や線のコントラスト調整で差別化してください。',
      );
    }

    return base;
  }

  String _summaryFor(RegistrabilityVerdict verdict) {
    if (gates.prefersEnglish) {
      switch (verdict) {
        case RegistrabilityVerdict.ok:
          return 'Ready for most official registrations.';
        case RegistrabilityVerdict.warning:
          return 'Minor risks detected. Adjust before submitting.';
        case RegistrabilityVerdict.fail:
          return 'Conflicts detected. Edit the design and re-run.';
      }
    }

    switch (verdict) {
      case RegistrabilityVerdict.ok:
        return '多くの公的手続きでそのまま使えます。';
      case RegistrabilityVerdict.warning:
        return '軽微なリスクがあります。提出前に調整してください。';
      case RegistrabilityVerdict.fail:
        return '衝突が検知されました。修正して再チェックしてください。';
    }
  }
}

class _ServiceResponse {
  const _ServiceResponse({
    required this.verdict,
    required this.summary,
    required this.findings,
    required this.guidance,
    required this.referenceId,
    required this.latencyMs,
  });

  final RegistrabilityVerdict verdict;
  final String summary;
  final List<RegistrabilityFinding> findings;
  final List<String> guidance;
  final String referenceId;
  final int latencyMs;
}
