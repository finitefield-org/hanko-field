import 'package:flutter/foundation.dart';

@immutable
class CatalogData {
  final List<FontOption> fonts;
  final List<MaterialOption> materials;
  final List<CountryOption> countries;

  const CatalogData({
    required this.fonts,
    required this.materials,
    required this.countries,
  });

  static const empty = CatalogData(fonts: [], materials: [], countries: []);
}

enum OrderStep {
  design(1),
  material(2),
  purchase(3);

  const OrderStep(this.value);
  final int value;

  OrderStep next() {
    return switch (this) {
      OrderStep.design => OrderStep.material,
      OrderStep.material => OrderStep.purchase,
      OrderStep.purchase => OrderStep.purchase,
    };
  }

  OrderStep prev() {
    return switch (this) {
      OrderStep.design => OrderStep.design,
      OrderStep.material => OrderStep.design,
      OrderStep.purchase => OrderStep.material,
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

  String localizedLabel(String locale) {
    if (isEnglishLocale(locale)) {
      return switch (this) {
        CandidateGender.unspecified => 'Unspecified',
        CandidateGender.male => 'Male',
        CandidateGender.female => 'Female',
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
class MaterialOption {
  final String key;
  final String label;
  final String description;
  final SealShape shape;
  final String shapeLabel;
  final int price;
  final String photoUrl;
  final String photoAlt;
  final bool hasPhoto;

  const MaterialOption({
    required this.key,
    required this.label,
    required this.description,
    required this.shape,
    required this.shapeLabel,
    required this.price,
    required this.photoUrl,
    required this.photoAlt,
    required this.hasPhoto,
  });
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
  final String sealLine1;
  final String sealLine2;
  final String fontLabel;
  final String shapeLabel;
  final String materialLabel;
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
    required this.sealLine1,
    required this.sealLine2,
    required this.fontLabel,
    required this.shapeLabel,
    required this.materialLabel,
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
