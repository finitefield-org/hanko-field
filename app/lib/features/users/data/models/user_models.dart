// ignore_for_file: public_member_api_docs

import 'package:collection/collection.dart';

enum UserPersona { foreigner, japanese }

extension UserPersonaX on UserPersona {
  String toJson() => switch (this) {
    UserPersona.foreigner => 'foreigner',
    UserPersona.japanese => 'japanese',
  };

  static UserPersona fromJson(String value) {
    switch (value) {
      case 'foreigner':
        return UserPersona.foreigner;
      case 'japanese':
        return UserPersona.japanese;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported persona');
  }
}

enum UserRole { user, staff, admin }

extension UserRoleX on UserRole {
  String toJson() => switch (this) {
    UserRole.user => 'user',
    UserRole.staff => 'staff',
    UserRole.admin => 'admin',
  };

  static UserRole fromJson(String value) {
    switch (value) {
      case 'user':
        return UserRole.user;
      case 'staff':
        return UserRole.staff;
      case 'admin':
        return UserRole.admin;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported role');
  }
}

class UserProfile {
  const UserProfile({
    required this.persona,
    required this.preferredLang,
    required this.isActive,
    required this.piiMasked,
    required this.createdAt,
    required this.updatedAt,
    this.id,
    this.displayName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.country,
    this.onboarding,
    this.marketingOptIn,
    this.role = UserRole.user,
    this.deletedAt,
  });

  final String? id;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final UserPersona persona;
  final String preferredLang;
  final String? country;
  final Map<String, Object?>? onboarding;
  final bool? marketingOptIn;
  final UserRole role;
  final bool isActive;
  final DateTime? deletedAt;
  final bool piiMasked;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? phone,
    String? avatarUrl,
    UserPersona? persona,
    String? preferredLang,
    String? country,
    Map<String, Object?>? onboarding,
    bool? marketingOptIn,
    UserRole? role,
    bool? isActive,
    DateTime? deletedAt,
    bool? piiMasked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      persona: persona ?? this.persona,
      preferredLang: preferredLang ?? this.preferredLang,
      country: country ?? this.country,
      onboarding: onboarding ?? this.onboarding,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      deletedAt: deletedAt ?? this.deletedAt,
      piiMasked: piiMasked ?? this.piiMasked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const deepEq = DeepCollectionEquality();
    return identical(this, other) ||
        (other is UserProfile &&
            other.id == id &&
            other.displayName == displayName &&
            other.email == email &&
            other.phone == phone &&
            other.avatarUrl == avatarUrl &&
            other.persona == persona &&
            other.preferredLang == preferredLang &&
            other.country == country &&
            deepEq.equals(other.onboarding, onboarding) &&
            other.marketingOptIn == marketingOptIn &&
            other.role == role &&
            other.isActive == isActive &&
            other.deletedAt == deletedAt &&
            other.piiMasked == piiMasked &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode {
    const deepEq = DeepCollectionEquality();
    return Object.hashAll([
      id,
      displayName,
      email,
      phone,
      avatarUrl,
      persona,
      preferredLang,
      country,
      deepEq.hash(onboarding),
      marketingOptIn,
      role,
      isActive,
      deletedAt,
      piiMasked,
      createdAt,
      updatedAt,
    ]);
  }
}

class UserAddress {
  const UserAddress({
    required this.recipient,
    required this.line1,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.createdAt,
    this.id,
    this.label,
    this.company,
    this.line2,
    this.state,
    this.phone,
    this.isDefault = false,
    this.updatedAt,
  });

  final String? id;
  final String? label;
  final String recipient;
  final String? company;
  final String line1;
  final String? line2;
  final String city;
  final String? state;
  final String postalCode;
  final String country;
  final String? phone;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserAddress copyWith({
    String? id,
    String? label,
    String? recipient,
    String? company,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? phone,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      recipient: recipient ?? this.recipient,
      company: company ?? this.company,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UserAddress &&
            other.id == id &&
            other.label == label &&
            other.recipient == recipient &&
            other.company == company &&
            other.line1 == line1 &&
            other.line2 == line2 &&
            other.city == city &&
            other.state == state &&
            other.postalCode == postalCode &&
            other.country == country &&
            other.phone == phone &&
            other.isDefault == isDefault &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    recipient,
    company,
    line1,
    line2,
    city,
    state,
    postalCode,
    country,
    phone,
    isDefault,
    createdAt,
    updatedAt,
  );
}

enum PaymentProvider { stripe, paypal, other }

extension PaymentProviderX on PaymentProvider {
  String toJson() => switch (this) {
    PaymentProvider.stripe => 'stripe',
    PaymentProvider.paypal => 'paypal',
    PaymentProvider.other => 'other',
  };

  static PaymentProvider fromJson(String value) {
    switch (value) {
      case 'stripe':
        return PaymentProvider.stripe;
      case 'paypal':
        return PaymentProvider.paypal;
      case 'other':
        return PaymentProvider.other;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported payment provider');
  }
}

enum PaymentMethodType { card, wallet, bank, other }

extension PaymentMethodTypeX on PaymentMethodType {
  String toJson() => switch (this) {
    PaymentMethodType.card => 'card',
    PaymentMethodType.wallet => 'wallet',
    PaymentMethodType.bank => 'bank',
    PaymentMethodType.other => 'other',
  };

  static PaymentMethodType fromJson(String value) {
    switch (value) {
      case 'card':
        return PaymentMethodType.card;
      case 'wallet':
        return PaymentMethodType.wallet;
      case 'bank':
        return PaymentMethodType.bank;
      case 'other':
        return PaymentMethodType.other;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported method type');
  }
}

class PaymentMethod {
  const PaymentMethod({
    required this.provider,
    required this.methodType,
    required this.providerRef,
    required this.createdAt,
    this.id,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.fingerprint,
    this.billingName,
    this.updatedAt,
  });

  final String? id;
  final PaymentProvider provider;
  final PaymentMethodType methodType;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final String? fingerprint;
  final String? billingName;
  final String providerRef;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PaymentMethod copyWith({
    String? id,
    PaymentProvider? provider,
    PaymentMethodType? methodType,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
    String? fingerprint,
    String? billingName,
    String? providerRef,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      methodType: methodType ?? this.methodType,
      brand: brand ?? this.brand,
      last4: last4 ?? this.last4,
      expMonth: expMonth ?? this.expMonth,
      expYear: expYear ?? this.expYear,
      fingerprint: fingerprint ?? this.fingerprint,
      billingName: billingName ?? this.billingName,
      providerRef: providerRef ?? this.providerRef,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PaymentMethod &&
            other.id == id &&
            other.provider == provider &&
            other.methodType == methodType &&
            other.brand == brand &&
            other.last4 == last4 &&
            other.expMonth == expMonth &&
            other.expYear == expYear &&
            other.fingerprint == fingerprint &&
            other.billingName == billingName &&
            other.providerRef == providerRef &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    methodType,
    brand,
    last4,
    expMonth,
    expYear,
    fingerprint,
    billingName,
    providerRef,
    createdAt,
    updatedAt,
  );
}

class FavoriteDesign {
  const FavoriteDesign({
    required this.designRef,
    required this.addedAt,
    this.note,
    this.tags = const <String>[],
  });

  final String designRef;
  final String? note;
  final List<String> tags;
  final DateTime addedAt;

  FavoriteDesign copyWith({
    String? designRef,
    String? note,
    List<String>? tags,
    DateTime? addedAt,
  }) {
    return FavoriteDesign(
      designRef: designRef ?? this.designRef,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is FavoriteDesign &&
            other.designRef == designRef &&
            other.note == note &&
            listEq.equals(other.tags, tags) &&
            other.addedAt == addedAt);
  }

  @override
  int get hashCode => Object.hash(
    designRef,
    note,
    const ListEquality<String>().hash(tags),
    addedAt,
  );
}
