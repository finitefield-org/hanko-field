import 'dart:math';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:miniriverpod/miniriverpod.dart';

import '../../../app/config/app_runtime_config.dart';
import '../data/order_api_repository.dart';
import '../domain/order_models.dart';

@immutable
class OrderScreenState {
  static const _noChange = Object();

  final CatalogData catalog;
  final bool isLoadingCatalog;
  final String catalogError;
  final String locale;
  final String currency;
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
  final bool isGeneratingSuggestions;
  final String recipientName;
  final String email;
  final String phone;
  final String postalCode;
  final String stateName;
  final String city;
  final String addressLine1;
  final String addressLine2;
  final bool termsAgreed;
  final bool isSubmittingPurchase;
  final PurchaseResultData? purchaseResult;
  final String purchaseError;

  const OrderScreenState({
    required this.catalog,
    required this.isLoadingCatalog,
    required this.catalogError,
    required this.locale,
    required this.currency,
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
    required this.isGeneratingSuggestions,
    required this.recipientName,
    required this.email,
    required this.phone,
    required this.postalCode,
    required this.stateName,
    required this.city,
    required this.addressLine1,
    required this.addressLine2,
    required this.termsAgreed,
    required this.isSubmittingPurchase,
    required this.purchaseResult,
    required this.purchaseError,
  });

  OrderScreenState copyWith({
    CatalogData? catalog,
    bool? isLoadingCatalog,
    String? catalogError,
    String? locale,
    String? currency,
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
    bool? isGeneratingSuggestions,
    String? recipientName,
    String? email,
    String? phone,
    String? postalCode,
    String? stateName,
    String? city,
    String? addressLine1,
    String? addressLine2,
    bool? termsAgreed,
    bool? isSubmittingPurchase,
    Object? purchaseResult = _noChange,
    String? purchaseError,
  }) {
    return OrderScreenState(
      catalog: catalog ?? this.catalog,
      isLoadingCatalog: isLoadingCatalog ?? this.isLoadingCatalog,
      catalogError: catalogError ?? this.catalogError,
      locale: locale ?? this.locale,
      currency: currency ?? this.currency,
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
      isGeneratingSuggestions:
          isGeneratingSuggestions ?? this.isGeneratingSuggestions,
      recipientName: recipientName ?? this.recipientName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      postalCode: postalCode ?? this.postalCode,
      stateName: stateName ?? this.stateName,
      city: city ?? this.city,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      termsAgreed: termsAgreed ?? this.termsAgreed,
      isSubmittingPurchase: isSubmittingPurchase ?? this.isSubmittingPurchase,
      purchaseResult: identical(purchaseResult, _noChange)
          ? this.purchaseResult
          : purchaseResult as PurchaseResultData?,
      purchaseError: purchaseError ?? this.purchaseError,
    );
  }

  bool get hasCatalog {
    return catalog.fonts.isNotEmpty &&
        catalog.materials.isNotEmpty &&
        catalog.countries.isNotEmpty;
  }

  String get effectiveCurrency {
    final normalized = currency.trim().toUpperCase();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return 'USD';
  }

  List<FontOption> get visibleFonts {
    if (!hasCatalog) {
      return const [];
    }

    return catalog.fonts
        .where((font) => font.kanjiStyle == kanjiStyle)
        .toList(growable: false);
  }

  FontOption? get selectedFontOrNull {
    if (!hasCatalog) {
      return null;
    }

    final visible = visibleFonts;
    final matched = visible.where((font) => font.key == selectedFontKey);
    if (matched.isNotEmpty) {
      return matched.first;
    }
    if (visible.isNotEmpty) {
      return visible.first;
    }

    final fallback = catalog.fonts.where((font) => font.key == selectedFontKey);
    if (fallback.isNotEmpty) {
      return fallback.first;
    }

    return catalog.fonts.first;
  }

  FontOption get selectedFont {
    return selectedFontOrNull ??
        const FontOption(
          key: '',
          label: '-',
          family: 'sans-serif',
          kanjiStyle: KanjiStyle.japanese,
        );
  }

  List<MaterialOption> get visibleMaterials {
    if (!hasCatalog) {
      return const [];
    }

    final filtered = catalog.materials
        .where((material) => material.shape == shape)
        .toList();
    if (filtered.isNotEmpty) {
      return filtered;
    }

    return catalog.materials;
  }

  MaterialOption? get selectedMaterialOrNull {
    if (!hasCatalog) {
      return null;
    }

    final visible = visibleMaterials;
    final matched = visible.where(
      (material) => material.key == selectedMaterialKey,
    );
    if (matched.isNotEmpty) {
      return matched.first;
    }
    return visible.isNotEmpty ? visible.first : catalog.materials.first;
  }

  MaterialOption get selectedMaterial {
    return selectedMaterialOrNull ??
        const MaterialOption(
          key: '',
          label: '-',
          description: '',
          shape: SealShape.square,
          shapeLabel: '角印',
          price: 0,
          photoUrl: '',
          photoAlt: '',
          hasPhoto: false,
        );
  }

  CountryOption? get selectedCountryOrNull {
    if (!hasCatalog) {
      return null;
    }

    final matched = catalog.countries.where(
      (country) => country.code == selectedCountryCode,
    );
    if (matched.isNotEmpty) {
      return matched.first;
    }
    return catalog.countries.first;
  }

  CountryOption get selectedCountry {
    return selectedCountryOrNull ??
        const CountryOption(code: '--', label: '-', shipping: 0);
  }

  int get subtotal => selectedMaterialOrNull?.price ?? 0;
  int get shipping => selectedCountryOrNull?.shipping ?? 0;
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
    final runtime = ref.watch(appRuntimeConfigProvider);

    return OrderScreenState(
      catalog: CatalogData.empty,
      isLoadingCatalog: false,
      catalogError: '',
      locale: runtime.preferredLocale,
      currency: 'USD',
      step: OrderStep.design,
      sealLine1: '',
      sealLine2: '',
      sealTextError: '',
      kanjiStyle: KanjiStyle.japanese,
      selectedFontKey: '',
      shape: SealShape.square,
      selectedMaterialKey: '',
      selectedCountryCode: '',
      realName: '',
      candidateGender: CandidateGender.unspecified,
      suggestions: const [],
      selectedSuggestionIndex: null,
      suggestionsError: '',
      isGeneratingSuggestions: false,
      recipientName: '',
      email: '',
      phone: '',
      postalCode: '',
      stateName: '',
      city: '',
      addressLine1: '',
      addressLine2: '',
      termsAgreed: false,
      isSubmittingPurchase: false,
      purchaseResult: null,
      purchaseError: '',
    );
  }

  late final initializeMut = mutation<void>(#initialize);
  late final selectLocaleMut = mutation<void>(#selectLocale);
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

  Call<void, OrderScreenState> initialize() {
    return mutate(initializeMut, (ref) async {
      final current = ref.watch(this);
      if (current.isLoadingCatalog) {
        return;
      }

      ref.state = current.copyWith(isLoadingCatalog: true, catalogError: '');

      try {
        final runtime = ref.watch(appRuntimeConfigProvider);
        final api = ref.watch(orderApiRepositoryProvider);
        final publicConfig = await api.fetchPublicConfig();
        final locale = _resolveLocale(runtime.preferredLocale, publicConfig);

        final catalogResponse = await api.fetchCatalog(locale: locale);
        final catalog = catalogResponse.catalog;
        if (catalog.fonts.isEmpty ||
            catalog.materials.isEmpty ||
            catalog.countries.isEmpty) {
          throw Exception('catalog is empty');
        }

        final style = KanjiStyle.japanese;
        final defaultFont = _pickInitialFont(catalog, style);
        final defaultShape = _pickInitialShape(catalog);
        final defaultMaterial = _pickInitialMaterial(catalog, defaultShape);
        final defaultCountry = catalog.countries.first;

        ref.state = ref
            .watch(this)
            .copyWith(
              catalog: catalog,
              isLoadingCatalog: false,
              catalogError: '',
              locale: normalizeUiLocale(catalogResponse.locale),
              currency: catalogResponse.currency,
              step: OrderStep.design,
              kanjiStyle: style,
              selectedFontKey: defaultFont.key,
              shape: defaultShape,
              selectedMaterialKey: defaultMaterial.key,
              selectedCountryCode: defaultCountry.code,
            );
      } catch (error) {
        ref.state = ref
            .watch(this)
            .copyWith(
              isLoadingCatalog: false,
              catalogError: _apiErrorMessage(
                error,
                fallback: 'カタログの取得に失敗しました。',
              ),
            );
      }
    });
  }

  Call<void, OrderScreenState> selectLocale(String locale) {
    return mutate(selectLocaleMut, (ref) async {
      final current = ref.watch(this);
      final nextLocale = normalizeUiLocale(locale);
      if (nextLocale == current.locale) {
        return;
      }

      ref.state = current.copyWith(
        locale: nextLocale,
        purchaseResult: null,
        suggestions: const [],
        selectedSuggestionIndex: null,
        suggestionsError: '',
      );

      if (!current.hasCatalog) {
        return;
      }

      final snapshot = ref.watch(this);
      ref.state = snapshot.copyWith(isLoadingCatalog: true, catalogError: '');

      try {
        final api = ref.watch(orderApiRepositoryProvider);
        final catalogResponse = await api.fetchCatalog(locale: nextLocale);
        final catalog = catalogResponse.catalog;
        if (catalog.fonts.isEmpty ||
            catalog.materials.isEmpty ||
            catalog.countries.isEmpty) {
          throw Exception('catalog is empty');
        }

        final active = ref.watch(this);
        var nextStyle = active.kanjiStyle;
        var visibleFonts = _visibleFontsFor(catalog: catalog, style: nextStyle);
        if (visibleFonts.isEmpty) {
          nextStyle = catalog.fonts.first.kanjiStyle;
          visibleFonts = _visibleFontsFor(catalog: catalog, style: nextStyle);
        }
        final nextFontKey =
            visibleFonts.any((font) => font.key == active.selectedFontKey)
            ? active.selectedFontKey
            : visibleFonts.first.key;

        var nextShape = active.shape;
        var visibleMaterials = _visibleMaterialsFor(
          catalog: catalog,
          shape: nextShape,
        );
        if (visibleMaterials.isEmpty) {
          nextShape = _pickInitialShape(catalog);
          visibleMaterials = _visibleMaterialsFor(
            catalog: catalog,
            shape: nextShape,
          );
        }
        final nextMaterialKey =
            visibleMaterials.any(
              (material) => material.key == active.selectedMaterialKey,
            )
            ? active.selectedMaterialKey
            : visibleMaterials.first.key;

        final nextCountryCode =
            catalog.countries.any(
              (country) => country.code == active.selectedCountryCode,
            )
            ? active.selectedCountryCode
            : catalog.countries.first.code;

        ref.state = active.copyWith(
          catalog: catalog,
          isLoadingCatalog: false,
          catalogError: '',
          locale: normalizeUiLocale(catalogResponse.locale),
          currency: catalogResponse.currency,
          kanjiStyle: nextStyle,
          selectedFontKey: nextFontKey,
          shape: nextShape,
          selectedMaterialKey: nextMaterialKey,
          selectedCountryCode: nextCountryCode,
        );
      } catch (error) {
        final latest = ref.watch(this);
        ref.state = latest.copyWith(
          isLoadingCatalog: false,
          catalogError: _apiErrorMessage(
            error,
            fallback: _catalogLoadErrorMessage(nextLocale),
          ),
        );
      }
    });
  }

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
      if (!current.hasCatalog) {
        return;
      }

      final visibleFonts = _visibleFontsFor(
        catalog: current.catalog,
        style: style,
      );
      final hasSelected = visibleFonts.any(
        (font) => font.key == current.selectedFontKey,
      );
      final nextFontKey = hasSelected
          ? current.selectedFontKey
          : visibleFonts.isNotEmpty
          ? visibleFonts.first.key
          : '';

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
      if (!current.hasCatalog) {
        return;
      }

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
      if (!current.hasCatalog) {
        return;
      }

      final visibleMaterials = _visibleMaterialsFor(
        catalog: current.catalog,
        shape: shape,
      );
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
      if (!current.hasCatalog) {
        return;
      }

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
      if (!current.hasCatalog) {
        return;
      }

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
      if (!current.hasCatalog) {
        return;
      }

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
      if (!current.hasCatalog) {
        return;
      }

      final realName = current.realName.trim();
      if (realName.isEmpty) {
        ref.state = current.copyWith(
          suggestions: const [],
          selectedSuggestionIndex: null,
          suggestionsError: '候補を表示するには本名を入力してください。',
        );
        return;
      }

      ref.state = current.copyWith(
        isGeneratingSuggestions: true,
        suggestionsError: '',
      );

      try {
        final api = ref.watch(orderApiRepositoryProvider);
        final suggestions = await api.generateKanjiCandidates(
          realName: realName,
          gender: current.candidateGender,
          style: current.kanjiStyle,
          reasonLanguage: current.locale,
        );

        ref.state = ref
            .watch(this)
            .copyWith(
              suggestions: suggestions,
              selectedSuggestionIndex: suggestions.isEmpty ? null : 0,
              suggestionsError: suggestions.isEmpty ? '候補を生成できませんでした。' : '',
              isGeneratingSuggestions: false,
            );
      } catch (error) {
        ref.state = ref
            .watch(this)
            .copyWith(
              suggestions: const [],
              selectedSuggestionIndex: null,
              suggestionsError: _apiErrorMessage(
                error,
                fallback: '候補生成に失敗しました。',
              ),
              isGeneratingSuggestions: false,
            );
      }
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
      if (!current.hasCatalog || current.isSubmittingPurchase) {
        return;
      }

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

      ref.state = current.copyWith(
        isSubmittingPurchase: true,
        purchaseError: '',
      );

      try {
        final api = ref.watch(orderApiRepositoryProvider);
        final order = await api.createOrder(
          locale: current.locale,
          idempotencyKey: _newIdempotencyKey(),
          termsAgreed: current.termsAgreed,
          sealLine1: current.sealLine1,
          sealLine2: current.sealLine2,
          shape: current.shape,
          fontKey: current.selectedFont.key,
          materialKey: current.selectedMaterial.key,
          countryCode: current.selectedCountry.code,
          recipientName: current.recipientName.trim(),
          phone: current.phone.trim(),
          postalCode: current.postalCode.trim(),
          state: current.stateName.trim(),
          city: current.city.trim(),
          addressLine1: current.addressLine1.trim(),
          addressLine2: current.addressLine2.trim(),
          email: current.email.trim(),
        );

        final checkout = await api.createStripeCheckoutSession(
          orderId: order.orderId,
          customerEmail: current.email.trim(),
        );

        final currency = order.currency.isNotEmpty
            ? order.currency
            : current.effectiveCurrency;
        final total = order.total > 0 ? order.total : current.total;

        ref.state = ref
            .watch(this)
            .copyWith(
              isSubmittingPurchase: false,
              purchaseError: '',
              purchaseResult: PurchaseResultData(
                sealLine1: current.sealLine1,
                sealLine2: current.sealLine2,
                fontLabel: current.selectedFont.label,
                shapeLabel: current.shape.localizedLabel(current.locale),
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
                total: total,
                email: current.email.trim(),
                sourceLabel: 'API',
                currency: currency,
                orderId: order.orderId,
                checkoutSessionId: checkout.sessionId,
                checkoutUrl: checkout.checkoutUrl,
                paymentIntentId: checkout.paymentIntentId,
              ),
            );
      } catch (error) {
        ref.state = ref
            .watch(this)
            .copyWith(
              isSubmittingPurchase: false,
              purchaseError: _apiErrorMessage(error, fallback: '購入処理に失敗しました。'),
              purchaseResult: null,
            );
      }
    });
  }
}

final orderViewModel = OrderViewModel();

const _maxSealCharTotal = 2;

String _resolveLocale(String preferredLocale, PublicConfigData publicConfig) {
  final supported = publicConfig.supportedLocales;
  final normalizedPreferred = preferredLocale.trim().toLowerCase();

  if (supported.contains(normalizedPreferred)) {
    return normalizedPreferred;
  }

  final defaultLocale = publicConfig.defaultLocale.trim().toLowerCase();
  if (defaultLocale.isNotEmpty && supported.contains(defaultLocale)) {
    return defaultLocale;
  }

  if (supported.isNotEmpty) {
    return supported.first;
  }

  return normalizedPreferred.isNotEmpty ? normalizedPreferred : 'ja';
}

FontOption _pickInitialFont(CatalogData catalog, KanjiStyle style) {
  final visibleFonts = _visibleFontsFor(catalog: catalog, style: style);
  if (visibleFonts.isNotEmpty) {
    return visibleFonts.first;
  }
  return catalog.fonts.first;
}

SealShape _pickInitialShape(CatalogData catalog) {
  if (catalog.materials.any((material) => material.shape == SealShape.square)) {
    return SealShape.square;
  }
  return catalog.materials.first.shape;
}

MaterialOption _pickInitialMaterial(CatalogData catalog, SealShape shape) {
  final visibleMaterials = _visibleMaterialsFor(catalog: catalog, shape: shape);
  return visibleMaterials.first;
}

List<FontOption> _visibleFontsFor({
  required CatalogData catalog,
  required KanjiStyle style,
}) {
  return catalog.fonts
      .where((font) => font.kanjiStyle == style)
      .toList(growable: false);
}

List<MaterialOption> _visibleMaterialsFor({
  required CatalogData catalog,
  required SealShape shape,
}) {
  final filtered = catalog.materials
      .where((material) => material.shape == shape)
      .toList();
  if (filtered.isNotEmpty) {
    return filtered;
  }
  return catalog.materials;
}

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

String _newIdempotencyKey() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final randomPart = Random.secure().nextInt(0x7fffffff).toRadixString(16);
  return 'app_${now}_$randomPart';
}

String _catalogLoadErrorMessage(String locale) {
  if (isEnglishLocale(locale)) {
    return 'Failed to load catalog.';
  }
  return 'カタログの取得に失敗しました。';
}

String _apiErrorMessage(Object error, {required String fallback}) {
  if (error is OrderApiException) {
    if (error.message.trim().isNotEmpty) {
      return error.message;
    }
    return fallback;
  }

  final text = error.toString().trim();
  if (text.isEmpty) {
    return fallback;
  }
  return text;
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
