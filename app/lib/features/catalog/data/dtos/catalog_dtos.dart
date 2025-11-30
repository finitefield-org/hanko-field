// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:app/core/utils/json_utils.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart';

class TemplateLayoutDefaultsDto {
  const TemplateLayoutDefaultsDto({
    this.grid,
    this.margin,
    this.autoKern,
    this.centerBias,
  });

  final String? grid;
  final double? margin;
  final bool? autoKern;
  final double? centerBias;

  factory TemplateLayoutDefaultsDto.fromJson(Map<String, Object?> json) {
    return TemplateLayoutDefaultsDto(
      grid: json['grid'] as String?,
      margin: (json['margin'] as num?)?.toDouble(),
      autoKern: json['autoKern'] as bool?,
      centerBias: (json['centerBias'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'grid': grid,
    'margin': margin,
    'autoKern': autoKern,
    'centerBias': centerBias,
  };

  TemplateLayoutDefaults toDomain() {
    return TemplateLayoutDefaults(
      grid: grid,
      margin: margin,
      autoKern: autoKern,
      centerBias: centerBias,
    );
  }

  static TemplateLayoutDefaultsDto fromDomain(TemplateLayoutDefaults layout) {
    return TemplateLayoutDefaultsDto(
      grid: layout.grid,
      margin: layout.margin,
      autoKern: layout.autoKern,
      centerBias: layout.centerBias,
    );
  }
}

class TemplateStrokeDefaultsDto {
  const TemplateStrokeDefaultsDto({this.weight, this.contrast});

  final double? weight;
  final double? contrast;

  factory TemplateStrokeDefaultsDto.fromJson(Map<String, Object?> json) {
    return TemplateStrokeDefaultsDto(
      weight: (json['weight'] as num?)?.toDouble(),
      contrast: (json['contrast'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'weight': weight,
    'contrast': contrast,
  };

  TemplateStrokeDefaults toDomain() =>
      TemplateStrokeDefaults(weight: weight, contrast: contrast);

  static TemplateStrokeDefaultsDto fromDomain(TemplateStrokeDefaults stroke) {
    return TemplateStrokeDefaultsDto(
      weight: stroke.weight,
      contrast: stroke.contrast,
    );
  }
}

class TemplateDefaultsDto {
  const TemplateDefaultsDto({
    this.sizeMm,
    this.layout,
    this.stroke,
    this.fontRef,
  });

  final double? sizeMm;
  final TemplateLayoutDefaultsDto? layout;
  final TemplateStrokeDefaultsDto? stroke;
  final String? fontRef;

  factory TemplateDefaultsDto.fromJson(Map<String, Object?> json) {
    return TemplateDefaultsDto(
      sizeMm: (json['sizeMm'] as num?)?.toDouble(),
      layout: json['layout'] != null
          ? TemplateLayoutDefaultsDto.fromJson(
              Map<String, Object?>.from(json['layout'] as Map),
            )
          : null,
      stroke: json['stroke'] != null
          ? TemplateStrokeDefaultsDto.fromJson(
              Map<String, Object?>.from(json['stroke'] as Map),
            )
          : null,
      fontRef: json['fontRef'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'sizeMm': sizeMm,
    'layout': layout?.toJson(),
    'stroke': stroke?.toJson(),
    'fontRef': fontRef,
  };

  TemplateDefaults toDomain() {
    return TemplateDefaults(
      sizeMm: sizeMm,
      layout: layout?.toDomain(),
      stroke: stroke?.toDomain(),
      fontRef: fontRef,
    );
  }

  static TemplateDefaultsDto fromDomain(TemplateDefaults defaults) {
    return TemplateDefaultsDto(
      sizeMm: defaults.sizeMm,
      layout: defaults.layout != null
          ? TemplateLayoutDefaultsDto.fromDomain(defaults.layout!)
          : null,
      stroke: defaults.stroke != null
          ? TemplateStrokeDefaultsDto.fromDomain(defaults.stroke!)
          : null,
      fontRef: defaults.fontRef,
    );
  }
}

class SizeConstraintDto {
  const SizeConstraintDto({required this.min, required this.max, this.step});

  final double min;
  final double max;
  final double? step;

  factory SizeConstraintDto.fromJson(Map<String, Object?> json) {
    return SizeConstraintDto(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      step: (json['step'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'min': min,
    'max': max,
    'step': step,
  };

  SizeConstraint toDomain() => SizeConstraint(min: min, max: max, step: step);

  static SizeConstraintDto fromDomain(SizeConstraint constraint) {
    return SizeConstraintDto(
      min: constraint.min,
      max: constraint.max,
      step: constraint.step,
    );
  }
}

class RangeConstraintDto {
  const RangeConstraintDto({this.min, this.max});

  final double? min;
  final double? max;

  factory RangeConstraintDto.fromJson(Map<String, Object?> json) {
    return RangeConstraintDto(
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{'min': min, 'max': max};

  RangeConstraint toDomain() => RangeConstraint(min: min, max: max);

  static RangeConstraintDto fromDomain(RangeConstraint constraint) {
    return RangeConstraintDto(min: constraint.min, max: constraint.max);
  }
}

class GlyphConstraintDto {
  const GlyphConstraintDto({
    this.maxChars,
    this.allowRepeat,
    this.allowedScripts = const <String>[],
    this.prohibitedChars = const <String>[],
  });

  final int? maxChars;
  final bool? allowRepeat;
  final List<String> allowedScripts;
  final List<String> prohibitedChars;

  factory GlyphConstraintDto.fromJson(Map<String, Object?> json) {
    return GlyphConstraintDto(
      maxChars: (json['maxChars'] as num?)?.toInt(),
      allowRepeat: json['allowRepeat'] as bool?,
      allowedScripts:
          (json['allowedScripts'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      prohibitedChars:
          (json['prohibitedChars'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'maxChars': maxChars,
    'allowRepeat': allowRepeat,
    'allowedScripts': allowedScripts,
    'prohibitedChars': prohibitedChars,
  };

  GlyphConstraint toDomain() {
    return GlyphConstraint(
      maxChars: maxChars,
      allowRepeat: allowRepeat,
      allowedScripts: allowedScripts,
      prohibitedChars: prohibitedChars,
    );
  }

  static GlyphConstraintDto fromDomain(GlyphConstraint constraint) {
    return GlyphConstraintDto(
      maxChars: constraint.maxChars,
      allowRepeat: constraint.allowRepeat,
      allowedScripts: constraint.allowedScripts,
      prohibitedChars: constraint.prohibitedChars,
    );
  }
}

class RegistrabilityHintDto {
  const RegistrabilityHintDto({
    this.jpJitsuinAllowed,
    this.bankInAllowed,
    this.notes,
  });

  final bool? jpJitsuinAllowed;
  final bool? bankInAllowed;
  final String? notes;

  factory RegistrabilityHintDto.fromJson(Map<String, Object?> json) {
    return RegistrabilityHintDto(
      jpJitsuinAllowed: json['jpJitsuinAllowed'] as bool?,
      bankInAllowed: json['bankInAllowed'] as bool?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'jpJitsuinAllowed': jpJitsuinAllowed,
    'bankInAllowed': bankInAllowed,
    'notes': notes,
  };

  RegistrabilityHint toDomain() {
    return RegistrabilityHint(
      jpJitsuinAllowed: jpJitsuinAllowed,
      bankInAllowed: bankInAllowed,
      notes: notes,
    );
  }

  static RegistrabilityHintDto fromDomain(RegistrabilityHint hint) {
    return RegistrabilityHintDto(
      jpJitsuinAllowed: hint.jpJitsuinAllowed,
      bankInAllowed: hint.bankInAllowed,
      notes: hint.notes,
    );
  }
}

class TemplateConstraintsDto {
  const TemplateConstraintsDto({
    required this.sizeMm,
    required this.strokeWeight,
    this.margin,
    this.glyph,
    this.registrability,
  });

  final SizeConstraintDto sizeMm;
  final RangeConstraintDto strokeWeight;
  final RangeConstraintDto? margin;
  final GlyphConstraintDto? glyph;
  final RegistrabilityHintDto? registrability;

  factory TemplateConstraintsDto.fromJson(Map<String, Object?> json) {
    return TemplateConstraintsDto(
      sizeMm: SizeConstraintDto.fromJson(
        Map<String, Object?>.from(json['sizeMm'] as Map),
      ),
      strokeWeight: RangeConstraintDto.fromJson(
        Map<String, Object?>.from(json['strokeWeight'] as Map),
      ),
      margin: json['margin'] != null
          ? RangeConstraintDto.fromJson(
              Map<String, Object?>.from(json['margin'] as Map),
            )
          : null,
      glyph: json['glyph'] != null
          ? GlyphConstraintDto.fromJson(
              Map<String, Object?>.from(json['glyph'] as Map),
            )
          : null,
      registrability: json['registrability'] != null
          ? RegistrabilityHintDto.fromJson(
              Map<String, Object?>.from(json['registrability'] as Map),
            )
          : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'sizeMm': sizeMm.toJson(),
    'strokeWeight': strokeWeight.toJson(),
    'margin': margin?.toJson(),
    'glyph': glyph?.toJson(),
    'registrability': registrability?.toJson(),
  };

  TemplateConstraints toDomain() {
    return TemplateConstraints(
      sizeMm: sizeMm.toDomain(),
      strokeWeight: strokeWeight.toDomain(),
      margin: margin?.toDomain(),
      glyph: glyph?.toDomain(),
      registrability: registrability?.toDomain(),
    );
  }

  static TemplateConstraintsDto fromDomain(TemplateConstraints constraints) {
    return TemplateConstraintsDto(
      sizeMm: SizeConstraintDto.fromDomain(constraints.sizeMm),
      strokeWeight: RangeConstraintDto.fromDomain(constraints.strokeWeight),
      margin: constraints.margin != null
          ? RangeConstraintDto.fromDomain(constraints.margin!)
          : null,
      glyph: constraints.glyph != null
          ? GlyphConstraintDto.fromDomain(constraints.glyph!)
          : null,
      registrability: constraints.registrability != null
          ? RegistrabilityHintDto.fromDomain(constraints.registrability!)
          : null,
    );
  }
}

class TemplateRecommendationsDto {
  const TemplateRecommendationsDto({
    this.defaultSizeMm,
    this.materialRefs = const <String>[],
    this.productRefs = const <String>[],
  });

  final double? defaultSizeMm;
  final List<String> materialRefs;
  final List<String> productRefs;

  factory TemplateRecommendationsDto.fromJson(Map<String, Object?> json) {
    return TemplateRecommendationsDto(
      defaultSizeMm: (json['defaultSizeMm'] as num?)?.toDouble(),
      materialRefs:
          (json['materials'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      productRefs:
          (json['products'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'defaultSizeMm': defaultSizeMm,
    'materials': materialRefs,
    'products': productRefs,
  };

  TemplateRecommendations toDomain() {
    return TemplateRecommendations(
      defaultSizeMm: defaultSizeMm,
      materialRefs: materialRefs,
      productRefs: productRefs,
    );
  }

  static TemplateRecommendationsDto fromDomain(
    TemplateRecommendations recommendations,
  ) {
    return TemplateRecommendationsDto(
      defaultSizeMm: recommendations.defaultSizeMm,
      materialRefs: recommendations.materialRefs,
      productRefs: recommendations.productRefs,
    );
  }
}

class TemplateDto {
  const TemplateDto({
    required this.name,
    required this.shape,
    required this.writing,
    required this.constraints,
    required this.isPublic,
    required this.sort,
    required this.createdAt,
    required this.updatedAt,
    this.id,
    this.slug,
    this.description,
    this.tags = const <String>[],
    this.defaults,
    this.previewUrl,
    this.exampleImages = const <String>[],
    this.recommendations,
    this.version,
    this.isDeprecated = false,
    this.replacedBy,
  });

  final String? id;
  final String name;
  final String? slug;
  final String? description;
  final List<String> tags;
  final SealShape shape;
  final WritingStyle writing;
  final TemplateDefaultsDto? defaults;
  final TemplateConstraintsDto constraints;
  final String? previewUrl;
  final List<String> exampleImages;
  final TemplateRecommendationsDto? recommendations;
  final bool isPublic;
  final int sort;
  final String? version;
  final bool isDeprecated;
  final String? replacedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TemplateDto.fromJson(Map<String, Object?> json, {String? id}) {
    return TemplateDto(
      id: id,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      shape: SealShapeX.fromJson(json['shape'] as String),
      writing: WritingStyleX.fromJson(json['writing'] as String),
      defaults: json['defaults'] != null
          ? TemplateDefaultsDto.fromJson(
              Map<String, Object?>.from(json['defaults'] as Map),
            )
          : null,
      constraints: TemplateConstraintsDto.fromJson(
        Map<String, Object?>.from(json['constraints'] as Map),
      ),
      previewUrl: json['previewUrl'] as String?,
      exampleImages:
          (json['exampleImages'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      recommendations: json['recommendations'] != null
          ? TemplateRecommendationsDto.fromJson(
              Map<String, Object?>.from(json['recommendations'] as Map),
            )
          : null,
      isPublic: json['isPublic'] as bool? ?? false,
      sort: (json['sort'] as num?)?.toInt() ?? 0,
      version: json['version'] as String?,
      isDeprecated: json['isDeprecated'] as bool? ?? false,
      replacedBy: json['replacedBy'] as String?,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseDateTime(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'slug': slug,
    'description': description,
    'tags': tags,
    'shape': shape.toJson(),
    'writing': writing.toJson(),
    'defaults': defaults?.toJson(),
    'constraints': constraints.toJson(),
    'previewUrl': previewUrl,
    'exampleImages': exampleImages,
    'recommendations': recommendations?.toJson(),
    'isPublic': isPublic,
    'sort': sort,
    'version': version,
    'isDeprecated': isDeprecated,
    'replacedBy': replacedBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Template toDomain() {
    return Template(
      id: id,
      name: name,
      slug: slug,
      description: description,
      tags: tags,
      shape: shape,
      writing: writing,
      defaults: defaults?.toDomain(),
      constraints: constraints.toDomain(),
      previewUrl: previewUrl,
      exampleImages: exampleImages,
      recommendations: recommendations?.toDomain(),
      isPublic: isPublic,
      sort: sort,
      version: version,
      isDeprecated: isDeprecated,
      replacedBy: replacedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static TemplateDto fromDomain(Template template) {
    return TemplateDto(
      id: template.id,
      name: template.name,
      slug: template.slug,
      description: template.description,
      tags: template.tags,
      shape: template.shape,
      writing: template.writing,
      defaults: template.defaults != null
          ? TemplateDefaultsDto.fromDomain(template.defaults!)
          : null,
      constraints: TemplateConstraintsDto.fromDomain(template.constraints),
      previewUrl: template.previewUrl,
      exampleImages: template.exampleImages,
      recommendations: template.recommendations != null
          ? TemplateRecommendationsDto.fromDomain(template.recommendations!)
          : null,
      isPublic: template.isPublic,
      sort: template.sort,
      version: template.version,
      isDeprecated: template.isDeprecated,
      replacedBy: template.replacedBy,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
    );
  }
}

class SustainabilityDto {
  const SustainabilityDto({this.certifications = const <String>[], this.notes});

  final List<String> certifications;
  final String? notes;

  factory SustainabilityDto.fromJson(Map<String, Object?> json) {
    return SustainabilityDto(
      certifications:
          (json['certifications'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      notes: json['notes'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'certifications': certifications,
    'notes': notes,
  };

  Sustainability toDomain() {
    return Sustainability(certifications: certifications, notes: notes);
  }

  static SustainabilityDto fromDomain(Sustainability sustainability) {
    return SustainabilityDto(
      certifications: sustainability.certifications,
      notes: sustainability.notes,
    );
  }
}

class MaterialSupplierDto {
  const MaterialSupplierDto({
    this.reference,
    this.name,
    this.contactEmail,
    this.contactPhone,
    this.leadTimeDays,
    this.minimumOrderQuantity,
    this.unitCostCents,
    this.currency,
    this.notes,
  });

  final String? reference;
  final String? name;
  final String? contactEmail;
  final String? contactPhone;
  final int? leadTimeDays;
  final int? minimumOrderQuantity;
  final int? unitCostCents;
  final String? currency;
  final String? notes;

  factory MaterialSupplierDto.fromJson(Map<String, Object?> json) {
    return MaterialSupplierDto(
      reference: json['reference'] as String?,
      name: json['name'] as String?,
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
      leadTimeDays: (json['leadTimeDays'] as num?)?.toInt(),
      minimumOrderQuantity: (json['minimumOrderQuantity'] as num?)?.toInt(),
      unitCostCents: (json['unitCostCents'] as num?)?.toInt(),
      currency: json['currency'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'reference': reference,
    'name': name,
    'contactEmail': contactEmail,
    'contactPhone': contactPhone,
    'leadTimeDays': leadTimeDays,
    'minimumOrderQuantity': minimumOrderQuantity,
    'unitCostCents': unitCostCents,
    'currency': currency,
    'notes': notes,
  };

  MaterialSupplier toDomain() {
    return MaterialSupplier(
      reference: reference,
      name: name,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      leadTimeDays: leadTimeDays,
      minimumOrderQuantity: minimumOrderQuantity,
      unitCostCents: unitCostCents,
      currency: currency,
      notes: notes,
    );
  }

  static MaterialSupplierDto fromDomain(MaterialSupplier supplier) {
    return MaterialSupplierDto(
      reference: supplier.reference,
      name: supplier.name,
      contactEmail: supplier.contactEmail,
      contactPhone: supplier.contactPhone,
      leadTimeDays: supplier.leadTimeDays,
      minimumOrderQuantity: supplier.minimumOrderQuantity,
      unitCostCents: supplier.unitCostCents,
      currency: supplier.currency,
      notes: supplier.notes,
    );
  }
}

class MaterialInventoryDto {
  const MaterialInventoryDto({
    this.sku,
    this.safetyStock,
    this.reorderPoint,
    this.reorderQuantity,
    this.warehouse,
  });

  final String? sku;
  final int? safetyStock;
  final int? reorderPoint;
  final int? reorderQuantity;
  final String? warehouse;

  factory MaterialInventoryDto.fromJson(Map<String, Object?> json) {
    return MaterialInventoryDto(
      sku: json['sku'] as String?,
      safetyStock: (json['safetyStock'] as num?)?.toInt(),
      reorderPoint: (json['reorderPoint'] as num?)?.toInt(),
      reorderQuantity: (json['reorderQuantity'] as num?)?.toInt(),
      warehouse: json['warehouse'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'sku': sku,
    'safetyStock': safetyStock,
    'reorderPoint': reorderPoint,
    'reorderQuantity': reorderQuantity,
    'warehouse': warehouse,
  };

  MaterialInventory toDomain() {
    return MaterialInventory(
      sku: sku,
      safetyStock: safetyStock,
      reorderPoint: reorderPoint,
      reorderQuantity: reorderQuantity,
      warehouse: warehouse,
    );
  }

  static MaterialInventoryDto fromDomain(MaterialInventory inventory) {
    return MaterialInventoryDto(
      sku: inventory.sku,
      safetyStock: inventory.safetyStock,
      reorderPoint: inventory.reorderPoint,
      reorderQuantity: inventory.reorderQuantity,
      warehouse: inventory.warehouse,
    );
  }
}

class MaterialDto {
  const MaterialDto({
    required this.name,
    required this.type,
    required this.isActive,
    required this.createdAt,
    this.id,
    this.finish,
    this.color,
    this.hardness,
    this.density,
    this.careNotes,
    this.sustainability,
    this.photos = const <String>[],
    this.supplier,
    this.inventory,
    this.updatedAt,
  });

  final String? id;
  final String name;
  final MaterialType type;
  final MaterialFinish? finish;
  final String? color;
  final double? hardness;
  final double? density;
  final String? careNotes;
  final SustainabilityDto? sustainability;
  final List<String> photos;
  final MaterialSupplierDto? supplier;
  final MaterialInventoryDto? inventory;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory MaterialDto.fromJson(Map<String, Object?> json, {String? id}) {
    return MaterialDto(
      id: id,
      name: json['name'] as String,
      type: MaterialTypeX.fromJson(json['type'] as String),
      finish: json['finish'] != null
          ? MaterialFinishX.fromJson(json['finish'] as String)
          : null,
      color: json['color'] as String?,
      hardness: (json['hardness'] as num?)?.toDouble(),
      density: (json['density'] as num?)?.toDouble(),
      careNotes: json['careNotes'] as String?,
      sustainability: json['sustainability'] != null
          ? SustainabilityDto.fromJson(
              Map<String, Object?>.from(json['sustainability'] as Map),
            )
          : null,
      photos:
          (json['photos'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      supplier: json['supplier'] != null
          ? MaterialSupplierDto.fromJson(
              Map<String, Object?>.from(json['supplier'] as Map),
            )
          : null,
      inventory: json['inventory'] != null
          ? MaterialInventoryDto.fromJson(
              Map<String, Object?>.from(json['inventory'] as Map),
            )
          : null,
      isActive: json['isActive'] as bool? ?? false,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'type': type.toJson(),
    'finish': finish?.toJson(),
    'color': color,
    'hardness': hardness,
    'density': density,
    'careNotes': careNotes,
    'sustainability': sustainability?.toJson(),
    'photos': photos,
    'supplier': supplier?.toJson(),
    'inventory': inventory?.toJson(),
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Material toDomain() {
    return Material(
      id: id,
      name: name,
      type: type,
      finish: finish,
      color: color,
      hardness: hardness,
      density: density,
      careNotes: careNotes,
      sustainability: sustainability?.toDomain(),
      photos: photos,
      supplier: supplier?.toDomain(),
      inventory: inventory?.toDomain(),
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static MaterialDto fromDomain(Material material) {
    return MaterialDto(
      id: material.id,
      name: material.name,
      type: material.type,
      finish: material.finish,
      color: material.color,
      hardness: material.hardness,
      density: material.density,
      careNotes: material.careNotes,
      sustainability: material.sustainability != null
          ? SustainabilityDto.fromDomain(material.sustainability!)
          : null,
      photos: material.photos,
      supplier: material.supplier != null
          ? MaterialSupplierDto.fromDomain(material.supplier!)
          : null,
      inventory: material.inventory != null
          ? MaterialInventoryDto.fromDomain(material.inventory!)
          : null,
      isActive: material.isActive,
      createdAt: material.createdAt,
      updatedAt: material.updatedAt,
    );
  }
}

class SalePriceDto {
  const SalePriceDto({
    required this.amount,
    required this.currency,
    this.startsAt,
    this.endsAt,
    this.active,
  });

  final int amount;
  final String currency;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool? active;

  factory SalePriceDto.fromJson(Map<String, Object?> json) {
    return SalePriceDto(
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      startsAt: parseDateTime(json['startsAt']),
      endsAt: parseDateTime(json['endsAt']),
      active: json['active'] as bool?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'amount': amount,
    'currency': currency,
    'startsAt': startsAt?.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
    'active': active,
  };

  SalePrice toDomain() {
    return SalePrice(
      amount: amount,
      currency: currency,
      startsAt: startsAt,
      endsAt: endsAt,
      active: active,
    );
  }

  static SalePriceDto fromDomain(SalePrice sale) {
    return SalePriceDto(
      amount: sale.amount,
      currency: sale.currency,
      startsAt: sale.startsAt,
      endsAt: sale.endsAt,
      active: sale.active,
    );
  }
}

class ShippingAttributesDto {
  const ShippingAttributesDto({this.weightGr, this.boxSize});

  final int? weightGr;
  final String? boxSize;

  factory ShippingAttributesDto.fromJson(Map<String, Object?> json) {
    return ShippingAttributesDto(
      weightGr: (json['weightGr'] as num?)?.toInt(),
      boxSize: json['boxSize'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'weightGr': weightGr,
    'boxSize': boxSize,
  };

  ShippingAttributes toDomain() {
    return ShippingAttributes(weightGr: weightGr, boxSize: boxSize);
  }

  static ShippingAttributesDto fromDomain(ShippingAttributes shipping) {
    return ShippingAttributesDto(
      weightGr: shipping.weightGr,
      boxSize: shipping.boxSize,
    );
  }
}

class ProductDto {
  const ProductDto({
    required this.sku,
    required this.materialRef,
    required this.shape,
    required this.sizeMm,
    required this.basePrice,
    required this.stockPolicy,
    required this.isActive,
    required this.createdAt,
    this.id,
    this.engraveDepthMm,
    this.salePrice,
    this.stockQuantity,
    this.stockSafety,
    this.photos = const <String>[],
    this.shipping,
    this.attributes,
    this.updatedAt,
  });

  final String? id;
  final String sku;
  final String materialRef;
  final SealShape shape;
  final double sizeMm;
  final Money basePrice;
  final SalePriceDto? salePrice;
  final StockPolicy stockPolicy;
  final int? stockQuantity;
  final int? stockSafety;
  final List<String> photos;
  final ShippingAttributesDto? shipping;
  final Map<String, Object?>? attributes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? engraveDepthMm;

  factory ProductDto.fromJson(Map<String, Object?> json, {String? id}) {
    return ProductDto(
      id: id,
      sku: json['sku'] as String,
      materialRef: json['materialRef'] as String,
      shape: SealShapeX.fromJson(json['shape'] as String),
      sizeMm: (json['size'] as Map)['mm'] is num
          ? ((json['size'] as Map)['mm'] as num).toDouble()
          : 0,
      basePrice: Money.fromJson(
        Map<String, Object?>.from(json['basePrice'] as Map),
      ),
      salePrice: json['salePrice'] != null
          ? SalePriceDto.fromJson(
              Map<String, Object?>.from(json['salePrice'] as Map),
            )
          : null,
      stockPolicy: StockPolicyX.fromJson(json['stockPolicy'] as String),
      stockQuantity: (json['stockQuantity'] as num?)?.toInt(),
      stockSafety: (json['stockSafety'] as num?)?.toInt(),
      photos:
          (json['photos'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      shipping: json['shipping'] != null
          ? ShippingAttributesDto.fromJson(
              Map<String, Object?>.from(json['shipping'] as Map),
            )
          : null,
      attributes: asMap(json['attributes']),
      isActive: json['isActive'] as bool? ?? false,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: parseDateTime(json['updatedAt']),
      engraveDepthMm: (json['engraveDepthMm'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'sku': sku,
    'materialRef': materialRef,
    'shape': shape.toJson(),
    'size': <String, Object?>{'mm': sizeMm},
    'engraveDepthMm': engraveDepthMm,
    'basePrice': basePrice.toJson(),
    'salePrice': salePrice?.toJson(),
    'stockPolicy': stockPolicy.toJson(),
    'stockQuantity': stockQuantity,
    'stockSafety': stockSafety,
    'photos': photos,
    'shipping': shipping?.toJson(),
    'attributes': attributes,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Product toDomain() {
    return Product(
      id: id,
      sku: sku,
      materialRef: materialRef,
      shape: shape,
      sizeMm: sizeMm,
      basePrice: basePrice,
      salePrice: salePrice?.toDomain(),
      stockPolicy: stockPolicy,
      stockQuantity: stockQuantity,
      stockSafety: stockSafety,
      photos: photos,
      shipping: shipping?.toDomain(),
      attributes: attributes,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      engraveDepthMm: engraveDepthMm,
    );
  }

  static ProductDto fromDomain(Product product) {
    return ProductDto(
      id: product.id,
      sku: product.sku,
      materialRef: product.materialRef,
      shape: product.shape,
      sizeMm: product.sizeMm,
      basePrice: product.basePrice,
      salePrice: product.salePrice != null
          ? SalePriceDto.fromDomain(product.salePrice!)
          : null,
      stockPolicy: product.stockPolicy,
      stockQuantity: product.stockQuantity,
      stockSafety: product.stockSafety,
      photos: product.photos,
      shipping: product.shipping != null
          ? ShippingAttributesDto.fromDomain(product.shipping!)
          : null,
      attributes: product.attributes,
      isActive: product.isActive,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      engraveDepthMm: product.engraveDepthMm,
    );
  }
}

class FontLicenseDto {
  const FontLicenseDto({
    required this.type,
    this.uri,
    this.text,
    this.restrictions = const <String>[],
    this.embeddable,
    this.exportPermission,
  });

  final FontLicenseType type;
  final String? uri;
  final String? text;
  final List<String> restrictions;
  final bool? embeddable;
  final String? exportPermission;

  factory FontLicenseDto.fromJson(Map<String, Object?> json) {
    return FontLicenseDto(
      type: FontLicenseTypeX.fromJson(json['type'] as String),
      uri: json['uri'] as String?,
      text: json['text'] as String?,
      restrictions:
          (json['restrictions'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      embeddable: json['embeddable'] as bool?,
      exportPermission: json['exportPermission'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.toJson(),
    'uri': uri,
    'text': text,
    'restrictions': restrictions,
    'embeddable': embeddable,
    'exportPermission': exportPermission,
  };

  FontLicense toDomain() {
    return FontLicense(
      type: type,
      uri: uri,
      text: text,
      restrictions: restrictions,
      embeddable: embeddable,
      exportPermission: exportPermission,
    );
  }

  static FontLicenseDto fromDomain(FontLicense license) {
    return FontLicenseDto(
      type: license.type,
      uri: license.uri,
      text: license.text,
      restrictions: license.restrictions,
      embeddable: license.embeddable,
      exportPermission: license.exportPermission,
    );
  }
}

class UnicodeRangeDto {
  const UnicodeRangeDto({required this.start, required this.end, this.label});

  final String start;
  final String end;
  final String? label;

  factory UnicodeRangeDto.fromJson(Map<String, Object?> json) {
    return UnicodeRangeDto(
      start: json['start'] as String,
      end: json['end'] as String,
      label: json['label'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'start': start,
    'end': end,
    'label': label,
  };

  UnicodeRange toDomain() => UnicodeRange(start: start, end: end, label: label);

  static UnicodeRangeDto fromDomain(UnicodeRange range) {
    return UnicodeRangeDto(
      start: range.start,
      end: range.end,
      label: range.label,
    );
  }
}

class FontMetricsDto {
  const FontMetricsDto({
    this.unitsPerEm,
    this.ascent,
    this.descent,
    this.capHeight,
    this.xHeight,
    this.weightRange,
  });

  final int? unitsPerEm;
  final double? ascent;
  final double? descent;
  final double? capHeight;
  final double? xHeight;
  final RangeConstraintDto? weightRange;

  factory FontMetricsDto.fromJson(Map<String, Object?> json) {
    return FontMetricsDto(
      unitsPerEm: (json['unitsPerEm'] as num?)?.toInt(),
      ascent: (json['ascent'] as num?)?.toDouble(),
      descent: (json['descent'] as num?)?.toDouble(),
      capHeight: (json['capHeight'] as num?)?.toDouble(),
      xHeight: (json['xHeight'] as num?)?.toDouble(),
      weightRange: json['weightRange'] != null
          ? RangeConstraintDto.fromJson(
              Map<String, Object?>.from(json['weightRange'] as Map),
            )
          : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'unitsPerEm': unitsPerEm,
    'ascent': ascent,
    'descent': descent,
    'capHeight': capHeight,
    'xHeight': xHeight,
    'weightRange': weightRange?.toJson(),
  };

  FontMetrics toDomain() {
    return FontMetrics(
      unitsPerEm: unitsPerEm,
      ascent: ascent,
      descent: descent,
      capHeight: capHeight,
      xHeight: xHeight,
      weightRange: weightRange?.toDomain(),
    );
  }

  static FontMetricsDto fromDomain(FontMetrics metrics) {
    return FontMetricsDto(
      unitsPerEm: metrics.unitsPerEm,
      ascent: metrics.ascent,
      descent: metrics.descent,
      capHeight: metrics.capHeight,
      xHeight: metrics.xHeight,
      weightRange: metrics.weightRange != null
          ? RangeConstraintDto.fromDomain(metrics.weightRange!)
          : null,
    );
  }
}

class FontFilesDto {
  const FontFilesDto({this.otf, this.ttf, this.woff2});

  final String? otf;
  final String? ttf;
  final String? woff2;

  factory FontFilesDto.fromJson(Map<String, Object?> json) {
    return FontFilesDto(
      otf: json['otf'] as String?,
      ttf: json['ttf'] as String?,
      woff2: json['woff2'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'otf': otf,
    'ttf': ttf,
    'woff2': woff2,
  };

  FontFiles toDomain() => FontFiles(otf: otf, ttf: ttf, woff2: woff2);

  static FontFilesDto fromDomain(FontFiles files) {
    return FontFilesDto(otf: files.otf, ttf: files.ttf, woff2: files.woff2);
  }
}

class FontDto {
  const FontDto({
    required this.family,
    required this.writing,
    required this.license,
    required this.isPublic,
    required this.createdAt,
    this.id,
    this.subfamily,
    this.vendor,
    this.version,
    this.designClass,
    this.glyphCoverage = const <String>[],
    this.unicodeRanges = const <UnicodeRangeDto>[],
    this.metrics,
    this.opentypeFeatures = const <String>[],
    this.files,
    this.previewUrl,
    this.sampleText,
    this.sort,
    this.isDeprecated = false,
    this.replacedBy,
    this.updatedAt,
  });

  final String? id;
  final String family;
  final String? subfamily;
  final String? vendor;
  final String? version;
  final WritingStyle writing;
  final FontDesignClass? designClass;
  final FontLicenseDto license;
  final List<String> glyphCoverage;
  final List<UnicodeRangeDto> unicodeRanges;
  final FontMetricsDto? metrics;
  final List<String> opentypeFeatures;
  final FontFilesDto? files;
  final String? previewUrl;
  final String? sampleText;
  final bool isPublic;
  final int? sort;
  final bool isDeprecated;
  final String? replacedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory FontDto.fromJson(Map<String, Object?> json, {String? id}) {
    return FontDto(
      id: id,
      family: json['family'] as String,
      subfamily: json['subfamily'] as String?,
      vendor: json['vendor'] as String?,
      version: json['version'] as String?,
      writing: WritingStyleX.fromJson(json['writing'] as String),
      designClass: json['designClass'] != null
          ? FontDesignClassX.fromJson(json['designClass'] as String)
          : null,
      license: FontLicenseDto.fromJson(
        Map<String, Object?>.from(json['license'] as Map),
      ),
      glyphCoverage:
          (json['glyphCoverage'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      unicodeRanges:
          (json['unicodeRanges'] as List?)
              ?.map(
                (e) => UnicodeRangeDto.fromJson(
                  Map<String, Object?>.from(e as Map),
                ),
              )
              .toList() ??
          const <UnicodeRangeDto>[],
      metrics: json['metrics'] != null
          ? FontMetricsDto.fromJson(
              Map<String, Object?>.from(json['metrics'] as Map),
            )
          : null,
      opentypeFeatures:
          (asMap(json['opentype'])?['features'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      files: json['files'] != null
          ? FontFilesDto.fromJson(
              Map<String, Object?>.from(json['files'] as Map),
            )
          : null,
      previewUrl: json['previewUrl'] as String?,
      sampleText: json['sampleText'] as String?,
      isPublic: json['isPublic'] as bool? ?? false,
      sort: (json['sort'] as num?)?.toInt(),
      isDeprecated: json['isDeprecated'] as bool? ?? false,
      replacedBy: json['replacedBy'] as String?,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'family': family,
    'subfamily': subfamily,
    'vendor': vendor,
    'version': version,
    'writing': writing.toJson(),
    'designClass': designClass?.toJson(),
    'license': license.toJson(),
    'glyphCoverage': glyphCoverage,
    'unicodeRanges': unicodeRanges.map((e) => e.toJson()).toList(),
    'metrics': metrics?.toJson(),
    'opentype': <String, Object?>{'features': opentypeFeatures},
    'files': files?.toJson(),
    'previewUrl': previewUrl,
    'sampleText': sampleText,
    'isPublic': isPublic,
    'sort': sort,
    'isDeprecated': isDeprecated,
    'replacedBy': replacedBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Font toDomain() {
    return Font(
      id: id,
      family: family,
      subfamily: subfamily,
      vendor: vendor,
      version: version,
      writing: writing,
      designClass: designClass,
      license: license.toDomain(),
      glyphCoverage: glyphCoverage,
      unicodeRanges: unicodeRanges.map((e) => e.toDomain()).toList(),
      metrics: metrics?.toDomain(),
      opentypeFeatures: opentypeFeatures,
      files: files?.toDomain(),
      previewUrl: previewUrl,
      sampleText: sampleText,
      isPublic: isPublic,
      sort: sort,
      isDeprecated: isDeprecated,
      replacedBy: replacedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static FontDto fromDomain(Font font) {
    return FontDto(
      id: font.id,
      family: font.family,
      subfamily: font.subfamily,
      vendor: font.vendor,
      version: font.version,
      writing: font.writing,
      designClass: font.designClass,
      license: FontLicenseDto.fromDomain(font.license),
      glyphCoverage: font.glyphCoverage,
      unicodeRanges: font.unicodeRanges
          .map((e) => UnicodeRangeDto.fromDomain(e))
          .toList(),
      metrics: font.metrics != null
          ? FontMetricsDto.fromDomain(font.metrics!)
          : null,
      opentypeFeatures: font.opentypeFeatures,
      files: font.files != null ? FontFilesDto.fromDomain(font.files!) : null,
      previewUrl: font.previewUrl,
      sampleText: font.sampleText,
      isPublic: font.isPublic,
      sort: font.sort,
      isDeprecated: font.isDeprecated,
      replacedBy: font.replacedBy,
      createdAt: font.createdAt,
      updatedAt: font.updatedAt,
    );
  }
}
