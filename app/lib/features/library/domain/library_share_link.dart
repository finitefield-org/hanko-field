import 'package:flutter/foundation.dart';

enum LibraryShareLinkStatus { active, expired, revoked }

@immutable
class LibraryShareLink {
  const LibraryShareLink({
    required this.id,
    required this.url,
    required this.status,
    required this.createdAt,
    this.label,
    this.expiresAt,
    this.lastAccessedAt,
    this.revokedAt,
    this.accessCount = 0,
    this.maxAccessCount,
  });

  final String id;
  final String url;
  final LibraryShareLinkStatus status;
  final DateTime createdAt;
  final String? label;
  final DateTime? expiresAt;
  final DateTime? lastAccessedAt;
  final DateTime? revokedAt;
  final int accessCount;
  final int? maxAccessCount;

  bool get hasExpiry => expiresAt != null;
  bool get hasBeenUsed => accessCount > 0;

  LibraryShareLink copyWith({
    String? id,
    String? url,
    LibraryShareLinkStatus? status,
    DateTime? createdAt,
    String? label,
    DateTime? expiresAt,
    DateTime? lastAccessedAt,
    DateTime? revokedAt,
    int? accessCount,
    int? maxAccessCount,
  }) {
    return LibraryShareLink(
      id: id ?? this.id,
      url: url ?? this.url,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      label: label ?? this.label,
      expiresAt: expiresAt ?? this.expiresAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      accessCount: accessCount ?? this.accessCount,
      maxAccessCount: maxAccessCount ?? this.maxAccessCount,
    );
  }
}
