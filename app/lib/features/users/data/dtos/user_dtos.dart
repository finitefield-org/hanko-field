// ignore_for_file: public_member_api_docs

import 'package:app/core/utils/json_utils.dart';
import 'package:app/features/users/data/models/user_models.dart';

class UserProfileDto {
  const UserProfileDto({
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

  factory UserProfileDto.fromJson(Map<String, Object?> json, {String? id}) {
    return UserProfileDto(
      id: id,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      persona: UserPersonaX.fromJson(json['persona'] as String),
      preferredLang: json['preferredLang'] as String,
      country: json['country'] as String?,
      onboarding: asMap(json['onboarding']),
      marketingOptIn: json['marketingOptIn'] as bool?,
      role: json['role'] != null
          ? UserRoleX.fromJson(json['role'] as String)
          : UserRole.user,
      isActive: json['isActive'] as bool? ?? true,
      deletedAt: parseDateTime(json['deletedAt']),
      piiMasked: json['piiMasked'] as bool? ?? false,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseDateTime(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'displayName': displayName,
    'email': email,
    'phone': phone,
    'avatarUrl': avatarUrl,
    'persona': persona.toJson(),
    'preferredLang': preferredLang,
    'country': country,
    'onboarding': onboarding,
    'marketingOptIn': marketingOptIn,
    'role': role.toJson(),
    'isActive': isActive,
    'deletedAt': deletedAt?.toIso8601String(),
    'piiMasked': piiMasked,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  UserProfile toDomain() {
    return UserProfile(
      id: id,
      displayName: displayName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      persona: persona,
      preferredLang: preferredLang,
      country: country,
      onboarding: onboarding,
      marketingOptIn: marketingOptIn,
      role: role,
      isActive: isActive,
      deletedAt: deletedAt,
      piiMasked: piiMasked,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static UserProfileDto fromDomain(UserProfile profile) {
    return UserProfileDto(
      id: profile.id,
      displayName: profile.displayName,
      email: profile.email,
      phone: profile.phone,
      avatarUrl: profile.avatarUrl,
      persona: profile.persona,
      preferredLang: profile.preferredLang,
      country: profile.country,
      onboarding: profile.onboarding,
      marketingOptIn: profile.marketingOptIn,
      role: profile.role,
      isActive: profile.isActive,
      deletedAt: profile.deletedAt,
      piiMasked: profile.piiMasked,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    );
  }
}

class UserAddressDto {
  const UserAddressDto({
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

  factory UserAddressDto.fromJson(Map<String, Object?> json, {String? id}) {
    return UserAddressDto(
      id: id,
      label: json['label'] as String?,
      recipient: json['recipient'] as String,
      company: json['company'] as String?,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String,
      country: json['country'] as String,
      phone: json['phone'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    'recipient': recipient,
    'company': company,
    'line1': line1,
    'line2': line2,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'country': country,
    'phone': phone,
    'isDefault': isDefault,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  UserAddress toDomain() {
    return UserAddress(
      id: id,
      label: label,
      recipient: recipient,
      company: company,
      line1: line1,
      line2: line2,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      phone: phone,
      isDefault: isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static UserAddressDto fromDomain(UserAddress address) {
    return UserAddressDto(
      id: address.id,
      label: address.label,
      recipient: address.recipient,
      company: address.company,
      line1: address.line1,
      line2: address.line2,
      city: address.city,
      state: address.state,
      postalCode: address.postalCode,
      country: address.country,
      phone: address.phone,
      isDefault: address.isDefault,
      createdAt: address.createdAt,
      updatedAt: address.updatedAt,
    );
  }
}

class PaymentMethodDto {
  const PaymentMethodDto({
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

  factory PaymentMethodDto.fromJson(Map<String, Object?> json, {String? id}) {
    return PaymentMethodDto(
      id: id,
      provider: PaymentProviderX.fromJson(json['provider'] as String),
      methodType: PaymentMethodTypeX.fromJson(json['methodType'] as String),
      brand: json['brand'] as String?,
      last4: json['last4'] as String?,
      expMonth: (json['expMonth'] as num?)?.toInt(),
      expYear: (json['expYear'] as num?)?.toInt(),
      fingerprint: json['fingerprint'] as String?,
      billingName: json['billingName'] as String?,
      providerRef: json['providerRef'] as String,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'provider': provider.toJson(),
    'methodType': methodType.toJson(),
    'brand': brand,
    'last4': last4,
    'expMonth': expMonth,
    'expYear': expYear,
    'fingerprint': fingerprint,
    'billingName': billingName,
    'providerRef': providerRef,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  PaymentMethod toDomain() {
    return PaymentMethod(
      id: id,
      provider: provider,
      methodType: methodType,
      brand: brand,
      last4: last4,
      expMonth: expMonth,
      expYear: expYear,
      fingerprint: fingerprint,
      billingName: billingName,
      providerRef: providerRef,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static PaymentMethodDto fromDomain(PaymentMethod method) {
    return PaymentMethodDto(
      id: method.id,
      provider: method.provider,
      methodType: method.methodType,
      brand: method.brand,
      last4: method.last4,
      expMonth: method.expMonth,
      expYear: method.expYear,
      fingerprint: method.fingerprint,
      billingName: method.billingName,
      providerRef: method.providerRef,
      createdAt: method.createdAt,
      updatedAt: method.updatedAt,
    );
  }
}

class FavoriteDesignDto {
  const FavoriteDesignDto({
    required this.designRef,
    required this.addedAt,
    this.note,
    this.tags = const <String>[],
  });

  final String designRef;
  final String? note;
  final List<String> tags;
  final DateTime addedAt;

  factory FavoriteDesignDto.fromJson(Map<String, Object?> json) {
    return FavoriteDesignDto(
      designRef: json['designRef'] as String,
      note: json['note'] as String?,
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      addedAt:
          parseDateTime(json['addedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'designRef': designRef,
    'note': note,
    'tags': tags,
    'addedAt': addedAt.toIso8601String(),
  };

  FavoriteDesign toDomain() {
    return FavoriteDesign(
      designRef: designRef,
      note: note,
      tags: tags,
      addedAt: addedAt,
    );
  }

  static FavoriteDesignDto fromDomain(FavoriteDesign favorite) {
    return FavoriteDesignDto(
      designRef: favorite.designRef,
      note: favorite.note,
      tags: favorite.tags,
      addedAt: favorite.addedAt,
    );
  }
}
