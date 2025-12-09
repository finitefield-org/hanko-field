// ignore_for_file: public_member_api_docs

import 'package:collection/collection.dart';

enum RegistrabilityVerdict { ok, warning, fail }

extension RegistrabilityVerdictX on RegistrabilityVerdict {
  String toJson() => switch (this) {
    RegistrabilityVerdict.ok => 'ok',
    RegistrabilityVerdict.warning => 'warning',
    RegistrabilityVerdict.fail => 'fail',
  };

  static RegistrabilityVerdict fromJson(String value) {
    switch (value) {
      case 'ok':
        return RegistrabilityVerdict.ok;
      case 'warning':
        return RegistrabilityVerdict.warning;
      case 'fail':
        return RegistrabilityVerdict.fail;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unsupported registrability verdict',
    );
  }
}

enum RegistrabilityBadge { safe, similar, conflict }

extension RegistrabilityBadgeX on RegistrabilityBadge {
  String toJson() => switch (this) {
    RegistrabilityBadge.safe => 'safe',
    RegistrabilityBadge.similar => 'similar',
    RegistrabilityBadge.conflict => 'conflict',
  };

  static RegistrabilityBadge fromJson(String value) {
    switch (value) {
      case 'safe':
        return RegistrabilityBadge.safe;
      case 'similar':
        return RegistrabilityBadge.similar;
      case 'conflict':
        return RegistrabilityBadge.conflict;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unsupported registrability badge',
    );
  }
}

enum RegistrabilitySeverity { info, caution, critical }

extension RegistrabilitySeverityX on RegistrabilitySeverity {
  String toJson() => switch (this) {
    RegistrabilitySeverity.info => 'info',
    RegistrabilitySeverity.caution => 'caution',
    RegistrabilitySeverity.critical => 'critical',
  };

  static RegistrabilitySeverity fromJson(String value) {
    switch (value) {
      case 'info':
        return RegistrabilitySeverity.info;
      case 'caution':
        return RegistrabilitySeverity.caution;
      case 'critical':
        return RegistrabilitySeverity.critical;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unsupported registrability severity',
    );
  }
}

class RegistrabilityFinding {
  const RegistrabilityFinding({
    required this.id,
    required this.title,
    required this.detail,
    required this.badge,
    required this.severity,
  });

  final String id;
  final String title;
  final String detail;
  final RegistrabilityBadge badge;
  final RegistrabilitySeverity severity;

  RegistrabilityFinding copyWith({
    String? id,
    String? title,
    String? detail,
    RegistrabilityBadge? badge,
    RegistrabilitySeverity? severity,
  }) {
    return RegistrabilityFinding(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      badge: badge ?? this.badge,
      severity: severity ?? this.severity,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'detail': detail,
    'badge': badge.toJson(),
    'severity': severity.toJson(),
  };

  factory RegistrabilityFinding.fromJson(Map<String, Object?> json) {
    return RegistrabilityFinding(
      id: json['id']?.toString() ?? 'unknown',
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      badge: RegistrabilityBadgeX.fromJson(json['badge']?.toString() ?? 'safe'),
      severity: RegistrabilitySeverityX.fromJson(
        json['severity']?.toString() ?? 'info',
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RegistrabilityFinding &&
            other.id == id &&
            other.title == title &&
            other.detail == detail &&
            other.badge == badge &&
            other.severity == severity);
  }

  @override
  int get hashCode => Object.hash(id, title, detail, badge, severity);
}

class RegistrabilityReport {
  const RegistrabilityReport({
    required this.designId,
    required this.verdict,
    required this.summary,
    required this.findings,
    required this.guidance,
    required this.checkedAt,
    this.referenceId,
    this.latencyMs,
    this.fromCache = false,
    this.isStale = false,
  });

  final String designId;
  final RegistrabilityVerdict verdict;
  final String summary;
  final List<RegistrabilityFinding> findings;
  final List<String> guidance;
  final DateTime checkedAt;
  final String? referenceId;
  final int? latencyMs;
  final bool fromCache;
  final bool isStale;

  bool get hasCritical =>
      verdict == RegistrabilityVerdict.fail ||
      findings.any((f) => f.severity == RegistrabilitySeverity.critical);

  RegistrabilityReport copyWith({
    String? designId,
    RegistrabilityVerdict? verdict,
    String? summary,
    List<RegistrabilityFinding>? findings,
    List<String>? guidance,
    DateTime? checkedAt,
    String? referenceId,
    int? latencyMs,
    bool? fromCache,
    bool? isStale,
  }) {
    return RegistrabilityReport(
      designId: designId ?? this.designId,
      verdict: verdict ?? this.verdict,
      summary: summary ?? this.summary,
      findings: findings ?? this.findings,
      guidance: guidance ?? this.guidance,
      checkedAt: checkedAt ?? this.checkedAt,
      referenceId: referenceId ?? this.referenceId,
      latencyMs: latencyMs ?? this.latencyMs,
      fromCache: fromCache ?? this.fromCache,
      isStale: isStale ?? this.isStale,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'designId': designId,
    'verdict': verdict.toJson(),
    'summary': summary,
    'findings': findings.map((f) => f.toJson()).toList(),
    'guidance': guidance,
    'checkedAt': checkedAt.toIso8601String(),
    'referenceId': referenceId,
    'latencyMs': latencyMs,
    'fromCache': fromCache,
    'isStale': isStale,
  };

  factory RegistrabilityReport.fromJson(Map<String, Object?> json) {
    final findingsRaw = json['findings'];
    final guidanceRaw = json['guidance'];

    return RegistrabilityReport(
      designId: json['designId']?.toString() ?? 'draft',
      verdict: RegistrabilityVerdictX.fromJson(
        json['verdict']?.toString() ?? 'warning',
      ),
      summary: json['summary']?.toString() ?? '',
      findings: findingsRaw is List
          ? findingsRaw
                .map(
                  (f) => RegistrabilityFinding.fromJson(
                    Map<String, Object?>.from(f as Map),
                  ),
                )
                .toList()
          : const <RegistrabilityFinding>[],
      guidance: guidanceRaw is List
          ? guidanceRaw.map((g) => g.toString()).toList()
          : const <String>[],
      checkedAt:
          DateTime.tryParse(json['checkedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      referenceId: json['referenceId']?.toString(),
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
      fromCache: json['fromCache'] == true,
      isStale: json['isStale'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    const findingsEq = ListEquality<RegistrabilityFinding>();
    const guidanceEq = ListEquality<String>();
    return identical(this, other) ||
        (other is RegistrabilityReport &&
            other.designId == designId &&
            other.verdict == verdict &&
            other.summary == summary &&
            findingsEq.equals(other.findings, findings) &&
            guidanceEq.equals(other.guidance, guidance) &&
            other.checkedAt == checkedAt &&
            other.referenceId == referenceId &&
            other.latencyMs == latencyMs &&
            other.fromCache == fromCache &&
            other.isStale == isStale);
  }

  @override
  int get hashCode => Object.hashAll([
    designId,
    verdict,
    summary,
    const ListEquality<RegistrabilityFinding>().hash(findings),
    const ListEquality<String>().hash(guidance),
    checkedAt,
    referenceId,
    latencyMs,
    fromCache,
    isStale,
  ]);
}
