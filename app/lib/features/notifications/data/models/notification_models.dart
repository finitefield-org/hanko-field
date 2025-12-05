// ignore_for_file: public_member_api_docs

enum NotificationCategory {
  order,
  design,
  promotion,
  support,
  system,
  security,
}

extension NotificationCategoryX on NotificationCategory {
  String toJson() => switch (this) {
    NotificationCategory.order => 'order',
    NotificationCategory.design => 'design',
    NotificationCategory.promotion => 'promotion',
    NotificationCategory.support => 'support',
    NotificationCategory.system => 'system',
    NotificationCategory.security => 'security',
  };

  static NotificationCategory fromJson(String value) {
    switch (value) {
      case 'order':
        return NotificationCategory.order;
      case 'design':
        return NotificationCategory.design;
      case 'promotion':
        return NotificationCategory.promotion;
      case 'support':
        return NotificationCategory.support;
      case 'system':
        return NotificationCategory.system;
      case 'security':
        return NotificationCategory.security;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported notification type');
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    required this.target,
    this.ctaLabel,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime createdAt;
  final String target;
  final String? ctaLabel;
  final bool read;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationCategory? category,
    DateTime? createdAt,
    String? target,
    String? ctaLabel,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      target: target ?? this.target,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      read: read ?? this.read,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AppNotification &&
            other.id == id &&
            other.title == title &&
            other.body == body &&
            other.category == category &&
            other.createdAt == createdAt &&
            other.target == target &&
            other.ctaLabel == ctaLabel &&
            other.read == read);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    body,
    category,
    createdAt,
    target,
    ctaLabel,
    read,
  ]);
}
