import 'package:flutter/foundation.dart';

enum LegalDocumentType { terms, privacy, commercial, cancellation }

enum LegalDocumentBodyFormat { markdown, html }

@immutable
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.slug,
    required this.type,
    required this.title,
    required this.version,
    required this.body,
    required this.bodyFormat,
    required this.updatedAt,
    this.summary,
    this.effectiveDate,
    this.shareUrl,
    this.downloadUrl,
  });

  final String id;
  final String slug;
  final LegalDocumentType type;
  final String title;
  final String version;
  final String body;
  final LegalDocumentBodyFormat bodyFormat;
  final String? summary;
  final DateTime? effectiveDate;
  final DateTime updatedAt;
  final String? shareUrl;
  final String? downloadUrl;

  LegalDocument copyWith({
    String? id,
    String? slug,
    LegalDocumentType? type,
    String? title,
    String? version,
    String? body,
    LegalDocumentBodyFormat? bodyFormat,
    String? summary,
    DateTime? effectiveDate,
    DateTime? updatedAt,
    String? shareUrl,
    String? downloadUrl,
  }) {
    return LegalDocument(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      type: type ?? this.type,
      title: title ?? this.title,
      version: version ?? this.version,
      body: body ?? this.body,
      bodyFormat: bodyFormat ?? this.bodyFormat,
      summary: summary ?? this.summary,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      updatedAt: updatedAt ?? this.updatedAt,
      shareUrl: shareUrl ?? this.shareUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is LegalDocument &&
            other.id == id &&
            other.slug == slug &&
            other.type == type &&
            other.title == title &&
            other.version == version &&
            other.body == body &&
            other.bodyFormat == bodyFormat &&
            other.summary == summary &&
            other.effectiveDate == effectiveDate &&
            other.updatedAt == updatedAt &&
            other.shareUrl == shareUrl &&
            other.downloadUrl == downloadUrl);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      slug,
      type,
      title,
      version,
      body,
      bodyFormat,
      summary,
      effectiveDate,
      updatedAt,
      shareUrl,
      downloadUrl,
    );
  }
}
