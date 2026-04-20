import 'package:flutter/foundation.dart';

@immutable
class CatalogData {
  final List<FontOption> fonts;
  final List<StoneListingOption> stoneListings;
  final List<CountryOption> countries;

  const CatalogData({
    required this.fonts,
    required this.stoneListings,
    required this.countries,
  });

  static const empty = CatalogData(fonts: [], stoneListings: [], countries: []);
}

enum OrderStep {
  design(1),
  listing(2),
  purchase(3);

  const OrderStep(this.value);
  final int value;

  static OrderStep fromValue(int value) {
    return switch (value) {
      2 => OrderStep.listing,
      3 => OrderStep.purchase,
      _ => OrderStep.design,
    };
  }

  OrderStep next() {
    return switch (this) {
      OrderStep.design => OrderStep.listing,
      OrderStep.listing => OrderStep.purchase,
      OrderStep.purchase => OrderStep.purchase,
    };
  }

  OrderStep prev() {
    return switch (this) {
      OrderStep.design => OrderStep.design,
      OrderStep.listing => OrderStep.design,
      OrderStep.purchase => OrderStep.listing,
    };
  }
}

enum KanjiStyle {
  japanese('japanese', '日本スタイル'),
  chinese('chinese', '中国スタイル'),
  taiwanese('taiwanese', '台湾スタイル');

  const KanjiStyle(this.code, this.label);
  final String code;
  final String label;

  bool get isChineseStyle => this == chinese || this == taiwanese;

  String localizedLabel(String locale) {
    if (isEnglishLocale(locale)) {
      return switch (this) {
        KanjiStyle.japanese => 'Japanese style',
        KanjiStyle.chinese => 'Chinese style',
        KanjiStyle.taiwanese => 'Taiwanese style',
      };
    }
    return label;
  }

  static KanjiStyle fromCode(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'chinese' || 'china' || 'cn' => KanjiStyle.chinese,
      'taiwanese' || 'taiwan' || 'tw' => KanjiStyle.taiwanese,
      _ => KanjiStyle.japanese,
    };
  }
}

enum CandidateGender {
  unspecified('unspecified', '選択なし'),
  male('male', '男性'),
  female('female', '女性');

  const CandidateGender(this.code, this.label);
  final String code;
  final String label;

  static CandidateGender fromCode(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'male' => CandidateGender.male,
      'female' => CandidateGender.female,
      _ => CandidateGender.unspecified,
    };
  }

  String localizedLabel(String locale) {
    if (isEnglishLocale(locale)) {
      return switch (this) {
        CandidateGender.unspecified => 'No preference',
        CandidateGender.male => 'Masculine',
        CandidateGender.female => 'Feminine',
      };
    }
    return label;
  }
}

enum SealShape {
  square('square', '角印', '角'),
  round('round', '丸印', '丸');

  const SealShape(this.code, this.label, this.previewLabel);
  final String code;
  final String label;
  final String previewLabel;

  String localizedLabel(String locale) {
    if (isEnglishLocale(locale)) {
      return switch (this) {
        SealShape.square => 'Square',
        SealShape.round => 'Round',
      };
    }
    return label;
  }

  String localizedPreviewLabel(String locale) {
    if (isEnglishLocale(locale)) {
      return switch (this) {
        SealShape.square => 'Square',
        SealShape.round => 'Round',
      };
    }
    return previewLabel;
  }

  static SealShape fromCode(String raw) {
    return raw.trim().toLowerCase() == 'round'
        ? SealShape.round
        : SealShape.square;
  }
}

@immutable
class FontOption {
  final String key;
  final String label;
  final String family;
  final KanjiStyle kanjiStyle;

  const FontOption({
    required this.key,
    required this.label,
    required this.family,
    required this.kanjiStyle,
  });
}

@immutable
class StoneListingOption {
  final String key;
  final String listingCode;
  final String title;
  final String description;
  final String story;
  final List<String> supportedSealShapes;
  final int price;
  final String photoUrl;
  final String photoAlt;
  final bool hasPhoto;

  const StoneListingOption({
    required this.key,
    required this.listingCode,
    required this.title,
    required this.description,
    required this.story,
    required this.supportedSealShapes,
    required this.price,
    required this.photoUrl,
    required this.photoAlt,
    required this.hasPhoto,
  });

  bool supportsShape(SealShape shape) {
    if (supportedSealShapes.isEmpty) {
      return true;
    }
    return supportedSealShapes.any(
      (supportedShape) => supportedShape.trim().toLowerCase() == shape.code,
    );
  }
}

@immutable
class CountryOption {
  final String code;
  final String label;
  final int shipping;

  const CountryOption({
    required this.code,
    required this.label,
    required this.shipping,
  });
}

@immutable
class KanjiCandidate {
  final String kanji;
  final String line1;
  final String line2;
  final String reading;
  final String reason;

  const KanjiCandidate({
    required this.kanji,
    required this.line1,
    required this.line2,
    required this.reading,
    required this.reason,
  });
}

@immutable
class PurchaseResultData {
  final String listingLabel;
  final String sealLine1;
  final String sealLine2;
  final String fontLabel;
  final String shapeLabel;
  final String stripeName;
  final String stripePhone;
  final String countryLabel;
  final String postalCode;
  final String state;
  final String city;
  final String addressLine1;
  final String addressLine2;
  final int subtotal;
  final int shipping;
  final int total;
  final String email;
  final String sourceLabel;
  final String currency;
  final String orderId;
  final String checkoutSessionId;
  final String checkoutUrl;
  final String paymentIntentId;

  const PurchaseResultData({
    required this.listingLabel,
    required this.sealLine1,
    required this.sealLine2,
    required this.fontLabel,
    required this.shapeLabel,
    required this.stripeName,
    required this.stripePhone,
    required this.countryLabel,
    required this.postalCode,
    required this.state,
    required this.city,
    required this.addressLine1,
    required this.addressLine2,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.email,
    required this.sourceLabel,
    required this.currency,
    required this.orderId,
    required this.checkoutSessionId,
    required this.checkoutUrl,
    required this.paymentIntentId,
  });
}

@immutable
class OrderDraftData {
  static const int version = 2;

  final int stepValue;
  final String sealLine1;
  final String sealLine2;
  final String kanjiStyleCode;
  final String selectedFontKey;
  final String shapeCode;
  final String selectedStoneListingKey;
  final String selectedCountryCode;
  final String realName;
  final String candidateGenderCode;
  final String recipientName;
  final String email;
  final String phone;
  final String postalCode;
  final String stateName;
  final String city;
  final String addressLine1;
  final String addressLine2;
  final bool termsAgreed;

  const OrderDraftData({
    required this.stepValue,
    required this.sealLine1,
    required this.sealLine2,
    required this.kanjiStyleCode,
    required this.selectedFontKey,
    required this.shapeCode,
    required this.selectedStoneListingKey,
    required this.selectedCountryCode,
    required this.realName,
    required this.candidateGenderCode,
    required this.recipientName,
    required this.email,
    required this.phone,
    required this.postalCode,
    required this.stateName,
    required this.city,
    required this.addressLine1,
    required this.addressLine2,
    required this.termsAgreed,
  });

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'step': stepValue,
      'seal_line1': sealLine1,
      'seal_line2': sealLine2,
      'kanji_style': kanjiStyleCode,
      'selected_font_key': selectedFontKey,
      'shape': shapeCode,
      'selected_stone_listing_key': selectedStoneListingKey,
      'selected_country_code': selectedCountryCode,
      'real_name': realName,
      'candidate_gender': candidateGenderCode,
      'recipient_name': recipientName,
      'email': email,
      'phone': phone,
      'postal_code': postalCode,
      'state_name': stateName,
      'city': city,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'terms_agreed': termsAgreed,
    };
  }

  factory OrderDraftData.fromJson(Map<String, Object?> json) {
    return OrderDraftData(
      stepValue: _asInt(json['step']),
      sealLine1: _asString(json['seal_line1']),
      sealLine2: _asString(json['seal_line2']),
      kanjiStyleCode: _asString(json['kanji_style']),
      selectedFontKey: _asString(json['selected_font_key']),
      shapeCode: _asString(json['shape']),
      selectedStoneListingKey: _asString(json['selected_stone_listing_key']),
      selectedCountryCode: _asString(json['selected_country_code']),
      realName: _asString(json['real_name']),
      candidateGenderCode: _asString(json['candidate_gender']),
      recipientName: _asString(json['recipient_name']),
      email: _asString(json['email']),
      phone: _asString(json['phone']),
      postalCode: _asString(json['postal_code']),
      stateName: _asString(json['state_name']),
      city: _asString(json['city']),
      addressLine1: _asString(json['address_line1']),
      addressLine2: _asString(json['address_line2']),
      termsAgreed: _asBool(json['terms_agreed']),
    );
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

String _asString(Object? value) {
  return value?.toString().trim() ?? '';
}

bool _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'on';
  }
  return false;
}

String formatMoney(int amount, String currency) {
  final normalizedCurrency = currency.trim().toUpperCase();
  final sign = amount < 0 ? '-' : '';
  final absolute = amount.abs();

  final isZeroDecimal =
      normalizedCurrency == 'JPY' || normalizedCurrency == 'KRW';
  if (isZeroDecimal) {
    return '$sign$normalizedCurrency ${_groupedNumber(absolute)}';
  }

  final whole = absolute ~/ 100;
  final fraction = absolute % 100;
  return '$sign$normalizedCurrency ${_groupedNumber(whole)}.${fraction.toString().padLeft(2, '0')}';
}

String _groupedNumber(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(raw[i]);
  }
  return buffer.toString();
}

bool isEnglishLocale(String locale) {
  return normalizeUiLocale(locale) == 'en';
}

String normalizeUiLocale(String locale) {
  final normalized = locale.trim().toLowerCase();
  if (normalized.startsWith('en')) {
    return 'en';
  }
  return 'ja';
}

String localizedUiText(
  String locale, {
  required String ja,
  required String en,
}) {
  return isEnglishLocale(locale) ? en : ja;
}
