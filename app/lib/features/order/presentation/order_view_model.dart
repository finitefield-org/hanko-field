import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:miniriverpod/miniriverpod.dart';

import '../data/mock_catalog.dart';
import '../domain/order_models.dart';

@immutable
class OrderScreenState {
  static const _noChange = Object();

  final CatalogData catalog;
  final OrderStep step;
  final String sealLine1;
  final String sealLine2;
  final String sealTextError;
  final KanjiStyle kanjiStyle;
  final String selectedFontKey;
  final SealShape shape;
  final String selectedMaterialKey;
  final String selectedCountryCode;
  final String realName;
  final CandidateGender candidateGender;
  final List<KanjiCandidate> suggestions;
  final int? selectedSuggestionIndex;
  final String suggestionsError;
  final String recipientName;
  final String email;
  final String phone;
  final String postalCode;
  final String stateName;
  final String city;
  final String addressLine1;
  final String addressLine2;
  final bool termsAgreed;
  final PurchaseResultData? purchaseResult;
  final String purchaseError;

  const OrderScreenState({
    required this.catalog,
    required this.step,
    required this.sealLine1,
    required this.sealLine2,
    required this.sealTextError,
    required this.kanjiStyle,
    required this.selectedFontKey,
    required this.shape,
    required this.selectedMaterialKey,
    required this.selectedCountryCode,
    required this.realName,
    required this.candidateGender,
    required this.suggestions,
    required this.selectedSuggestionIndex,
    required this.suggestionsError,
    required this.recipientName,
    required this.email,
    required this.phone,
    required this.postalCode,
    required this.stateName,
    required this.city,
    required this.addressLine1,
    required this.addressLine2,
    required this.termsAgreed,
    required this.purchaseResult,
    required this.purchaseError,
  });

  OrderScreenState copyWith({
    CatalogData? catalog,
    OrderStep? step,
    String? sealLine1,
    String? sealLine2,
    String? sealTextError,
    KanjiStyle? kanjiStyle,
    String? selectedFontKey,
    SealShape? shape,
    String? selectedMaterialKey,
    String? selectedCountryCode,
    String? realName,
    CandidateGender? candidateGender,
    List<KanjiCandidate>? suggestions,
    Object? selectedSuggestionIndex = _noChange,
    String? suggestionsError,
    String? recipientName,
    String? email,
    String? phone,
    String? postalCode,
    String? stateName,
    String? city,
    String? addressLine1,
    String? addressLine2,
    bool? termsAgreed,
    Object? purchaseResult = _noChange,
    String? purchaseError,
  }) {
    return OrderScreenState(
      catalog: catalog ?? this.catalog,
      step: step ?? this.step,
      sealLine1: sealLine1 ?? this.sealLine1,
      sealLine2: sealLine2 ?? this.sealLine2,
      sealTextError: sealTextError ?? this.sealTextError,
      kanjiStyle: kanjiStyle ?? this.kanjiStyle,
      selectedFontKey: selectedFontKey ?? this.selectedFontKey,
      shape: shape ?? this.shape,
      selectedMaterialKey: selectedMaterialKey ?? this.selectedMaterialKey,
      selectedCountryCode: selectedCountryCode ?? this.selectedCountryCode,
      realName: realName ?? this.realName,
      candidateGender: candidateGender ?? this.candidateGender,
      suggestions: suggestions ?? this.suggestions,
      selectedSuggestionIndex: identical(selectedSuggestionIndex, _noChange)
          ? this.selectedSuggestionIndex
          : selectedSuggestionIndex as int?,
      suggestionsError: suggestionsError ?? this.suggestionsError,
      recipientName: recipientName ?? this.recipientName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      postalCode: postalCode ?? this.postalCode,
      stateName: stateName ?? this.stateName,
      city: city ?? this.city,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      termsAgreed: termsAgreed ?? this.termsAgreed,
      purchaseResult: identical(purchaseResult, _noChange)
          ? this.purchaseResult
          : purchaseResult as PurchaseResultData?,
      purchaseError: purchaseError ?? this.purchaseError,
    );
  }

  List<FontOption> get visibleFonts {
    return catalog.fonts.where((f) => f.kanjiStyle == kanjiStyle).toList();
  }

  FontOption get selectedFont {
    final visible = visibleFonts;
    final matched = visible.where((f) => f.key == selectedFontKey);
    if (matched.isNotEmpty) {
      return matched.first;
    }
    return visible.first;
  }

  List<MaterialOption> get visibleMaterials {
    return catalog.materials.where((m) => m.shape == shape).toList();
  }

  MaterialOption get selectedMaterial {
    final visible = visibleMaterials;
    final matched = visible.where((m) => m.key == selectedMaterialKey);
    if (matched.isNotEmpty) {
      return matched.first;
    }
    return visible.first;
  }

  CountryOption get selectedCountry {
    final matched = catalog.countries.where(
      (c) => c.code == selectedCountryCode,
    );
    if (matched.isNotEmpty) {
      return matched.first;
    }
    return catalog.countries.first;
  }

  int get subtotal => selectedMaterial.price;
  int get shipping => selectedCountry.shipping;
  int get total => subtotal + shipping;

  String get sealDisplay {
    if (sealLine1.isEmpty) {
      return '-';
    }
    if (sealLine2.isNotEmpty) {
      return '$sealLine1\n$sealLine2';
    }
    return sealLine1;
  }

  KanjiCandidate? get selectedSuggestion {
    final index = selectedSuggestionIndex;
    if (index == null) {
      return null;
    }
    if (index < 0 || index >= suggestions.length) {
      return null;
    }
    return suggestions[index];
  }
}

class OrderViewModel extends Provider<OrderScreenState> {
  OrderViewModel() : super.args(null);

  @override
  OrderScreenState build(Ref ref) {
    final catalog = mockCatalog;
    final defaultStyle = KanjiStyle.japanese;
    final defaultFont = catalog.fonts.firstWhere(
      (font) => font.kanjiStyle == defaultStyle,
      orElse: () => catalog.fonts.first,
    );
    final defaultShape = SealShape.square;
    final defaultMaterial = catalog.materials.firstWhere(
      (material) => material.shape == defaultShape,
      orElse: () => catalog.materials.first,
    );

    return OrderScreenState(
      catalog: catalog,
      step: OrderStep.design,
      sealLine1: '',
      sealLine2: '',
      sealTextError: '',
      kanjiStyle: defaultStyle,
      selectedFontKey: defaultFont.key,
      shape: defaultShape,
      selectedMaterialKey: defaultMaterial.key,
      selectedCountryCode: catalog.countries.first.code,
      realName: '',
      candidateGender: CandidateGender.unspecified,
      suggestions: const [],
      selectedSuggestionIndex: null,
      suggestionsError: '',
      recipientName: '',
      email: '',
      phone: '',
      postalCode: '',
      stateName: '',
      city: '',
      addressLine1: '',
      addressLine2: '',
      termsAgreed: false,
      purchaseResult: null,
      purchaseError: '',
    );
  }

  late final updateSealLine1Mut = mutation<void>(#updateSealLine1);
  late final updateSealLine2Mut = mutation<void>(#updateSealLine2);
  late final toggleWritingModeMut = mutation<void>(#toggleWritingMode);
  late final selectKanjiStyleMut = mutation<void>(#selectKanjiStyle);
  late final selectFontMut = mutation<void>(#selectFont);
  late final selectShapeMut = mutation<void>(#selectShape);
  late final selectMaterialMut = mutation<void>(#selectMaterial);
  late final selectCountryMut = mutation<void>(#selectCountry);
  late final nextStepMut = mutation<void>(#nextStep);
  late final prevStepMut = mutation<void>(#prevStep);
  late final updateRealNameMut = mutation<void>(#updateRealName);
  late final selectCandidateGenderMut = mutation<void>(#selectCandidateGender);
  late final generateSuggestionsMut = mutation<void>(#generateSuggestions);
  late final selectSuggestionMut = mutation<void>(#selectSuggestion);
  late final updateRecipientNameMut = mutation<void>(#updateRecipientName);
  late final updateEmailMut = mutation<void>(#updateEmail);
  late final updatePhoneMut = mutation<void>(#updatePhone);
  late final updatePostalCodeMut = mutation<void>(#updatePostalCode);
  late final updateStateNameMut = mutation<void>(#updateStateName);
  late final updateCityMut = mutation<void>(#updateCity);
  late final updateAddressLine1Mut = mutation<void>(#updateAddressLine1);
  late final updateAddressLine2Mut = mutation<void>(#updateAddressLine2);
  late final setTermsAgreedMut = mutation<void>(#setTermsAgreed);
  late final submitPurchaseMut = mutation<void>(#submitPurchase);

  Call<void, OrderScreenState> updateSealLine1(String value) {
    return mutate(updateSealLine1Mut, (ref) async {
      final current = ref.watch(this);
      final (line1, line2) = _normalizedSealLines(value, current.sealLine2);
      final sealError = _validateSealText(line1: line1, line2: line2);
      ref.state = current.copyWith(
        sealLine1: line1,
        sealLine2: line2,
        sealTextError: sealError,
        purchaseResult: null,
      );
    });
  }

  Call<void, OrderScreenState> updateSealLine2(String value) {
    return mutate(updateSealLine2Mut, (ref) async {
      final current = ref.watch(this);
      final (line1, line2) = _normalizedSealLines(current.sealLine1, value);
      final sealError = _validateSealText(line1: line1, line2: line2);
      ref.state = current.copyWith(
        sealLine1: line1,
        sealLine2: line2,
        sealTextError: sealError,
        purchaseResult: null,
      );
    });
  }

  Call<void, OrderScreenState> toggleWritingMode() {
    return mutate(toggleWritingModeMut, (ref) async {
      final current = ref.watch(this);
      final line1Chars = current.sealLine1.characters.toList();
      final line2Chars = current.sealLine2.characters.toList();

      var nextLine1 = current.sealLine1;
      var nextLine2 = current.sealLine2;

      if (line1Chars.length >= 2 && line2Chars.isEmpty) {
        nextLine1 = line1Chars.take(1).join();
        nextLine2 = line1Chars.skip(1).take(1).join();
      } else if (line1Chars.isNotEmpty && line2Chars.isNotEmpty) {
        nextLine1 = '${line1Chars.first}${line2Chars.first}';
        nextLine2 = '';
      }

      final (line1, line2) = _normalizedSealLines(nextLine1, nextLine2);
      final sealError = _validateSealText(line1: line1, line2: line2);
      ref.state = current.copyWith(
        sealLine1: line1,
        sealLine2: line2,
        sealTextError: sealError,
        purchaseResult: null,
      );
    });
  }

  Call<void, OrderScreenState> selectKanjiStyle(KanjiStyle style) {
    return mutate(selectKanjiStyleMut, (ref) async {
      final current = ref.watch(this);
      final visibleFonts = current.catalog.fonts
          .where((font) => font.kanjiStyle == style)
          .toList();
      final hasSelected = visibleFonts.any(
        (font) => font.key == current.selectedFontKey,
      );
      final nextFontKey = hasSelected
          ? current.selectedFontKey
          : visibleFonts.first.key;
      ref.state = current.copyWith(
        kanjiStyle: style,
        selectedFontKey: nextFontKey,
        selectedSuggestionIndex: null,
      );
    });
  }

  Call<void, OrderScreenState> selectFont(String key) {
    return mutate(selectFontMut, (ref) async {
      final current = ref.watch(this);
      final allowed = current.visibleFonts.any((font) => font.key == key);
      if (!allowed) {
        return;
      }
      ref.state = current.copyWith(selectedFontKey: key);
    });
  }

  Call<void, OrderScreenState> selectShape(SealShape shape) {
    return mutate(selectShapeMut, (ref) async {
      final current = ref.watch(this);
      final visibleMaterials = current.catalog.materials
          .where((material) => material.shape == shape)
          .toList();
      final hasSelected = visibleMaterials.any(
        (material) => material.key == current.selectedMaterialKey,
      );
      final nextMaterialKey = hasSelected
          ? current.selectedMaterialKey
          : visibleMaterials.first.key;
      ref.state = current.copyWith(
        shape: shape,
        selectedMaterialKey: nextMaterialKey,
        purchaseResult: null,
      );
    });
  }

  Call<void, OrderScreenState> selectMaterial(String key) {
    return mutate(selectMaterialMut, (ref) async {
      final current = ref.watch(this);
      final allowed = current.visibleMaterials.any(
        (material) => material.key == key,
      );
      if (!allowed) {
        return;
      }
      ref.state = current.copyWith(
        selectedMaterialKey: key,
        purchaseResult: null,
      );
    });
  }

  Call<void, OrderScreenState> selectCountry(String code) {
    return mutate(selectCountryMut, (ref) async {
      final current = ref.watch(this);
      final allowed = current.catalog.countries.any(
        (country) => country.code == code,
      );
      if (!allowed) {
        return;
      }
      ref.state = current.copyWith(
        selectedCountryCode: code,
        purchaseResult: null,
      );
    });
  }

  Call<void, OrderScreenState> nextStep() {
    return mutate(nextStepMut, (ref) async {
      final current = ref.watch(this);
      if (current.step == OrderStep.design) {
        final sealError = _validateSealText(
          line1: current.sealLine1,
          line2: current.sealLine2,
        );
        if (sealError.isNotEmpty) {
          ref.state = current.copyWith(
            sealTextError: sealError,
            step: OrderStep.design,
          );
          return;
        }
      }
      ref.state = current.copyWith(step: current.step.next());
    });
  }

  Call<void, OrderScreenState> prevStep() {
    return mutate(prevStepMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(step: current.step.prev());
    });
  }

  Call<void, OrderScreenState> updateRealName(String value) {
    return mutate(updateRealNameMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(realName: value);
    });
  }

  Call<void, OrderScreenState> selectCandidateGender(CandidateGender gender) {
    return mutate(selectCandidateGenderMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(candidateGender: gender);
    });
  }

  Call<void, OrderScreenState> generateSuggestions() {
    return mutate(generateSuggestionsMut, (ref) async {
      final current = ref.watch(this);
      final realName = current.realName.trim();
      if (realName.isEmpty) {
        ref.state = current.copyWith(
          suggestions: const [],
          selectedSuggestionIndex: null,
          suggestionsError: '候補を表示するには本名を入力してください。',
        );
        return;
      }

      final suggestions = _mockSuggestions(
        realName: realName,
        style: current.kanjiStyle,
        gender: current.candidateGender,
      );

      ref.state = current.copyWith(
        suggestions: suggestions,
        selectedSuggestionIndex: suggestions.isEmpty ? null : 0,
        suggestionsError: '',
      );
    });
  }

  Call<void, OrderScreenState> selectSuggestion(int index) {
    return mutate(selectSuggestionMut, (ref) async {
      final current = ref.watch(this);
      if (index < 0 || index >= current.suggestions.length) {
        return;
      }

      final candidate = current.suggestions[index];
      final sourceLine1 = candidate.line1.isNotEmpty
          ? candidate.line1
          : candidate.kanji;
      final sourceLine2 = candidate.line2;
      final (line1, line2) = _normalizedSealLines(sourceLine1, sourceLine2);
      final sealError = _validateSealText(line1: line1, line2: line2);

      ref.state = current.copyWith(
        selectedSuggestionIndex: index,
        sealLine1: line1,
        sealLine2: line2,
        sealTextError: sealError,
        purchaseResult: null,
      );
    });
  }

  Call<void, OrderScreenState> updateRecipientName(String value) {
    return mutate(updateRecipientNameMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(recipientName: value, purchaseResult: null);
    });
  }

  Call<void, OrderScreenState> updateEmail(String value) {
    return mutate(updateEmailMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(email: value, purchaseResult: null);
    });
  }

  Call<void, OrderScreenState> updatePhone(String value) {
    return mutate(updatePhoneMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(phone: value, purchaseResult: null);
    });
  }

  Call<void, OrderScreenState> updatePostalCode(String value) {
    return mutate(updatePostalCodeMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(postalCode: value, purchaseResult: null);
    });
  }

  Call<void, OrderScreenState> updateStateName(String value) {
    return mutate(updateStateNameMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(stateName: value, purchaseResult: null);
    });
  }

  Call<void, OrderScreenState> updateCity(String value) {
    return mutate(updateCityMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(city: value, purchaseResult: null);
    });
  }

  Call<void, OrderScreenState> updateAddressLine1(String value) {
    return mutate(updateAddressLine1Mut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(addressLine1: value, purchaseResult: null);
    });
  }

  Call<void, OrderScreenState> updateAddressLine2(String value) {
    return mutate(updateAddressLine2Mut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(addressLine2: value, purchaseResult: null);
    });
  }

  Call<void, OrderScreenState> setTermsAgreed(bool value) {
    return mutate(setTermsAgreedMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(termsAgreed: value, purchaseResult: null);
    });
  }

  Call<void, OrderScreenState> submitPurchase() {
    return mutate(submitPurchaseMut, (ref) async {
      final current = ref.watch(this);

      final sealError = _validateSealText(
        line1: current.sealLine1,
        line2: current.sealLine2,
      );
      if (sealError.isNotEmpty) {
        ref.state = current.copyWith(
          sealTextError: sealError,
          purchaseError: sealError,
          purchaseResult: null,
        );
        return;
      }

      final purchaseError = _validatePurchase(current);
      if (purchaseError.isNotEmpty) {
        ref.state = current.copyWith(
          purchaseError: purchaseError,
          purchaseResult: null,
        );
        return;
      }

      final next = current.copyWith(
        purchaseError: '',
        purchaseResult: PurchaseResultData(
          sealLine1: current.sealLine1,
          sealLine2: current.sealLine2,
          fontLabel: current.selectedFont.label,
          shapeLabel: current.shape.label,
          materialLabel: current.selectedMaterial.label,
          stripeName: current.recipientName.trim(),
          stripePhone: current.phone.trim(),
          countryLabel: current.selectedCountry.label,
          postalCode: current.postalCode.trim(),
          state: current.stateName.trim(),
          city: current.city.trim(),
          addressLine1: current.addressLine1.trim(),
          addressLine2: current.addressLine2.trim(),
          subtotal: current.subtotal,
          shipping: current.shipping,
          total: current.total,
          email: current.email.trim(),
          sourceLabel: 'Mock',
          isMock: true,
        ),
      );

      ref.state = next;
    });
  }
}

final orderViewModel = OrderViewModel();

const _maxSealCharTotal = 2;

(String, String) _normalizedSealLines(String first, String second) {
  final trimmedFirst = first.trim();
  final trimmedSecond = second.trim();

  final firstChars = trimmedFirst.characters.take(_maxSealCharTotal).toString();
  final remaining = _maxSealCharTotal - firstChars.characters.length;
  final secondChars = remaining <= 0
      ? ''
      : trimmedSecond.characters.take(remaining).toString();

  return (firstChars, secondChars);
}

String _validateSealText({required String line1, required String line2}) {
  if (line1.characters.isEmpty) {
    return 'お名前を入力してください。';
  }

  if (_containsWhitespace(line1)) {
    return '1行目に空白は使えません。';
  }

  if (line2.isNotEmpty && _containsWhitespace(line2)) {
    return '2行目に空白は使えません。';
  }

  if (line1.characters.length + line2.characters.length > _maxSealCharTotal) {
    return '印影テキストは1行目と2行目の合計で2文字以内で入力してください。';
  }

  return '';
}

bool _containsWhitespace(String value) {
  return RegExp(r'\s', unicode: true).hasMatch(value);
}

String _validatePurchase(OrderScreenState state) {
  if (state.recipientName.trim().isEmpty) {
    return 'お届け先氏名を入力してください。';
  }
  if (state.email.trim().isEmpty) {
    return 'メールアドレスを入力してください。';
  }
  if (!state.email.contains('@')) {
    return 'メールアドレスの形式が正しくありません。';
  }
  if (state.phone.trim().isEmpty) {
    return '電話番号を入力してください。';
  }
  if (state.postalCode.trim().isEmpty) {
    return '郵便番号を入力してください。';
  }
  if (state.stateName.trim().isEmpty) {
    return '都道府県 / 州を入力してください。';
  }
  if (state.city.trim().isEmpty) {
    return '市区町村 / City を入力してください。';
  }
  if (state.addressLine1.trim().isEmpty) {
    return '住所1を入力してください。';
  }
  if (!state.termsAgreed) {
    return '利用規約に同意してください。';
  }
  return '';
}

List<KanjiCandidate> _mockSuggestions({
  required String realName,
  required KanjiStyle style,
  required CandidateGender gender,
}) {
  final genderHint = switch (gender) {
    CandidateGender.male => '男性イメージを重視しています。',
    CandidateGender.female => '女性イメージを重視しています。',
    CandidateGender.unspecified => '性別指定なしで提案しています。',
  };

  final firstWord = realName.split(RegExp(r'\s+')).first;

  final base = switch (style) {
    KanjiStyle.japanese => <KanjiCandidate>[
      KanjiCandidate(
        kanji: '光真',
        line1: '光真',
        line2: '',
        reading: 'koma',
        reason: '$firstWord の音に近く、明るさを感じる組み合わせです。$genderHint',
      ),
      KanjiCandidate(
        kanji: '雅蓮',
        line1: '雅蓮',
        line2: '',
        reading: 'garen',
        reason: '上品で印影バランスが安定しやすい構成です。$genderHint',
      ),
      KanjiCandidate(
        kanji: '成和',
        line1: '成和',
        line2: '',
        reading: 'seiwa',
        reason: '穏やかで信頼感のある響きに寄せています。$genderHint',
      ),
      KanjiCandidate(
        kanji: '誠道',
        line1: '誠道',
        line2: '',
        reading: 'seido',
        reason: '力強さと誠実さの印象を両立しやすい候補です。$genderHint',
      ),
      KanjiCandidate(
        kanji: '悠仁',
        line1: '悠仁',
        line2: '',
        reading: 'yuji',
        reason: '長く使う印鑑向けに落ち着いた字面でまとめています。$genderHint',
      ),
      KanjiCandidate(
        kanji: '景香',
        line1: '景香',
        line2: '',
        reading: 'keika',
        reason: '読みやすさと印面の収まりを優先した候補です。$genderHint',
      ),
    ],
    KanjiStyle.chinese => <KanjiCandidate>[
      KanjiCandidate(
        kanji: '明辰',
        line1: '明辰',
        line2: '',
        reading: 'míng chén',
        reason: '$firstWord の発音傾向に合わせ、簡潔な字面で構成しています。$genderHint',
      ),
      KanjiCandidate(
        kanji: '文澤',
        line1: '文澤',
        line2: '',
        reading: 'wén zé',
        reason: '知的な印象と視認性のバランスを重視した候補です。$genderHint',
      ),
      KanjiCandidate(
        kanji: '安祐',
        line1: '安祐',
        line2: '',
        reading: 'ān yòu',
        reason: '穏やかで縁起のよい意味を優先して選定しています。$genderHint',
      ),
      KanjiCandidate(
        kanji: '子宣',
        line1: '子宣',
        line2: '',
        reading: 'zǐ xuān',
        reason: '輪郭がはっきりし、丸印でも崩れにくい組み合わせです。$genderHint',
      ),
      KanjiCandidate(
        kanji: '景恩',
        line1: '景恩',
        line2: '',
        reading: 'jǐng ēn',
        reason: '柔らかい響きとフォーマルさを両立する構成です。$genderHint',
      ),
      KanjiCandidate(
        kanji: '嘉寧',
        line1: '嘉寧',
        line2: '',
        reading: 'jiā níng',
        reason: '画数バランスが整いやすく実印用途にも向きます。$genderHint',
      ),
    ],
    KanjiStyle.taiwanese => <KanjiCandidate>[
      KanjiCandidate(
        kanji: '承宇',
        line1: '承宇',
        line2: '',
        reading: 'chéng yǔ',
        reason: '$firstWord の音節感に寄せ、現代的な字面で構成しています。$genderHint',
      ),
      KanjiCandidate(
        kanji: '語晴',
        line1: '語晴',
        line2: '',
        reading: 'yǔ qíng',
        reason: '台湾向けで好まれる柔らかい印象の漢字を選びました。$genderHint',
      ),
      KanjiCandidate(
        kanji: '柏睿',
        line1: '柏睿',
        line2: '',
        reading: 'bó ruì',
        reason: '実用性と個性のバランスを取りやすい候補です。$genderHint',
      ),
      KanjiCandidate(
        kanji: '立宸',
        line1: '立宸',
        line2: '',
        reading: 'lì chén',
        reason: '縦書きでも横書きでも形が安定しやすい組み合わせです。$genderHint',
      ),
      KanjiCandidate(
        kanji: '映彤',
        line1: '映彤',
        line2: '',
        reading: 'yìng tóng',
        reason: '明るさと華やかさを重視したスタイル候補です。$genderHint',
      ),
      KanjiCandidate(
        kanji: '岳霖',
        line1: '岳霖',
        line2: '',
        reading: 'yuè lín',
        reason: '重厚感のある文字構成で印影の存在感を出しやすいです。$genderHint',
      ),
    ],
  };

  return base;
}

String normalizePinyinWithoutTone(String input) {
  const toneMap = {
    'ā': 'a',
    'á': 'a',
    'ǎ': 'a',
    'à': 'a',
    'ē': 'e',
    'é': 'e',
    'ě': 'e',
    'è': 'e',
    'ī': 'i',
    'í': 'i',
    'ǐ': 'i',
    'ì': 'i',
    'ō': 'o',
    'ó': 'o',
    'ǒ': 'o',
    'ò': 'o',
    'ū': 'u',
    'ú': 'u',
    'ǔ': 'u',
    'ù': 'u',
    'ǖ': 'ü',
    'ǘ': 'ü',
    'ǚ': 'ü',
    'ǜ': 'ü',
    'ń': 'n',
    'ň': 'n',
    'ǹ': 'n',
    'ḿ': 'm',
  };

  final normalized = input
      .trim()
      .toLowerCase()
      .split('')
      .map((char) => toneMap[char] ?? char)
      .join()
      .replaceAll('u:', 'ü')
      .replaceAll(RegExp(r'[1-5]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return normalized;
}
