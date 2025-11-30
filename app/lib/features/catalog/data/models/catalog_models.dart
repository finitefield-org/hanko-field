// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:collection/collection.dart';

class TemplateLayoutDefaults {
  const TemplateLayoutDefaults({
    this.grid,
    this.margin,
    this.autoKern,
    this.centerBias,
  });

  final String? grid;
  final double? margin;
  final bool? autoKern;
  final double? centerBias;

  TemplateLayoutDefaults copyWith({
    String? grid,
    double? margin,
    bool? autoKern,
    double? centerBias,
  }) {
    return TemplateLayoutDefaults(
      grid: grid ?? this.grid,
      margin: margin ?? this.margin,
      autoKern: autoKern ?? this.autoKern,
      centerBias: centerBias ?? this.centerBias,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is TemplateLayoutDefaults &&
            other.grid == grid &&
            other.margin == margin &&
            other.autoKern == autoKern &&
            other.centerBias == centerBias);
  }

  @override
  int get hashCode => Object.hash(grid, margin, autoKern, centerBias);
}

class TemplateStrokeDefaults {
  const TemplateStrokeDefaults({this.weight, this.contrast});

  final double? weight;
  final double? contrast;

  TemplateStrokeDefaults copyWith({double? weight, double? contrast}) {
    return TemplateStrokeDefaults(
      weight: weight ?? this.weight,
      contrast: contrast ?? this.contrast,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is TemplateStrokeDefaults &&
            other.weight == weight &&
            other.contrast == contrast);
  }

  @override
  int get hashCode => Object.hash(weight, contrast);
}

class TemplateDefaults {
  const TemplateDefaults({this.sizeMm, this.layout, this.stroke, this.fontRef});

  final double? sizeMm;
  final TemplateLayoutDefaults? layout;
  final TemplateStrokeDefaults? stroke;
  final String? fontRef;

  TemplateDefaults copyWith({
    double? sizeMm,
    TemplateLayoutDefaults? layout,
    TemplateStrokeDefaults? stroke,
    String? fontRef,
  }) {
    return TemplateDefaults(
      sizeMm: sizeMm ?? this.sizeMm,
      layout: layout ?? this.layout,
      stroke: stroke ?? this.stroke,
      fontRef: fontRef ?? this.fontRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is TemplateDefaults &&
            other.sizeMm == sizeMm &&
            other.layout == layout &&
            other.stroke == stroke &&
            other.fontRef == fontRef);
  }

  @override
  int get hashCode => Object.hash(sizeMm, layout, stroke, fontRef);
}

class SizeConstraint {
  const SizeConstraint({required this.min, required this.max, this.step});

  final double min;
  final double max;
  final double? step;

  SizeConstraint copyWith({double? min, double? max, double? step}) {
    return SizeConstraint(
      min: min ?? this.min,
      max: max ?? this.max,
      step: step ?? this.step,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SizeConstraint &&
            other.min == min &&
            other.max == max &&
            other.step == step);
  }

  @override
  int get hashCode => Object.hash(min, max, step);
}

class RangeConstraint {
  const RangeConstraint({this.min, this.max});

  final double? min;
  final double? max;

  RangeConstraint copyWith({double? min, double? max}) {
    return RangeConstraint(min: min ?? this.min, max: max ?? this.max);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RangeConstraint && other.min == min && other.max == max);
  }

  @override
  int get hashCode => Object.hash(min, max);
}

class GlyphConstraint {
  const GlyphConstraint({
    this.maxChars,
    this.allowRepeat,
    this.allowedScripts = const <String>[],
    this.prohibitedChars = const <String>[],
  });

  final int? maxChars;
  final bool? allowRepeat;
  final List<String> allowedScripts;
  final List<String> prohibitedChars;

  GlyphConstraint copyWith({
    int? maxChars,
    bool? allowRepeat,
    List<String>? allowedScripts,
    List<String>? prohibitedChars,
  }) {
    return GlyphConstraint(
      maxChars: maxChars ?? this.maxChars,
      allowRepeat: allowRepeat ?? this.allowRepeat,
      allowedScripts: allowedScripts ?? this.allowedScripts,
      prohibitedChars: prohibitedChars ?? this.prohibitedChars,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is GlyphConstraint &&
            other.maxChars == maxChars &&
            other.allowRepeat == allowRepeat &&
            listEq.equals(other.allowedScripts, allowedScripts) &&
            listEq.equals(other.prohibitedChars, prohibitedChars));
  }

  @override
  int get hashCode => Object.hash(
    maxChars,
    allowRepeat,
    const ListEquality<String>().hash(allowedScripts),
    const ListEquality<String>().hash(prohibitedChars),
  );
}

class RegistrabilityHint {
  const RegistrabilityHint({
    this.jpJitsuinAllowed,
    this.bankInAllowed,
    this.notes,
  });

  final bool? jpJitsuinAllowed;
  final bool? bankInAllowed;
  final String? notes;

  RegistrabilityHint copyWith({
    bool? jpJitsuinAllowed,
    bool? bankInAllowed,
    String? notes,
  }) {
    return RegistrabilityHint(
      jpJitsuinAllowed: jpJitsuinAllowed ?? this.jpJitsuinAllowed,
      bankInAllowed: bankInAllowed ?? this.bankInAllowed,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RegistrabilityHint &&
            other.jpJitsuinAllowed == jpJitsuinAllowed &&
            other.bankInAllowed == bankInAllowed &&
            other.notes == notes);
  }

  @override
  int get hashCode => Object.hash(jpJitsuinAllowed, bankInAllowed, notes);
}

class TemplateConstraints {
  const TemplateConstraints({
    required this.sizeMm,
    required this.strokeWeight,
    this.margin,
    this.glyph,
    this.registrability,
  });

  final SizeConstraint sizeMm;
  final RangeConstraint strokeWeight;
  final RangeConstraint? margin;
  final GlyphConstraint? glyph;
  final RegistrabilityHint? registrability;

  TemplateConstraints copyWith({
    SizeConstraint? sizeMm,
    RangeConstraint? strokeWeight,
    RangeConstraint? margin,
    GlyphConstraint? glyph,
    RegistrabilityHint? registrability,
  }) {
    return TemplateConstraints(
      sizeMm: sizeMm ?? this.sizeMm,
      strokeWeight: strokeWeight ?? this.strokeWeight,
      margin: margin ?? this.margin,
      glyph: glyph ?? this.glyph,
      registrability: registrability ?? this.registrability,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is TemplateConstraints &&
            other.sizeMm == sizeMm &&
            other.strokeWeight == strokeWeight &&
            other.margin == margin &&
            other.glyph == glyph &&
            other.registrability == registrability);
  }

  @override
  int get hashCode =>
      Object.hash(sizeMm, strokeWeight, margin, glyph, registrability);
}

class TemplateRecommendations {
  const TemplateRecommendations({
    this.defaultSizeMm,
    this.materialRefs = const <String>[],
    this.productRefs = const <String>[],
  });

  final double? defaultSizeMm;
  final List<String> materialRefs;
  final List<String> productRefs;

  TemplateRecommendations copyWith({
    double? defaultSizeMm,
    List<String>? materialRefs,
    List<String>? productRefs,
  }) {
    return TemplateRecommendations(
      defaultSizeMm: defaultSizeMm ?? this.defaultSizeMm,
      materialRefs: materialRefs ?? this.materialRefs,
      productRefs: productRefs ?? this.productRefs,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is TemplateRecommendations &&
            other.defaultSizeMm == defaultSizeMm &&
            listEq.equals(other.materialRefs, materialRefs) &&
            listEq.equals(other.productRefs, productRefs));
  }

  @override
  int get hashCode => Object.hash(
    defaultSizeMm,
    const ListEquality<String>().hash(materialRefs),
    const ListEquality<String>().hash(productRefs),
  );
}

class Template {
  const Template({
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
  final TemplateDefaults? defaults;
  final TemplateConstraints constraints;
  final String? previewUrl;
  final List<String> exampleImages;
  final TemplateRecommendations? recommendations;
  final bool isPublic;
  final int sort;
  final String? version;
  final bool isDeprecated;
  final String? replacedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Template copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    List<String>? tags,
    SealShape? shape,
    WritingStyle? writing,
    TemplateDefaults? defaults,
    TemplateConstraints? constraints,
    String? previewUrl,
    List<String>? exampleImages,
    TemplateRecommendations? recommendations,
    bool? isPublic,
    int? sort,
    String? version,
    bool? isDeprecated,
    String? replacedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      shape: shape ?? this.shape,
      writing: writing ?? this.writing,
      defaults: defaults ?? this.defaults,
      constraints: constraints ?? this.constraints,
      previewUrl: previewUrl ?? this.previewUrl,
      exampleImages: exampleImages ?? this.exampleImages,
      recommendations: recommendations ?? this.recommendations,
      isPublic: isPublic ?? this.isPublic,
      sort: sort ?? this.sort,
      version: version ?? this.version,
      isDeprecated: isDeprecated ?? this.isDeprecated,
      replacedBy: replacedBy ?? this.replacedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is Template &&
            other.id == id &&
            other.name == name &&
            other.slug == slug &&
            other.description == description &&
            listEq.equals(other.tags, tags) &&
            other.shape == shape &&
            other.writing == writing &&
            other.defaults == defaults &&
            other.constraints == constraints &&
            other.previewUrl == previewUrl &&
            listEq.equals(other.exampleImages, exampleImages) &&
            other.recommendations == recommendations &&
            other.isPublic == isPublic &&
            other.sort == sort &&
            other.version == version &&
            other.isDeprecated == isDeprecated &&
            other.replacedBy == replacedBy &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    slug,
    description,
    const ListEquality<String>().hash(tags),
    shape,
    writing,
    defaults,
    constraints,
    previewUrl,
    const ListEquality<String>().hash(exampleImages),
    recommendations,
    isPublic,
    sort,
    version,
    isDeprecated,
    replacedBy,
    createdAt,
    updatedAt,
  ]);
}

enum MaterialType { horn, wood, titanium, acrylic }

extension MaterialTypeX on MaterialType {
  String toJson() => switch (this) {
    MaterialType.horn => 'horn',
    MaterialType.wood => 'wood',
    MaterialType.titanium => 'titanium',
    MaterialType.acrylic => 'acrylic',
  };

  static MaterialType fromJson(String value) {
    switch (value) {
      case 'horn':
        return MaterialType.horn;
      case 'wood':
        return MaterialType.wood;
      case 'titanium':
        return MaterialType.titanium;
      case 'acrylic':
        return MaterialType.acrylic;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported material type');
  }
}

enum MaterialFinish { matte, gloss, hairline }

extension MaterialFinishX on MaterialFinish {
  String toJson() => switch (this) {
    MaterialFinish.matte => 'matte',
    MaterialFinish.gloss => 'gloss',
    MaterialFinish.hairline => 'hairline',
  };

  static MaterialFinish fromJson(String value) {
    switch (value) {
      case 'matte':
        return MaterialFinish.matte;
      case 'gloss':
        return MaterialFinish.gloss;
      case 'hairline':
        return MaterialFinish.hairline;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported finish');
  }
}

class Sustainability {
  const Sustainability({this.certifications = const <String>[], this.notes});

  final List<String> certifications;
  final String? notes;

  Sustainability copyWith({List<String>? certifications, String? notes}) {
    return Sustainability(
      certifications: certifications ?? this.certifications,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is Sustainability &&
            listEq.equals(other.certifications, certifications) &&
            other.notes == notes);
  }

  @override
  int get hashCode =>
      Object.hash(const ListEquality<String>().hash(certifications), notes);
}

class MaterialSupplier {
  const MaterialSupplier({
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

  MaterialSupplier copyWith({
    String? reference,
    String? name,
    String? contactEmail,
    String? contactPhone,
    int? leadTimeDays,
    int? minimumOrderQuantity,
    int? unitCostCents,
    String? currency,
    String? notes,
  }) {
    return MaterialSupplier(
      reference: reference ?? this.reference,
      name: name ?? this.name,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      minimumOrderQuantity: minimumOrderQuantity ?? this.minimumOrderQuantity,
      unitCostCents: unitCostCents ?? this.unitCostCents,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is MaterialSupplier &&
            other.reference == reference &&
            other.name == name &&
            other.contactEmail == contactEmail &&
            other.contactPhone == contactPhone &&
            other.leadTimeDays == leadTimeDays &&
            other.minimumOrderQuantity == minimumOrderQuantity &&
            other.unitCostCents == unitCostCents &&
            other.currency == currency &&
            other.notes == notes);
  }

  @override
  int get hashCode => Object.hash(
    reference,
    name,
    contactEmail,
    contactPhone,
    leadTimeDays,
    minimumOrderQuantity,
    unitCostCents,
    currency,
    notes,
  );
}

class MaterialInventory {
  const MaterialInventory({
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

  MaterialInventory copyWith({
    String? sku,
    int? safetyStock,
    int? reorderPoint,
    int? reorderQuantity,
    String? warehouse,
  }) {
    return MaterialInventory(
      sku: sku ?? this.sku,
      safetyStock: safetyStock ?? this.safetyStock,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      reorderQuantity: reorderQuantity ?? this.reorderQuantity,
      warehouse: warehouse ?? this.warehouse,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is MaterialInventory &&
            other.sku == sku &&
            other.safetyStock == safetyStock &&
            other.reorderPoint == reorderPoint &&
            other.reorderQuantity == reorderQuantity &&
            other.warehouse == warehouse);
  }

  @override
  int get hashCode =>
      Object.hash(sku, safetyStock, reorderPoint, reorderQuantity, warehouse);
}

class Material {
  const Material({
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
  final Sustainability? sustainability;
  final List<String> photos;
  final MaterialSupplier? supplier;
  final MaterialInventory? inventory;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Material copyWith({
    String? id,
    String? name,
    MaterialType? type,
    MaterialFinish? finish,
    String? color,
    double? hardness,
    double? density,
    String? careNotes,
    Sustainability? sustainability,
    List<String>? photos,
    MaterialSupplier? supplier,
    MaterialInventory? inventory,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Material(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      finish: finish ?? this.finish,
      color: color ?? this.color,
      hardness: hardness ?? this.hardness,
      density: density ?? this.density,
      careNotes: careNotes ?? this.careNotes,
      sustainability: sustainability ?? this.sustainability,
      photos: photos ?? this.photos,
      supplier: supplier ?? this.supplier,
      inventory: inventory ?? this.inventory,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is Material &&
            other.id == id &&
            other.name == name &&
            other.type == type &&
            other.finish == finish &&
            other.color == color &&
            other.hardness == hardness &&
            other.density == density &&
            other.careNotes == careNotes &&
            other.sustainability == sustainability &&
            listEq.equals(other.photos, photos) &&
            other.supplier == supplier &&
            other.inventory == inventory &&
            other.isActive == isActive &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    type,
    finish,
    color,
    hardness,
    density,
    careNotes,
    sustainability,
    const ListEquality<String>().hash(photos),
    supplier,
    inventory,
    isActive,
    createdAt,
    updatedAt,
  ]);
}

enum StockPolicy { madeToOrder, inventory }

extension StockPolicyX on StockPolicy {
  String toJson() => switch (this) {
    StockPolicy.madeToOrder => 'madeToOrder',
    StockPolicy.inventory => 'inventory',
  };

  static StockPolicy fromJson(String value) {
    switch (value) {
      case 'madeToOrder':
        return StockPolicy.madeToOrder;
      case 'inventory':
        return StockPolicy.inventory;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported stock policy');
  }
}

class SalePrice {
  const SalePrice({
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

  SalePrice copyWith({
    int? amount,
    String? currency,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? active,
  }) {
    return SalePrice(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SalePrice &&
            other.amount == amount &&
            other.currency == currency &&
            other.startsAt == startsAt &&
            other.endsAt == endsAt &&
            other.active == active);
  }

  @override
  int get hashCode => Object.hash(amount, currency, startsAt, endsAt, active);
}

class ShippingAttributes {
  const ShippingAttributes({this.weightGr, this.boxSize});

  final int? weightGr;
  final String? boxSize;

  ShippingAttributes copyWith({int? weightGr, String? boxSize}) {
    return ShippingAttributes(
      weightGr: weightGr ?? this.weightGr,
      boxSize: boxSize ?? this.boxSize,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ShippingAttributes &&
            other.weightGr == weightGr &&
            other.boxSize == boxSize);
  }

  @override
  int get hashCode => Object.hash(weightGr, boxSize);
}

class Product {
  const Product({
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
  final SalePrice? salePrice;
  final StockPolicy stockPolicy;
  final int? stockQuantity;
  final int? stockSafety;
  final List<String> photos;
  final ShippingAttributes? shipping;
  final Map<String, Object?>? attributes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? engraveDepthMm;

  Product copyWith({
    String? id,
    String? sku,
    String? materialRef,
    SealShape? shape,
    double? sizeMm,
    Money? basePrice,
    SalePrice? salePrice,
    StockPolicy? stockPolicy,
    int? stockQuantity,
    int? stockSafety,
    List<String>? photos,
    ShippingAttributes? shipping,
    Map<String, Object?>? attributes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? engraveDepthMm,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      materialRef: materialRef ?? this.materialRef,
      shape: shape ?? this.shape,
      sizeMm: sizeMm ?? this.sizeMm,
      basePrice: basePrice ?? this.basePrice,
      salePrice: salePrice ?? this.salePrice,
      stockPolicy: stockPolicy ?? this.stockPolicy,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      stockSafety: stockSafety ?? this.stockSafety,
      photos: photos ?? this.photos,
      shipping: shipping ?? this.shipping,
      attributes: attributes ?? this.attributes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      engraveDepthMm: engraveDepthMm ?? this.engraveDepthMm,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    const deepEq = DeepCollectionEquality();
    return identical(this, other) ||
        (other is Product &&
            other.id == id &&
            other.sku == sku &&
            other.materialRef == materialRef &&
            other.shape == shape &&
            other.sizeMm == sizeMm &&
            other.basePrice == basePrice &&
            other.salePrice == salePrice &&
            other.stockPolicy == stockPolicy &&
            other.stockQuantity == stockQuantity &&
            other.stockSafety == stockSafety &&
            listEq.equals(other.photos, photos) &&
            other.shipping == shipping &&
            deepEq.equals(other.attributes, attributes) &&
            other.isActive == isActive &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.engraveDepthMm == engraveDepthMm);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    sku,
    materialRef,
    shape,
    sizeMm,
    basePrice,
    salePrice,
    stockPolicy,
    stockQuantity,
    stockSafety,
    const ListEquality<String>().hash(photos),
    shipping,
    const DeepCollectionEquality().hash(attributes),
    isActive,
    createdAt,
    updatedAt,
    engraveDepthMm,
  ]);
}

enum FontLicenseType { commercial, open, custom }

extension FontLicenseTypeX on FontLicenseType {
  String toJson() => switch (this) {
    FontLicenseType.commercial => 'commercial',
    FontLicenseType.open => 'open',
    FontLicenseType.custom => 'custom',
  };

  static FontLicenseType fromJson(String value) {
    switch (value) {
      case 'commercial':
        return FontLicenseType.commercial;
      case 'open':
        return FontLicenseType.open;
      case 'custom':
        return FontLicenseType.custom;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported license type');
  }
}

class FontLicense {
  const FontLicense({
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

  FontLicense copyWith({
    FontLicenseType? type,
    String? uri,
    String? text,
    List<String>? restrictions,
    bool? embeddable,
    String? exportPermission,
  }) {
    return FontLicense(
      type: type ?? this.type,
      uri: uri ?? this.uri,
      text: text ?? this.text,
      restrictions: restrictions ?? this.restrictions,
      embeddable: embeddable ?? this.embeddable,
      exportPermission: exportPermission ?? this.exportPermission,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is FontLicense &&
            other.type == type &&
            other.uri == uri &&
            other.text == text &&
            listEq.equals(other.restrictions, restrictions) &&
            other.embeddable == embeddable &&
            other.exportPermission == exportPermission);
  }

  @override
  int get hashCode => Object.hash(
    type,
    uri,
    text,
    const ListEquality<String>().hash(restrictions),
    embeddable,
    exportPermission,
  );
}

enum FontDesignClass { serif, sans, brush, seal, engraved, other }

extension FontDesignClassX on FontDesignClass {
  String toJson() => switch (this) {
    FontDesignClass.serif => 'serif',
    FontDesignClass.sans => 'sans',
    FontDesignClass.brush => 'brush',
    FontDesignClass.seal => 'seal',
    FontDesignClass.engraved => 'engraved',
    FontDesignClass.other => 'other',
  };

  static FontDesignClass fromJson(String value) {
    switch (value) {
      case 'serif':
        return FontDesignClass.serif;
      case 'sans':
        return FontDesignClass.sans;
      case 'brush':
        return FontDesignClass.brush;
      case 'seal':
        return FontDesignClass.seal;
      case 'engraved':
        return FontDesignClass.engraved;
      case 'other':
        return FontDesignClass.other;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported design class');
  }
}

class UnicodeRange {
  const UnicodeRange({required this.start, required this.end, this.label});

  final String start;
  final String end;
  final String? label;

  UnicodeRange copyWith({String? start, String? end, String? label}) {
    return UnicodeRange(
      start: start ?? this.start,
      end: end ?? this.end,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UnicodeRange &&
            other.start == start &&
            other.end == end &&
            other.label == label);
  }

  @override
  int get hashCode => Object.hash(start, end, label);
}

class FontMetrics {
  const FontMetrics({
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
  final RangeConstraint? weightRange;

  FontMetrics copyWith({
    int? unitsPerEm,
    double? ascent,
    double? descent,
    double? capHeight,
    double? xHeight,
    RangeConstraint? weightRange,
  }) {
    return FontMetrics(
      unitsPerEm: unitsPerEm ?? this.unitsPerEm,
      ascent: ascent ?? this.ascent,
      descent: descent ?? this.descent,
      capHeight: capHeight ?? this.capHeight,
      xHeight: xHeight ?? this.xHeight,
      weightRange: weightRange ?? this.weightRange,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is FontMetrics &&
            other.unitsPerEm == unitsPerEm &&
            other.ascent == ascent &&
            other.descent == descent &&
            other.capHeight == capHeight &&
            other.xHeight == xHeight &&
            other.weightRange == weightRange);
  }

  @override
  int get hashCode =>
      Object.hash(unitsPerEm, ascent, descent, capHeight, xHeight, weightRange);
}

class FontFiles {
  const FontFiles({this.otf, this.ttf, this.woff2});

  final String? otf;
  final String? ttf;
  final String? woff2;

  FontFiles copyWith({String? otf, String? ttf, String? woff2}) {
    return FontFiles(
      otf: otf ?? this.otf,
      ttf: ttf ?? this.ttf,
      woff2: woff2 ?? this.woff2,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is FontFiles &&
            other.otf == otf &&
            other.ttf == ttf &&
            other.woff2 == woff2);
  }

  @override
  int get hashCode => Object.hash(otf, ttf, woff2);
}

class Font {
  const Font({
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
    this.unicodeRanges = const <UnicodeRange>[],
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
  final FontLicense license;
  final List<String> glyphCoverage;
  final List<UnicodeRange> unicodeRanges;
  final FontMetrics? metrics;
  final List<String> opentypeFeatures;
  final FontFiles? files;
  final String? previewUrl;
  final String? sampleText;
  final bool isPublic;
  final int? sort;
  final bool isDeprecated;
  final String? replacedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Font copyWith({
    String? id,
    String? family,
    String? subfamily,
    String? vendor,
    String? version,
    WritingStyle? writing,
    FontDesignClass? designClass,
    FontLicense? license,
    List<String>? glyphCoverage,
    List<UnicodeRange>? unicodeRanges,
    FontMetrics? metrics,
    List<String>? opentypeFeatures,
    FontFiles? files,
    String? previewUrl,
    String? sampleText,
    bool? isPublic,
    int? sort,
    bool? isDeprecated,
    String? replacedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Font(
      id: id ?? this.id,
      family: family ?? this.family,
      subfamily: subfamily ?? this.subfamily,
      vendor: vendor ?? this.vendor,
      version: version ?? this.version,
      writing: writing ?? this.writing,
      designClass: designClass ?? this.designClass,
      license: license ?? this.license,
      glyphCoverage: glyphCoverage ?? this.glyphCoverage,
      unicodeRanges: unicodeRanges ?? this.unicodeRanges,
      metrics: metrics ?? this.metrics,
      opentypeFeatures: opentypeFeatures ?? this.opentypeFeatures,
      files: files ?? this.files,
      previewUrl: previewUrl ?? this.previewUrl,
      sampleText: sampleText ?? this.sampleText,
      isPublic: isPublic ?? this.isPublic,
      sort: sort ?? this.sort,
      isDeprecated: isDeprecated ?? this.isDeprecated,
      replacedBy: replacedBy ?? this.replacedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const stringEq = ListEquality<String>();
    const unicodeEq = ListEquality<UnicodeRange>();
    return identical(this, other) ||
        (other is Font &&
            other.id == id &&
            other.family == family &&
            other.subfamily == subfamily &&
            other.vendor == vendor &&
            other.version == version &&
            other.writing == writing &&
            other.designClass == designClass &&
            other.license == license &&
            stringEq.equals(other.glyphCoverage, glyphCoverage) &&
            unicodeEq.equals(other.unicodeRanges, unicodeRanges) &&
            other.metrics == metrics &&
            stringEq.equals(other.opentypeFeatures, opentypeFeatures) &&
            other.files == files &&
            other.previewUrl == previewUrl &&
            other.sampleText == sampleText &&
            other.isPublic == isPublic &&
            other.sort == sort &&
            other.isDeprecated == isDeprecated &&
            other.replacedBy == replacedBy &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    family,
    subfamily,
    vendor,
    version,
    writing,
    designClass,
    license,
    const ListEquality<String>().hash(glyphCoverage),
    const ListEquality<UnicodeRange>().hash(unicodeRanges),
    metrics,
    const ListEquality<String>().hash(opentypeFeatures),
    files,
    previewUrl,
    sampleText,
    isPublic,
    sort,
    isDeprecated,
    replacedBy,
    createdAt,
    updatedAt,
  ]);
}
