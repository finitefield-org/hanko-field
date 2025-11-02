import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:flutter/foundation.dart';

/// Registrability verdict returned by the external verification service.
enum RegistrabilityVerdict { safe, caution, blocked }

/// Badge that annotates each diagnostic detail.
enum RegistrabilityBadgeType { safe, similar, conflict, info }

@immutable
class RegistrabilityCheckDetail {
  const RegistrabilityCheckDetail({
    required this.title,
    required this.description,
    required this.badge,
  });

  final String title;
  final String description;
  final RegistrabilityBadgeType badge;

  RegistrabilityCheckDetail copyWith({
    String? title,
    String? description,
    RegistrabilityBadgeType? badge,
  }) {
    return RegistrabilityCheckDetail(
      title: title ?? this.title,
      description: description ?? this.description,
      badge: badge ?? this.badge,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'badge': badge.name,
    };
  }

  static RegistrabilityCheckDetail fromJson(Map<String, dynamic> json) {
    return RegistrabilityCheckDetail(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      badge: RegistrabilityBadgeType.values.firstWhere(
        (value) => value.name == json['badge'],
        orElse: () => RegistrabilityBadgeType.info,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RegistrabilityCheckDetail &&
            other.title == title &&
            other.description == description &&
            other.badge == badge);
  }

  @override
  int get hashCode => Object.hash(title, description, badge);
}

@immutable
class RegistrabilityCheckResult {
  const RegistrabilityCheckResult({
    required this.verdict,
    required this.summary,
    required this.details,
    required this.checkedAt,
    this.guidance,
    this.score,
  });

  final RegistrabilityVerdict verdict;
  final String summary;
  final List<RegistrabilityCheckDetail> details;
  final DateTime checkedAt;
  final String? guidance;
  final double? score;

  RegistrabilityCheckResult copyWith({
    RegistrabilityVerdict? verdict,
    String? summary,
    List<RegistrabilityCheckDetail>? details,
    DateTime? checkedAt,
    String? guidance,
    double? score,
  }) {
    return RegistrabilityCheckResult(
      verdict: verdict ?? this.verdict,
      summary: summary ?? this.summary,
      details: details ?? this.details,
      checkedAt: checkedAt ?? this.checkedAt,
      guidance: guidance ?? this.guidance,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'verdict': verdict.name,
      'summary': summary,
      'details': details.map((detail) => detail.toJson()).toList(),
      'checkedAt': checkedAt.toIso8601String(),
      'guidance': guidance,
      'score': score,
    };
  }

  static RegistrabilityCheckResult fromJson(Map<String, dynamic> json) {
    return RegistrabilityCheckResult(
      verdict: RegistrabilityVerdict.values.firstWhere(
        (value) => value.name == json['verdict'],
        orElse: () => RegistrabilityVerdict.safe,
      ),
      summary: json['summary'] as String? ?? '',
      details: (json['details'] as List<dynamic>? ?? const [])
          .map(
            (detail) => RegistrabilityCheckDetail.fromJson(
              Map<String, dynamic>.from(detail as Map),
            ),
          )
          .toList(growable: false),
      checkedAt:
          DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      guidance: json['guidance'] as String?,
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RegistrabilityCheckResult &&
            other.verdict == verdict &&
            other.summary == summary &&
            listEquals(other.details, details) &&
            other.checkedAt == checkedAt &&
            other.guidance == guidance &&
            other.score == score);
  }

  @override
  int get hashCode => Object.hash(
    verdict,
    summary,
    Object.hashAll(details),
    checkedAt,
    guidance,
    score,
  );
}

@immutable
class RegistrabilityCheckSnapshot {
  const RegistrabilityCheckSnapshot({
    required this.result,
    required this.designFingerprint,
  });

  final RegistrabilityCheckResult result;
  final String designFingerprint;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'result': result.toJson(),
      'designFingerprint': designFingerprint,
    };
  }

  static RegistrabilityCheckSnapshot fromJson(Map<String, dynamic> json) {
    return RegistrabilityCheckSnapshot(
      result: RegistrabilityCheckResult.fromJson(
        Map<String, dynamic>.from(json['result'] as Map),
      ),
      designFingerprint: json['designFingerprint'] as String? ?? '',
    );
  }
}

@immutable
class RegistrabilityCheckRequest {
  const RegistrabilityCheckRequest({
    required this.displayName,
    required this.persona,
    required this.shape,
    required this.writingStyle,
    required this.alignment,
    required this.strokeWeight,
    required this.margin,
    required this.grid,
  });

  final String displayName;
  final UserPersona persona;
  final DesignShape shape;
  final DesignWritingStyle writingStyle;
  final DesignCanvasAlignment alignment;
  final double strokeWeight;
  final double margin;
  final String grid;

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'displayName': displayName,
      'persona': persona.name,
      'shape': shape.name,
      'writingStyle': writingStyle.name,
      'alignment': alignment.name,
      'strokeWeight': strokeWeight,
      'margin': margin,
      'grid': grid,
    };
  }

  String get fingerprint {
    final normalizedName = displayName.trim().toLowerCase();
    return [
      normalizedName,
      persona.name,
      shape.name,
      writingStyle.name,
      alignment.name,
      strokeWeight.toStringAsFixed(2),
      margin.toStringAsFixed(2),
      grid,
    ].join('|');
  }
}
