import 'package:app/core/domain/entities/catalog.dart';
import 'package:flutter/foundation.dart';

@immutable
class MaterialDetail {
  MaterialDetail({
    required this.material,
    required this.description,
    required List<String> highlights,
    required List<MaterialMedia> media,
    required List<MaterialSpec> specs,
    required this.availability,
    required List<String> compatibleProductIds,
  }) : highlights = List.unmodifiable(highlights),
       media = List.unmodifiable(media),
       specs = List.unmodifiable(specs),
       compatibleProductIds = List.unmodifiable(compatibleProductIds);

  final CatalogMaterial material;
  final String description;
  final List<String> highlights;
  final List<MaterialMedia> media;
  final List<MaterialSpec> specs;
  final MaterialAvailability availability;
  final List<String> compatibleProductIds;

  MaterialDetail copyWith({
    CatalogMaterial? material,
    String? description,
    List<String>? highlights,
    List<MaterialMedia>? media,
    List<MaterialSpec>? specs,
    MaterialAvailability? availability,
    List<String>? compatibleProductIds,
  }) {
    return MaterialDetail(
      material: material ?? this.material,
      description: description ?? this.description,
      highlights: highlights ?? this.highlights,
      media: media ?? this.media,
      specs: specs ?? this.specs,
      availability: availability ?? this.availability,
      compatibleProductIds: compatibleProductIds ?? this.compatibleProductIds,
    );
  }
}

enum MaterialMediaType { image, video }

@immutable
class MaterialMedia {
  const MaterialMedia({
    required this.type,
    required this.url,
    this.previewImageUrl,
    this.caption,
  });

  final MaterialMediaType type;
  final String url;
  final String? previewImageUrl;
  final String? caption;
}

enum MaterialSpecKind {
  hardness,
  texture,
  finish,
  origin,
  density,
  color,
  sustainability,
  maintenance,
  bestFor,
}

@immutable
class MaterialSpec {
  const MaterialSpec({
    required this.kind,
    required this.label,
    required this.value,
    this.detail,
  });

  final MaterialSpecKind kind;
  final String label;
  final String value;
  final String? detail;
}

@immutable
class MaterialAvailability {
  MaterialAvailability({
    required this.statusLabel,
    required List<String> tags,
    this.estimatedLeadTime,
    this.inventoryNote,
  }) : tags = List.unmodifiable(tags);

  final String statusLabel;
  final List<String> tags;
  final String? estimatedLeadTime;
  final String? inventoryNote;
}
