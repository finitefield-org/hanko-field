// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/core/utils/json_utils.dart';
import 'package:app/features/designs/data/models/design_models.dart';

class KanjiMappingDto {
  const KanjiMappingDto({this.value, this.mappingRef});

  final String? value;
  final String? mappingRef;

  factory KanjiMappingDto.fromJson(Map<String, Object?> json) {
    return KanjiMappingDto(
      value: json['value'] as String?,
      mappingRef: json['mappingRef'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'value': value,
    'mappingRef': mappingRef,
  };

  KanjiMapping toDomain() {
    return KanjiMapping(value: value, mappingRef: mappingRef);
  }

  static KanjiMappingDto fromDomain(KanjiMapping mapping) {
    return KanjiMappingDto(
      value: mapping.value,
      mappingRef: mapping.mappingRef,
    );
  }
}

class DesignInputDto {
  const DesignInputDto({
    required this.sourceType,
    required this.rawName,
    this.kanji,
  });

  final DesignSourceType sourceType;
  final String rawName;
  final KanjiMappingDto? kanji;

  factory DesignInputDto.fromJson(Map<String, Object?> json) {
    return DesignInputDto(
      sourceType: DesignSourceTypeX.fromJson(json['sourceType'] as String),
      rawName: json['rawName'] as String,
      kanji: json['kanji'] != null
          ? KanjiMappingDto.fromJson(
              Map<String, Object?>.from(json['kanji'] as Map),
            )
          : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'sourceType': sourceType.toJson(),
    'rawName': rawName,
    'kanji': kanji?.toJson(),
  };

  DesignInput toDomain() {
    return DesignInput(
      sourceType: sourceType,
      rawName: rawName,
      kanji: kanji?.toDomain(),
    );
  }

  static DesignInputDto fromDomain(DesignInput input) {
    return DesignInputDto(
      sourceType: input.sourceType,
      rawName: input.rawName,
      kanji: input.kanji != null
          ? KanjiMappingDto.fromDomain(input.kanji!)
          : null,
    );
  }
}

class DesignSizeDto {
  const DesignSizeDto({required this.mm});

  final double mm;

  factory DesignSizeDto.fromJson(Map<String, Object?> json) {
    return DesignSizeDto(mm: (json['mm'] as num).toDouble());
  }

  Map<String, Object?> toJson() => <String, Object?>{'mm': mm};

  DesignSize toDomain() => DesignSize(mm: mm);

  static DesignSizeDto fromDomain(DesignSize size) =>
      DesignSizeDto(mm: size.mm);
}

class StrokeConfigDto {
  const StrokeConfigDto({this.weight, this.contrast});

  final double? weight;
  final double? contrast;

  factory StrokeConfigDto.fromJson(Map<String, Object?> json) {
    return StrokeConfigDto(
      weight: (json['weight'] as num?)?.toDouble(),
      contrast: (json['contrast'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'weight': weight,
    'contrast': contrast,
  };

  StrokeConfig toDomain() => StrokeConfig(weight: weight, contrast: contrast);

  static StrokeConfigDto fromDomain(StrokeConfig stroke) {
    return StrokeConfigDto(weight: stroke.weight, contrast: stroke.contrast);
  }
}

class LayoutConfigDto {
  const LayoutConfigDto({this.grid, this.margin});

  final String? grid;
  final double? margin;

  factory LayoutConfigDto.fromJson(Map<String, Object?> json) {
    return LayoutConfigDto(
      grid: json['grid'] as String?,
      margin: (json['margin'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'grid': grid,
    'margin': margin,
  };

  LayoutConfig toDomain() => LayoutConfig(grid: grid, margin: margin);

  static LayoutConfigDto fromDomain(LayoutConfig layout) {
    return LayoutConfigDto(grid: layout.grid, margin: layout.margin);
  }
}

class DesignStyleDto {
  const DesignStyleDto({
    required this.writing,
    this.fontRef,
    this.templateRef,
    this.stroke,
    this.layout,
  });

  final WritingStyle writing;
  final String? fontRef;
  final String? templateRef;
  final StrokeConfigDto? stroke;
  final LayoutConfigDto? layout;

  factory DesignStyleDto.fromJson(Map<String, Object?> json) {
    return DesignStyleDto(
      writing: WritingStyleX.fromJson(json['writing'] as String),
      fontRef: json['fontRef'] as String?,
      templateRef: json['templateRef'] as String?,
      stroke: json['stroke'] != null
          ? StrokeConfigDto.fromJson(
              Map<String, Object?>.from(json['stroke'] as Map),
            )
          : null,
      layout: json['layout'] != null
          ? LayoutConfigDto.fromJson(
              Map<String, Object?>.from(json['layout'] as Map),
            )
          : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'writing': writing.toJson(),
    'fontRef': fontRef,
    'templateRef': templateRef,
    'stroke': stroke?.toJson(),
    'layout': layout?.toJson(),
  };

  DesignStyle toDomain() {
    return DesignStyle(
      writing: writing,
      fontRef: fontRef,
      templateRef: templateRef,
      stroke: stroke?.toDomain(),
      layout: layout?.toDomain(),
    );
  }

  static DesignStyleDto fromDomain(DesignStyle style) {
    return DesignStyleDto(
      writing: style.writing,
      fontRef: style.fontRef,
      templateRef: style.templateRef,
      stroke: style.stroke != null
          ? StrokeConfigDto.fromDomain(style.stroke!)
          : null,
      layout: style.layout != null
          ? LayoutConfigDto.fromDomain(style.layout!)
          : null,
    );
  }
}

class AiMetadataDto {
  const AiMetadataDto({
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

  factory AiMetadataDto.fromJson(Map<String, Object?> json) {
    return AiMetadataDto(
      enabled: json['enabled'] as bool?,
      lastJobRef: json['lastJobRef'] as String?,
      qualityScore: (json['qualityScore'] as num?)?.toDouble(),
      registrable: json['registrable'] as bool?,
      diagnostics:
          (json['diagnostics'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'lastJobRef': lastJobRef,
    'qualityScore': qualityScore,
    'registrable': registrable,
    'diagnostics': diagnostics,
  };

  AiMetadata toDomain() {
    return AiMetadata(
      enabled: enabled,
      lastJobRef: lastJobRef,
      qualityScore: qualityScore,
      registrable: registrable,
      diagnostics: diagnostics,
    );
  }

  static AiMetadataDto fromDomain(AiMetadata ai) {
    return AiMetadataDto(
      enabled: ai.enabled,
      lastJobRef: ai.lastJobRef,
      qualityScore: ai.qualityScore,
      registrable: ai.registrable,
      diagnostics: ai.diagnostics,
    );
  }
}

class DesignAssetsDto {
  const DesignAssetsDto({
    this.vectorSvg,
    this.previewPng,
    this.previewPngUrl,
    this.stampMockUrl,
  });

  final String? vectorSvg;
  final String? previewPng;
  final String? previewPngUrl;
  final String? stampMockUrl;

  factory DesignAssetsDto.fromJson(Map<String, Object?> json) {
    return DesignAssetsDto(
      vectorSvg: json['vectorSvg'] as String?,
      previewPng: json['previewPng'] as String?,
      previewPngUrl: json['previewPngUrl'] as String?,
      stampMockUrl: json['stampMockUrl'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'vectorSvg': vectorSvg,
    'previewPng': previewPng,
    'previewPngUrl': previewPngUrl,
    'stampMockUrl': stampMockUrl,
  };

  DesignAssets toDomain() {
    return DesignAssets(
      vectorSvg: vectorSvg,
      previewPng: previewPng,
      previewPngUrl: previewPngUrl,
      stampMockUrl: stampMockUrl,
    );
  }

  static DesignAssetsDto fromDomain(DesignAssets assets) {
    return DesignAssetsDto(
      vectorSvg: assets.vectorSvg,
      previewPng: assets.previewPng,
      previewPngUrl: assets.previewPngUrl,
      stampMockUrl: assets.stampMockUrl,
    );
  }
}

class DesignDto {
  const DesignDto({
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
    this.tags = const <String>[],
    this.hash,
    this.lastOrderedAt,
  });

  final String? id;
  final String? ownerRef;
  final DesignStatus status;
  final DesignInputDto? input;
  final SealShape shape;
  final DesignSizeDto size;
  final DesignStyleDto style;
  final AiMetadataDto? ai;
  final DesignAssetsDto? assets;
  final List<String> tags;
  final String? hash;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOrderedAt;

  factory DesignDto.fromJson(Map<String, Object?> json, {String? id}) {
    final inputMap = asMap(json['input']);
    final aiMap = asMap(json['ai']);
    final assetsMap = asMap(json['assets']);

    return DesignDto(
      id: id,
      ownerRef: json['ownerRef'] as String?,
      status: DesignStatusX.fromJson(json['status'] as String),
      input: inputMap != null ? DesignInputDto.fromJson(inputMap) : null,
      shape: SealShapeX.fromJson(json['shape'] as String),
      size: DesignSizeDto.fromJson(
        Map<String, Object?>.from(json['size'] as Map),
      ),
      style: DesignStyleDto.fromJson(
        Map<String, Object?>.from(json['style'] as Map),
      ),
      ai: aiMap != null ? AiMetadataDto.fromJson(aiMap) : null,
      assets: assetsMap != null ? DesignAssetsDto.fromJson(assetsMap) : null,
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      hash: json['hash'] as String?,
      version: (json['version'] as num).toInt(),
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseDateTime(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastOrderedAt: parseDateTime(json['lastOrderedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'ownerRef': ownerRef,
    'status': status.toJson(),
    'input': input?.toJson(),
    'shape': shape.toJson(),
    'size': size.toJson(),
    'style': style.toJson(),
    'ai': ai?.toJson(),
    'assets': assets?.toJson(),
    'tags': tags,
    'hash': hash,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastOrderedAt': lastOrderedAt?.toIso8601String(),
  };

  Design toDomain() {
    return Design(
      id: id,
      ownerRef: ownerRef,
      status: status,
      input: input?.toDomain(),
      shape: shape,
      size: size.toDomain(),
      style: style.toDomain(),
      ai: ai?.toDomain(),
      assets: assets?.toDomain(),
      tags: tags,
      hash: hash,
      version: version,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastOrderedAt: lastOrderedAt,
    );
  }

  static DesignDto fromDomain(Design design) {
    return DesignDto(
      id: design.id,
      ownerRef: design.ownerRef,
      status: design.status,
      input: design.input != null
          ? DesignInputDto.fromDomain(design.input!)
          : null,
      shape: design.shape,
      size: DesignSizeDto.fromDomain(design.size),
      style: DesignStyleDto.fromDomain(design.style),
      ai: design.ai != null ? AiMetadataDto.fromDomain(design.ai!) : null,
      assets: design.assets != null
          ? DesignAssetsDto.fromDomain(design.assets!)
          : null,
      tags: design.tags,
      hash: design.hash,
      version: design.version,
      createdAt: design.createdAt,
      updatedAt: design.updatedAt,
      lastOrderedAt: design.lastOrderedAt,
    );
  }
}

class DesignVersionDto {
  const DesignVersionDto({
    required this.version,
    required this.snapshot,
    required this.createdAt,
    required this.createdBy,
    this.id,
    this.changeNote,
  });

  final String? id;
  final int version;
  final DesignDto snapshot;
  final String createdBy;
  final DateTime createdAt;
  final String? changeNote;

  factory DesignVersionDto.fromJson(Map<String, Object?> json, {String? id}) {
    return DesignVersionDto(
      id: id,
      version: (json['version'] as num).toInt(),
      snapshot: DesignDto.fromJson(
        Map<String, Object?>.from(json['snapshot'] as Map),
      ),
      changeNote: json['changeNote'] as String?,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: json['createdBy'] as String,
      // updatedAt not present in schema
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'snapshot': snapshot.toJson(),
    'changeNote': changeNote,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
  };

  DesignVersion toDomain() {
    return DesignVersion(
      id: id,
      version: version,
      snapshot: snapshot.toDomain(),
      createdBy: createdBy,
      createdAt: createdAt,
      changeNote: changeNote,
    );
  }

  static DesignVersionDto fromDomain(DesignVersion version) {
    return DesignVersionDto(
      id: version.id,
      version: version.version,
      snapshot: DesignDto.fromDomain(version.snapshot),
      createdBy: version.createdBy,
      createdAt: version.createdAt,
      changeNote: version.changeNote,
    );
  }
}

class AiScoresDto {
  const AiScoresDto({
    this.balance,
    this.legibility,
    this.traditionMatch,
    this.styleMatch,
  });

  final double? balance;
  final double? legibility;
  final double? traditionMatch;
  final double? styleMatch;

  factory AiScoresDto.fromJson(Map<String, Object?> json) {
    return AiScoresDto(
      balance: (json['balance'] as num?)?.toDouble(),
      legibility: (json['legibility'] as num?)?.toDouble(),
      traditionMatch: (json['traditionMatch'] as num?)?.toDouble(),
      styleMatch: (json['styleMatch'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'balance': balance,
    'legibility': legibility,
    'traditionMatch': traditionMatch,
    'styleMatch': styleMatch,
  };

  AiScores toDomain() {
    return AiScores(
      balance: balance,
      legibility: legibility,
      traditionMatch: traditionMatch,
      styleMatch: styleMatch,
    );
  }

  static AiScoresDto fromDomain(AiScores scores) {
    return AiScoresDto(
      balance: scores.balance,
      legibility: scores.legibility,
      traditionMatch: scores.traditionMatch,
      styleMatch: scores.styleMatch,
    );
  }
}

class AiDiagnosticDto {
  const AiDiagnosticDto({required this.code, this.severity, this.detail});

  final String code;
  final String? severity;
  final String? detail;

  factory AiDiagnosticDto.fromJson(Map<String, Object?> json) {
    return AiDiagnosticDto(
      code: json['code'] as String,
      severity: json['severity'] as String?,
      detail: json['detail'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'severity': severity,
    'detail': detail,
  };

  AiDiagnostic toDomain() =>
      AiDiagnostic(code: code, severity: severity, detail: detail);

  static AiDiagnosticDto fromDomain(AiDiagnostic diagnostic) {
    return AiDiagnosticDto(
      code: diagnostic.code,
      severity: diagnostic.severity,
      detail: diagnostic.detail,
    );
  }
}

class AiSuggestionDeltaDto {
  const AiSuggestionDeltaDto({this.absolute, this.relative, this.jsonPatch});

  final Map<String, Object?>? absolute;
  final Map<String, num>? relative;
  final List<Map<String, Object?>>? jsonPatch;

  factory AiSuggestionDeltaDto.fromJson(Map<String, Object?> json) {
    return AiSuggestionDeltaDto(
      absolute: json['absolute'] != null
          ? Map<String, Object?>.from(json['absolute'] as Map)
          : null,
      relative: json['relative'] != null
          ? Map<String, num>.from(
              (json['relative'] as Map).map(
                (key, value) => MapEntry(key.toString(), (value as num)),
              ),
            )
          : null,
      jsonPatch: (json['jsonPatch'] as List?)
          ?.map((e) => Map<String, Object?>.from(e as Map))
          .toList(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'absolute': absolute,
    'relative': relative,
    'jsonPatch': jsonPatch,
  };

  AiSuggestionDelta toDomain() {
    return AiSuggestionDelta(
      absolute: absolute,
      relative: relative,
      jsonPatch: jsonPatch,
    );
  }

  static AiSuggestionDeltaDto fromDomain(AiSuggestionDelta delta) {
    return AiSuggestionDeltaDto(
      absolute: delta.absolute,
      relative: delta.relative,
      jsonPatch: delta.jsonPatch,
    );
  }
}

class AiSuggestionPreviewDto {
  const AiSuggestionPreviewDto({
    required this.previewUrl,
    this.diffUrl,
    this.assetRef,
    this.svgUrl,
  });

  final String previewUrl;
  final String? diffUrl;
  final String? assetRef;
  final String? svgUrl;

  factory AiSuggestionPreviewDto.fromJson(Map<String, Object?> json) {
    return AiSuggestionPreviewDto(
      previewUrl: json['previewUrl'] as String,
      diffUrl: json['diffUrl'] as String?,
      assetRef: json['assetRef'] as String?,
      svgUrl: json['svgUrl'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'previewUrl': previewUrl,
    'diffUrl': diffUrl,
    'assetRef': assetRef,
    'svgUrl': svgUrl,
  };

  AiSuggestionPreview toDomain() {
    return AiSuggestionPreview(
      previewUrl: previewUrl,
      diffUrl: diffUrl,
      assetRef: assetRef,
      svgUrl: svgUrl,
    );
  }

  static AiSuggestionPreviewDto fromDomain(AiSuggestionPreview preview) {
    return AiSuggestionPreviewDto(
      previewUrl: preview.previewUrl,
      diffUrl: preview.diffUrl,
      assetRef: preview.assetRef,
      svgUrl: preview.svgUrl,
    );
  }
}

class AiSuggestionResultDto {
  const AiSuggestionResultDto({
    this.appliesToHash,
    this.resultHash,
    this.newVersion,
  });

  final String? appliesToHash;
  final String? resultHash;
  final int? newVersion;

  factory AiSuggestionResultDto.fromJson(Map<String, Object?> json) {
    return AiSuggestionResultDto(
      appliesToHash: json['appliesToHash'] as String?,
      resultHash: json['resultHash'] as String?,
      newVersion: (json['newVersion'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'appliesToHash': appliesToHash,
    'resultHash': resultHash,
    'newVersion': newVersion,
  };

  AiSuggestionResult toDomain() {
    return AiSuggestionResult(
      appliesToHash: appliesToHash,
      resultHash: resultHash,
      newVersion: newVersion,
    );
  }

  static AiSuggestionResultDto fromDomain(AiSuggestionResult result) {
    return AiSuggestionResultDto(
      appliesToHash: result.appliesToHash,
      resultHash: result.resultHash,
      newVersion: result.newVersion,
    );
  }
}

class AiSuggestionDto {
  const AiSuggestionDto({
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
    this.diagnostics = const <AiDiagnosticDto>[],
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
  final AiScoresDto? scores;
  final List<AiDiagnosticDto> diagnostics;
  final bool? registrability;
  final List<String> tags;
  final AiSuggestionDeltaDto? delta;
  final AiSuggestionPreviewDto preview;
  final AiSuggestionStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final String? rejectionReason;
  final AiSuggestionResultDto? result;
  final String? notes;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  factory AiSuggestionDto.fromJson(Map<String, Object?> json, {String? id}) {
    return AiSuggestionDto(
      id: id,
      jobRef: json['jobRef'] as String,
      designRef: json['designRef'] as String,
      method: json['method'] != null
          ? AiSuggestionMethodX.fromJson(json['method'] as String)
          : null,
      model: json['model'] as String?,
      baseVersion: (json['baseVersion'] as num).toInt(),
      baseHash: json['baseHash'] as String,
      score: (json['score'] as num).toDouble(),
      scores: json['scores'] != null
          ? AiScoresDto.fromJson(
              Map<String, Object?>.from(json['scores'] as Map),
            )
          : null,
      diagnostics:
          (json['diagnostics'] as List?)
              ?.map(
                (e) => AiDiagnosticDto.fromJson(
                  Map<String, Object?>.from(e as Map),
                ),
              )
              .toList() ??
          const <AiDiagnosticDto>[],
      registrability: json['registrability'] as bool?,
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      delta: json['delta'] != null
          ? AiSuggestionDeltaDto.fromJson(
              Map<String, Object?>.from(json['delta'] as Map),
            )
          : null,
      preview: AiSuggestionPreviewDto.fromJson(
        Map<String, Object?>.from(json['preview'] as Map),
      ),
      status: AiSuggestionStatusX.fromJson(json['status'] as String),
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: json['createdBy'] as String,
      acceptedAt: parseDateTime(json['acceptedAt']),
      acceptedBy: json['acceptedBy'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      result: json['result'] != null
          ? AiSuggestionResultDto.fromJson(
              Map<String, Object?>.from(json['result'] as Map),
            )
          : null,
      notes: json['notes'] as String?,
      updatedAt: parseDateTime(json['updatedAt']),
      expiresAt: parseDateTime(json['expiresAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'jobRef': jobRef,
    'designRef': designRef,
    'method': method?.toJson(),
    'model': model,
    'baseVersion': baseVersion,
    'baseHash': baseHash,
    'score': score,
    'scores': scores?.toJson(),
    'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
    'registrability': registrability,
    'tags': tags,
    'delta': delta?.toJson(),
    'preview': preview.toJson(),
    'status': status.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
    'acceptedAt': acceptedAt?.toIso8601String(),
    'acceptedBy': acceptedBy,
    'rejectionReason': rejectionReason,
    'result': result?.toJson(),
    'notes': notes,
    'updatedAt': updatedAt?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
  };

  AiSuggestion toDomain() {
    return AiSuggestion(
      id: id,
      jobRef: jobRef,
      designRef: designRef,
      method: method,
      model: model,
      baseVersion: baseVersion,
      baseHash: baseHash,
      score: score,
      scores: scores?.toDomain(),
      diagnostics: diagnostics.map((d) => d.toDomain()).toList(),
      registrability: registrability,
      tags: tags,
      delta: delta?.toDomain(),
      preview: preview.toDomain(),
      status: status,
      createdAt: createdAt,
      createdBy: createdBy,
      acceptedAt: acceptedAt,
      acceptedBy: acceptedBy,
      rejectionReason: rejectionReason,
      result: result?.toDomain(),
      notes: notes,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
    );
  }

  static AiSuggestionDto fromDomain(AiSuggestion suggestion) {
    return AiSuggestionDto(
      id: suggestion.id,
      jobRef: suggestion.jobRef,
      designRef: suggestion.designRef,
      method: suggestion.method,
      model: suggestion.model,
      baseVersion: suggestion.baseVersion,
      baseHash: suggestion.baseHash,
      score: suggestion.score,
      scores: suggestion.scores != null
          ? AiScoresDto.fromDomain(suggestion.scores!)
          : null,
      diagnostics: suggestion.diagnostics
          .map((d) => AiDiagnosticDto.fromDomain(d))
          .toList(),
      registrability: suggestion.registrability,
      tags: suggestion.tags,
      delta: suggestion.delta != null
          ? AiSuggestionDeltaDto.fromDomain(suggestion.delta!)
          : null,
      preview: AiSuggestionPreviewDto.fromDomain(suggestion.preview),
      status: suggestion.status,
      createdAt: suggestion.createdAt,
      createdBy: suggestion.createdBy,
      acceptedAt: suggestion.acceptedAt,
      acceptedBy: suggestion.acceptedBy,
      rejectionReason: suggestion.rejectionReason,
      result: suggestion.result != null
          ? AiSuggestionResultDto.fromDomain(suggestion.result!)
          : null,
      notes: suggestion.notes,
      updatedAt: suggestion.updatedAt,
      expiresAt: suggestion.expiresAt,
    );
  }
}
