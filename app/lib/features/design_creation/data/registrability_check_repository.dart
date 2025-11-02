import 'dart:async';

import 'package:app/core/storage/cache_policy.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/design_creation/domain/registrability_check.dart';
import 'package:clock/clock.dart' as clock_package;

class RegistrabilityCheckException implements Exception {
  const RegistrabilityCheckException(this.message);

  final String message;

  @override
  String toString() => 'RegistrabilityCheckException($message)';
}

class RegistrabilityCheckRepository {
  RegistrabilityCheckRepository({
    required OfflineCacheRepository cache,
    clock_package.Clock? clock,
  }) : _cache = cache,
       _clock = clock ?? clock_package.clock;

  static const _cacheKey = 'latest';
  static const _networkLatency = Duration(milliseconds: 320);

  final OfflineCacheRepository _cache;
  final clock_package.Clock _clock;

  Future<RegistrabilityCheckResult> runCheck(
    RegistrabilityCheckRequest request,
  ) async {
    await Future<void>.delayed(_networkLatency);

    if (_shouldSimulateFailure(request.displayName)) {
      throw const RegistrabilityCheckException(
        'External verification service is unavailable. Please retry.',
      );
    }

    final now = _clock.now();
    final result = _simulateExternalCheck(request, now);
    final snapshot = RegistrabilityCheckSnapshot(
      result: result,
      designFingerprint: request.fingerprint,
    );
    await _cache.writeRegistrabilityCheck(snapshot, key: _cacheKey);
    return result;
  }

  Future<CacheReadResult<RegistrabilityCheckSnapshot>>
  loadCachedSnapshot() async {
    return _cache.readRegistrabilityCheck(key: _cacheKey);
  }

  bool _shouldSimulateFailure(String displayName) {
    final lowered = displayName.trim().toLowerCase();
    return lowered.contains('error') || lowered.contains('fail-check');
  }

  RegistrabilityCheckResult _simulateExternalCheck(
    RegistrabilityCheckRequest request,
    DateTime timestamp,
  ) {
    final normalizedName = request.displayName.trim();
    final lowered = normalizedName.toLowerCase();
    final details = <RegistrabilityCheckDetail>[];

    var score = 92.0;
    var verdict = RegistrabilityVerdict.safe;
    var summary = 'No conflicts found in official registries.';
    String? guidance;

    details.add(
      const RegistrabilityCheckDetail(
        title: 'Character set',
        description: 'All characters are supported for registry submission.',
        badge: RegistrabilityBadgeType.safe,
      ),
    );

    final hasReservedKeyword =
        lowered.contains('official') ||
        lowered.contains('government') ||
        normalizedName.contains('公');
    if (hasReservedKeyword) {
      verdict = RegistrabilityVerdict.blocked;
      summary = 'Restricted terminology detected in the seal text.';
      guidance =
          'Remove reserved terms like 「公」 or “official” before submission.';
      score -= 55;
      details.add(
        const RegistrabilityCheckDetail(
          title: 'Restricted terms',
          description:
              'Japanese law prohibits using government-related terms in private seals.',
          badge: RegistrabilityBadgeType.conflict,
        ),
      );
    }

    final hasSensitiveGlyph =
        normalizedName.contains('禁') ||
        normalizedName.contains('仮') ||
        lowered.contains('void');
    if (hasSensitiveGlyph) {
      verdict = RegistrabilityVerdict.blocked;
      summary = 'Conflicting glyphs prevent registration.';
      guidance =
          'Replace characters like 「禁」 or 「仮」 with alternatives approved by registry offices.';
      score -= 60;
      details.add(
        const RegistrabilityCheckDetail(
          title: 'Prohibited character',
          description:
              'Detected characters commonly rejected by municipal registrars.',
          badge: RegistrabilityBadgeType.conflict,
        ),
      );
    }

    final isTooGeneric =
        lowered.contains('test') ||
        lowered.contains('sample') ||
        lowered.endsWith('seal');
    if (isTooGeneric && verdict != RegistrabilityVerdict.blocked) {
      verdict = RegistrabilityVerdict.caution;
      summary = 'Potential similarity detected with existing registrations.';
      guidance ??=
          'Add distinctive wording or adjust the writing style to avoid conflicts.';
      score -= 18;
      details.add(
        const RegistrabilityCheckDetail(
          title: 'Common wording',
          description:
              'Registries flag common placeholders like “test” or “sample”.',
          badge: RegistrabilityBadgeType.similar,
        ),
      );
    }

    final tightMargin = request.margin < 2.5;
    if (tightMargin && verdict != RegistrabilityVerdict.blocked) {
      verdict = RegistrabilityVerdict.caution;
      guidance ??=
          'Increase the border margin to improve ink balance and approval odds.';
      score -= 12;
      details.add(
        const RegistrabilityCheckDetail(
          title: 'Narrow border margin',
          description:
              'Registrars prefer at least a 3mm margin to prevent bleeding.',
          badge: RegistrabilityBadgeType.info,
        ),
      );
    }

    final heavyStroke = request.strokeWeight > 7.5;
    if (heavyStroke && verdict != RegistrabilityVerdict.blocked) {
      verdict = RegistrabilityVerdict.caution;
      guidance ??=
          'Reduce stroke weight slightly for better legibility in registry scans.';
      score -= 10;
      details.add(
        const RegistrabilityCheckDetail(
          title: 'Bold stroke width',
          description:
              'Very thick strokes may blur when stamped; lighter strokes test better.',
          badge: RegistrabilityBadgeType.info,
        ),
      );
    }

    if (details.length > 4) {
      details.removeWhere(
        (detail) =>
            detail.badge == RegistrabilityBadgeType.safe && details.length > 4,
      );
    }

    if (score < 0) {
      score = 0;
    } else if (score > 100) {
      score = 100;
    }

    return RegistrabilityCheckResult(
      verdict: verdict,
      summary: summary,
      details: List<RegistrabilityCheckDetail>.unmodifiable(details),
      checkedAt: timestamp,
      guidance: guidance,
      score: double.parse(score.toStringAsFixed(1)),
    );
  }
}
