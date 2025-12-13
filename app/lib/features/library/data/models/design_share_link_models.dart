// ignore_for_file: public_member_api_docs

class DesignShareLink {
  const DesignShareLink({
    required this.id,
    required this.url,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
    required this.openCount,
    this.lastOpenedAt,
  });

  final String id;
  final String url;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final int openCount;
  final DateTime? lastOpenedAt;

  bool get isRevoked => revokedAt != null;

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  bool get isActive => !isRevoked && !isExpired;

  DesignShareLink copyWith({
    String? id,
    String? url,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? revokedAt,
    int? openCount,
    DateTime? lastOpenedAt,
  }) {
    return DesignShareLink(
      id: id ?? this.id,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      revokedAt: revokedAt ?? this.revokedAt,
      openCount: openCount ?? this.openCount,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  static DesignShareLink fromJson(Map<String, Object?> json) {
    return DesignShareLink(
      id: (json['id'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAtMs'] as int?) ?? 0,
      ),
      expiresAt: json['expiresAtMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['expiresAtMs']! as int),
      revokedAt: json['revokedAtMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['revokedAtMs']! as int),
      openCount: (json['openCount'] as int?) ?? 0,
      lastOpenedAt: json['lastOpenedAtMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['lastOpenedAtMs']! as int),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'url': url,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'expiresAtMs': expiresAt?.millisecondsSinceEpoch,
      'revokedAtMs': revokedAt?.millisecondsSinceEpoch,
      'openCount': openCount,
      'lastOpenedAtMs': lastOpenedAt?.millisecondsSinceEpoch,
    };
  }
}
