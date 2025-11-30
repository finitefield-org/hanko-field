// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:collection/collection.dart';

enum DesignStatus { draft, ready, ordered, locked }

extension DesignStatusX on DesignStatus {
  String toJson() => switch (this) {
    DesignStatus.draft => 'draft',
    DesignStatus.ready => 'ready',
    DesignStatus.ordered => 'ordered',
    DesignStatus.locked => 'locked',
  };

  static DesignStatus fromJson(String value) {
    switch (value) {
      case 'draft':
        return DesignStatus.draft;
      case 'ready':
        return DesignStatus.ready;
      case 'ordered':
        return DesignStatus.ordered;
      case 'locked':
        return DesignStatus.locked;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported design status');
  }
}

enum DesignSourceType { typed, uploaded, logo }

extension DesignSourceTypeX on DesignSourceType {
  String toJson() => switch (this) {
    DesignSourceType.typed => 'typed',
    DesignSourceType.uploaded => 'uploaded',
    DesignSourceType.logo => 'logo',
  };

  static DesignSourceType fromJson(String value) {
    switch (value) {
      case 'typed':
        return DesignSourceType.typed;
      case 'uploaded':
        return DesignSourceType.uploaded;
      case 'logo':
        return DesignSourceType.logo;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported source type');
  }
}

class KanjiMapping {
  const KanjiMapping({this.value, this.mappingRef});

  final String? value;
  final String? mappingRef;

  KanjiMapping copyWith({String? value, String? mappingRef}) {
    return KanjiMapping(
      value: value ?? this.value,
      mappingRef: mappingRef ?? this.mappingRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is KanjiMapping &&
            other.value == value &&
            other.mappingRef == mappingRef);
  }

  @override
  int get hashCode => Object.hash(value, mappingRef);
}

class DesignInput {
  const DesignInput({
    required this.sourceType,
    required this.rawName,
    this.kanji,
  });

  final DesignSourceType sourceType;
  final String rawName;
  final KanjiMapping? kanji;

  DesignInput copyWith({
    DesignSourceType? sourceType,
    String? rawName,
    KanjiMapping? kanji,
  }) {
    return DesignInput(
      sourceType: sourceType ?? this.sourceType,
      rawName: rawName ?? this.rawName,
      kanji: kanji ?? this.kanji,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignInput &&
            other.sourceType == sourceType &&
            other.rawName == rawName &&
            other.kanji == kanji);
  }

  @override
  int get hashCode => Object.hash(sourceType, rawName, kanji);
}

class DesignSize {
  const DesignSize({required this.mm});

  final double mm;

  DesignSize copyWith({double? mm}) => DesignSize(mm: mm ?? this.mm);

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other is DesignSize && other.mm == mm);
  }

  @override
  int get hashCode => mm.hashCode;
}

class StrokeConfig {
  const StrokeConfig({this.weight, this.contrast});

  final double? weight;
  final double? contrast;

  StrokeConfig copyWith({double? weight, double? contrast}) {
    return StrokeConfig(
      weight: weight ?? this.weight,
      contrast: contrast ?? this.contrast,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is StrokeConfig &&
            other.weight == weight &&
            other.contrast == contrast);
  }

  @override
  int get hashCode => Object.hash(weight, contrast);
}

class LayoutConfig {
  const LayoutConfig({this.grid, this.margin});

  final String? grid;
  final double? margin;

  LayoutConfig copyWith({String? grid, double? margin}) {
    return LayoutConfig(grid: grid ?? this.grid, margin: margin ?? this.margin);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is LayoutConfig && other.grid == grid && other.margin == margin);
  }

  @override
  int get hashCode => Object.hash(grid, margin);
}

class DesignStyle {
  const DesignStyle({
    required this.writing,
    this.fontRef,
    this.templateRef,
    this.stroke,
    this.layout,
  });

  final WritingStyle writing;
  final String? fontRef;
  final String? templateRef;
  final StrokeConfig? stroke;
  final LayoutConfig? layout;

  DesignStyle copyWith({
    WritingStyle? writing,
    String? fontRef,
    String? templateRef,
    StrokeConfig? stroke,
    LayoutConfig? layout,
  }) {
    return DesignStyle(
      writing: writing ?? this.writing,
      fontRef: fontRef ?? this.fontRef,
      templateRef: templateRef ?? this.templateRef,
      stroke: stroke ?? this.stroke,
      layout: layout ?? this.layout,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignStyle &&
            other.writing == writing &&
            other.fontRef == fontRef &&
            other.templateRef == templateRef &&
            other.stroke == stroke &&
            other.layout == layout);
  }

  @override
  int get hashCode =>
      Object.hash(writing, fontRef, templateRef, stroke, layout);
}

class AiMetadata {
  const AiMetadata({
    this.enabled,
    this.lastJobRef,
    this.qualityScore,
    this.registrable,
    this.diagnostics = const <String>[],
  });

  final bool? enabled;
  final String? lastJobRef;
  final double? qualityScore;
  final bool? registrable;
  final List<String> diagnostics;

  AiMetadata copyWith({
    bool? enabled,
    String? lastJobRef,
    double? qualityScore,
    bool? registrable,
    List<String>? diagnostics,
  }) {
    return AiMetadata(
      enabled: enabled ?? this.enabled,
      lastJobRef: lastJobRef ?? this.lastJobRef,
      qualityScore: qualityScore ?? this.qualityScore,
      registrable: registrable ?? this.registrable,
      diagnostics: diagnostics ?? this.diagnostics,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is AiMetadata &&
            other.enabled == enabled &&
            other.lastJobRef == lastJobRef &&
            other.qualityScore == qualityScore &&
            other.registrable == registrable &&
            listEq.equals(other.diagnostics, diagnostics));
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    lastJobRef,
    qualityScore,
    registrable,
    const ListEquality<String>().hash(diagnostics),
  );
}

class DesignAssets {
  const DesignAssets({
    this.vectorSvg,
    this.previewPng,
    this.previewPngUrl,
    this.stampMockUrl,
  });

  final String? vectorSvg;
  final String? previewPng;
  final String? previewPngUrl;
  final String? stampMockUrl;

  DesignAssets copyWith({
    String? vectorSvg,
    String? previewPng,
    String? previewPngUrl,
    String? stampMockUrl,
  }) {
    return DesignAssets(
      vectorSvg: vectorSvg ?? this.vectorSvg,
      previewPng: previewPng ?? this.previewPng,
      previewPngUrl: previewPngUrl ?? this.previewPngUrl,
      stampMockUrl: stampMockUrl ?? this.stampMockUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignAssets &&
            other.vectorSvg == vectorSvg &&
            other.previewPng == previewPng &&
            other.previewPngUrl == previewPngUrl &&
            other.stampMockUrl == stampMockUrl);
  }

  @override
  int get hashCode =>
      Object.hash(vectorSvg, previewPng, previewPngUrl, stampMockUrl);
}

class Design {
  const Design({
    required this.status,
    required this.shape,
    required this.size,
    required this.style,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.id,
    this.ownerRef,
    this.input,
    this.ai,
    this.assets,
    this.hash,
    this.lastOrderedAt,
  });

  final String? id;
  final String? ownerRef;
  final DesignStatus status;
  final DesignInput? input;
  final SealShape shape;
  final DesignSize size;
  final DesignStyle style;
  final AiMetadata? ai;
  final DesignAssets? assets;
  final String? hash;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOrderedAt;

  Design copyWith({
    String? id,
    String? ownerRef,
    DesignStatus? status,
    DesignInput? input,
    SealShape? shape,
    DesignSize? size,
    DesignStyle? style,
    AiMetadata? ai,
    DesignAssets? assets,
    String? hash,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOrderedAt,
  }) {
    return Design(
      id: id ?? this.id,
      ownerRef: ownerRef ?? this.ownerRef,
      status: status ?? this.status,
      input: input ?? this.input,
      shape: shape ?? this.shape,
      size: size ?? this.size,
      style: style ?? this.style,
      ai: ai ?? this.ai,
      assets: assets ?? this.assets,
      hash: hash ?? this.hash,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOrderedAt: lastOrderedAt ?? this.lastOrderedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Design &&
            other.id == id &&
            other.ownerRef == ownerRef &&
            other.status == status &&
            other.input == input &&
            other.shape == shape &&
            other.size == size &&
            other.style == style &&
            other.ai == ai &&
            other.assets == assets &&
            other.hash == hash &&
            other.version == version &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.lastOrderedAt == lastOrderedAt);
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerRef,
    status,
    input,
    shape,
    size,
    style,
    ai,
    assets,
    hash,
    version,
    createdAt,
    updatedAt,
    lastOrderedAt,
  );
}

class DesignVersion {
  const DesignVersion({
    required this.version,
    required this.snapshot,
    required this.createdAt,
    required this.createdBy,
    this.id,
    this.changeNote,
  });

  final String? id;
  final int version;
  final Design snapshot;
  final String createdBy;
  final DateTime createdAt;
  final String? changeNote;

  DesignVersion copyWith({
    String? id,
    int? version,
    Design? snapshot,
    String? createdBy,
    DateTime? createdAt,
    String? changeNote,
  }) {
    return DesignVersion(
      id: id ?? this.id,
      version: version ?? this.version,
      snapshot: snapshot ?? this.snapshot,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      changeNote: changeNote ?? this.changeNote,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignVersion &&
            other.id == id &&
            other.version == version &&
            other.snapshot == snapshot &&
            other.createdBy == createdBy &&
            other.createdAt == createdAt &&
            other.changeNote == changeNote);
  }

  @override
  int get hashCode =>
      Object.hash(id, version, snapshot, createdBy, createdAt, changeNote);
}

enum AiSuggestionMethod {
  balance,
  generateCandidates,
  vectorizeUpload,
  registrabilityCheck,
  custom,
}

extension AiSuggestionMethodX on AiSuggestionMethod {
  String toJson() => switch (this) {
    AiSuggestionMethod.balance => 'balance',
    AiSuggestionMethod.generateCandidates => 'generateCandidates',
    AiSuggestionMethod.vectorizeUpload => 'vectorizeUpload',
    AiSuggestionMethod.registrabilityCheck => 'registrabilityCheck',
    AiSuggestionMethod.custom => 'custom',
  };

  static AiSuggestionMethod fromJson(String value) {
    switch (value) {
      case 'balance':
        return AiSuggestionMethod.balance;
      case 'generateCandidates':
        return AiSuggestionMethod.generateCandidates;
      case 'vectorizeUpload':
        return AiSuggestionMethod.vectorizeUpload;
      case 'registrabilityCheck':
        return AiSuggestionMethod.registrabilityCheck;
      case 'custom':
        return AiSuggestionMethod.custom;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported AI method');
  }
}

enum AiSuggestionStatus { proposed, accepted, rejected, applied, expired }

extension AiSuggestionStatusX on AiSuggestionStatus {
  String toJson() => switch (this) {
    AiSuggestionStatus.proposed => 'proposed',
    AiSuggestionStatus.accepted => 'accepted',
    AiSuggestionStatus.rejected => 'rejected',
    AiSuggestionStatus.applied => 'applied',
    AiSuggestionStatus.expired => 'expired',
  };

  static AiSuggestionStatus fromJson(String value) {
    switch (value) {
      case 'proposed':
        return AiSuggestionStatus.proposed;
      case 'accepted':
        return AiSuggestionStatus.accepted;
      case 'rejected':
        return AiSuggestionStatus.rejected;
      case 'applied':
        return AiSuggestionStatus.applied;
      case 'expired':
        return AiSuggestionStatus.expired;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unsupported AI suggestion status',
    );
  }
}

class AiScores {
  const AiScores({
    this.balance,
    this.legibility,
    this.traditionMatch,
    this.styleMatch,
  });

  final double? balance;
  final double? legibility;
  final double? traditionMatch;
  final double? styleMatch;

  AiScores copyWith({
    double? balance,
    double? legibility,
    double? traditionMatch,
    double? styleMatch,
  }) {
    return AiScores(
      balance: balance ?? this.balance,
      legibility: legibility ?? this.legibility,
      traditionMatch: traditionMatch ?? this.traditionMatch,
      styleMatch: styleMatch ?? this.styleMatch,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AiScores &&
            other.balance == balance &&
            other.legibility == legibility &&
            other.traditionMatch == traditionMatch &&
            other.styleMatch == styleMatch);
  }

  @override
  int get hashCode =>
      Object.hash(balance, legibility, traditionMatch, styleMatch);
}

class AiDiagnostic {
  const AiDiagnostic({required this.code, this.severity, this.detail});

  final String code;
  final String? severity;
  final String? detail;

  AiDiagnostic copyWith({String? code, String? severity, String? detail}) {
    return AiDiagnostic(
      code: code ?? this.code,
      severity: severity ?? this.severity,
      detail: detail ?? this.detail,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AiDiagnostic &&
            other.code == code &&
            other.severity == severity &&
            other.detail == detail);
  }

  @override
  int get hashCode => Object.hash(code, severity, detail);
}

class AiSuggestionDelta {
  const AiSuggestionDelta({this.absolute, this.relative, this.jsonPatch});

  final Map<String, Object?>? absolute;
  final Map<String, num>? relative;
  final List<Map<String, Object?>>? jsonPatch;

  AiSuggestionDelta copyWith({
    Map<String, Object?>? absolute,
    Map<String, num>? relative,
    List<Map<String, Object?>>? jsonPatch,
  }) {
    return AiSuggestionDelta(
      absolute: absolute ?? this.absolute,
      relative: relative ?? this.relative,
      jsonPatch: jsonPatch ?? this.jsonPatch,
    );
  }

  @override
  bool operator ==(Object other) {
    const deepEq = DeepCollectionEquality();
    return identical(this, other) ||
        (other is AiSuggestionDelta &&
            deepEq.equals(other.absolute, absolute) &&
            deepEq.equals(other.relative, relative) &&
            deepEq.equals(other.jsonPatch, jsonPatch));
  }

  @override
  int get hashCode {
    const deepEq = DeepCollectionEquality();
    return Object.hash(
      deepEq.hash(absolute),
      deepEq.hash(relative),
      deepEq.hash(jsonPatch),
    );
  }
}

class AiSuggestionPreview {
  const AiSuggestionPreview({
    required this.previewUrl,
    this.diffUrl,
    this.assetRef,
    this.svgUrl,
  });

  final String previewUrl;
  final String? diffUrl;
  final String? assetRef;
  final String? svgUrl;

  AiSuggestionPreview copyWith({
    String? previewUrl,
    String? diffUrl,
    String? assetRef,
    String? svgUrl,
  }) {
    return AiSuggestionPreview(
      previewUrl: previewUrl ?? this.previewUrl,
      diffUrl: diffUrl ?? this.diffUrl,
      assetRef: assetRef ?? this.assetRef,
      svgUrl: svgUrl ?? this.svgUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AiSuggestionPreview &&
            other.previewUrl == previewUrl &&
            other.diffUrl == diffUrl &&
            other.assetRef == assetRef &&
            other.svgUrl == svgUrl);
  }

  @override
  int get hashCode => Object.hash(previewUrl, diffUrl, assetRef, svgUrl);
}

class AiSuggestionResult {
  const AiSuggestionResult({
    this.appliesToHash,
    this.resultHash,
    this.newVersion,
  });

  final String? appliesToHash;
  final String? resultHash;
  final int? newVersion;

  AiSuggestionResult copyWith({
    String? appliesToHash,
    String? resultHash,
    int? newVersion,
  }) {
    return AiSuggestionResult(
      appliesToHash: appliesToHash ?? this.appliesToHash,
      resultHash: resultHash ?? this.resultHash,
      newVersion: newVersion ?? this.newVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AiSuggestionResult &&
            other.appliesToHash == appliesToHash &&
            other.resultHash == resultHash &&
            other.newVersion == newVersion);
  }

  @override
  int get hashCode => Object.hash(appliesToHash, resultHash, newVersion);
}

class AiSuggestion {
  const AiSuggestion({
    required this.jobRef,
    required this.designRef,
    required this.baseVersion,
    required this.baseHash,
    required this.score,
    required this.preview,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.id,
    this.method,
    this.model,
    this.scores,
    this.diagnostics = const <AiDiagnostic>[],
    this.registrability,
    this.tags = const <String>[],
    this.delta,
    this.acceptedAt,
    this.acceptedBy,
    this.rejectionReason,
    this.result,
    this.notes,
    this.updatedAt,
    this.expiresAt,
  });

  final String? id;
  final String jobRef;
  final String designRef;
  final AiSuggestionMethod? method;
  final String? model;
  final int baseVersion;
  final String baseHash;
  final double score;
  final AiScores? scores;
  final List<AiDiagnostic> diagnostics;
  final bool? registrability;
  final List<String> tags;
  final AiSuggestionDelta? delta;
  final AiSuggestionPreview preview;
  final AiSuggestionStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final String? rejectionReason;
  final AiSuggestionResult? result;
  final String? notes;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  AiSuggestion copyWith({
    String? id,
    String? jobRef,
    String? designRef,
    AiSuggestionMethod? method,
    String? model,
    int? baseVersion,
    String? baseHash,
    double? score,
    AiScores? scores,
    List<AiDiagnostic>? diagnostics,
    bool? registrability,
    List<String>? tags,
    AiSuggestionDelta? delta,
    AiSuggestionPreview? preview,
    AiSuggestionStatus? status,
    DateTime? createdAt,
    String? createdBy,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? rejectionReason,
    AiSuggestionResult? result,
    String? notes,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return AiSuggestion(
      id: id ?? this.id,
      jobRef: jobRef ?? this.jobRef,
      designRef: designRef ?? this.designRef,
      method: method ?? this.method,
      model: model ?? this.model,
      baseVersion: baseVersion ?? this.baseVersion,
      baseHash: baseHash ?? this.baseHash,
      score: score ?? this.score,
      scores: scores ?? this.scores,
      diagnostics: diagnostics ?? this.diagnostics,
      registrability: registrability ?? this.registrability,
      tags: tags ?? this.tags,
      delta: delta ?? this.delta,
      preview: preview ?? this.preview,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      result: result ?? this.result,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const diagEq = ListEquality<AiDiagnostic>();
    const tagEq = ListEquality<String>();
    return identical(this, other) ||
        (other is AiSuggestion &&
            other.id == id &&
            other.jobRef == jobRef &&
            other.designRef == designRef &&
            other.method == method &&
            other.model == model &&
            other.baseVersion == baseVersion &&
            other.baseHash == baseHash &&
            other.score == score &&
            other.scores == scores &&
            diagEq.equals(other.diagnostics, diagnostics) &&
            other.registrability == registrability &&
            tagEq.equals(other.tags, tags) &&
            other.delta == delta &&
            other.preview == preview &&
            other.status == status &&
            other.createdAt == createdAt &&
            other.createdBy == createdBy &&
            other.acceptedAt == acceptedAt &&
            other.acceptedBy == acceptedBy &&
            other.rejectionReason == rejectionReason &&
            other.result == result &&
            other.notes == notes &&
            other.updatedAt == updatedAt &&
            other.expiresAt == expiresAt);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    jobRef,
    designRef,
    method,
    model,
    baseVersion,
    baseHash,
    score,
    scores,
    const ListEquality<AiDiagnostic>().hash(diagnostics),
    registrability,
    const ListEquality<String>().hash(tags),
    delta,
    preview,
    status,
    createdAt,
    createdBy,
    acceptedAt,
    acceptedBy,
    rejectionReason,
    result,
    notes,
    updatedAt,
    expiresAt,
  ]);
}
