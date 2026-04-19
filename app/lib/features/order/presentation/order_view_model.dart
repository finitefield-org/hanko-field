import 'dart:async';
import 'dart:math';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:miniriverpod/miniriverpod.dart';

import '../../../app/config/app_runtime_config.dart';
import '../data/order_draft_storage.dart';
import '../data/order_api_repository.dart';
import '../domain/order_models.dart';

@immutable
class PurchaseValidationGroup {
  const PurchaseValidationGroup({required this.label, required this.items});

  final String label;
  final List<String> items;
}

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
  final String selectedStoneListingKey;
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
    required this.selectedStoneListingKey,
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
    String? selectedStoneListingKey,
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
      selectedStoneListingKey:
          selectedStoneListingKey ?? this.selectedStoneListingKey,
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
        availableShapes.isNotEmpty &&
        catalog.countries.isNotEmpty;
  }

  List<PurchaseValidationGroup> get purchaseValidationGroups {
    final locale = this.locale;
    final groups = <PurchaseValidationGroup>[];

    final sealTextError = _validateSealText(
      locale: locale,
      line1: sealLine1,
      line2: sealLine2,
    );
    if (sealTextError.isNotEmpty) {
      groups.add(
        PurchaseValidationGroup(
          label: localizedUiText(locale, ja: '印影テキスト', en: 'Seal text'),
          items: [sealTextError],
        ),
      );
    }

    if (hasCatalog && selectedStoneListingOrNull == null) {
      groups.add(
        PurchaseValidationGroup(
          label: localizedUiText(locale, ja: '出品個体', en: 'Listing'),
          items: [
            localizedUiText(
              locale,
              ja: '現在の形状に対応する出品個体が見つかりません。',
              en: 'No listing is available for the selected shape.',
            ),
          ],
        ),
      );
    }

    final shippingIssues = <String>[];
    if (recipientName.trim().isEmpty) {
      shippingIssues.add(
        localizedUiText(locale, ja: 'お届け先氏名', en: 'Recipient name'),
      );
    }
    if (email.trim().isEmpty) {
      shippingIssues.add(
        localizedUiText(locale, ja: 'メールアドレス', en: 'Email address'),
      );
    } else if (!email.contains('@')) {
      shippingIssues.add(
        localizedUiText(
          locale,
          ja: 'メールアドレスの形式が正しくありません。',
          en: 'Enter a valid email address.',
        ),
      );
    }
    if (phone.trim().isEmpty) {
      shippingIssues.add(
        localizedUiText(locale, ja: '電話番号', en: 'Phone number'),
      );
    }
    if (postalCode.trim().isEmpty) {
      shippingIssues.add(
        localizedUiText(locale, ja: '郵便番号', en: 'Postal code'),
      );
    }
    if (stateName.trim().isEmpty) {
      shippingIssues.add(
        localizedUiText(locale, ja: '都道府県 / 州', en: 'State / Prefecture'),
      );
    }
    if (city.trim().isEmpty) {
      shippingIssues.add(
        localizedUiText(locale, ja: '市区町村 / City', en: 'City'),
      );
    }
    if (addressLine1.trim().isEmpty) {
      shippingIssues.add(
        localizedUiText(locale, ja: '住所1', en: 'Address line 1'),
      );
    }
    if (shippingIssues.isNotEmpty) {
      groups.add(
        PurchaseValidationGroup(
          label: localizedUiText(locale, ja: 'お届け先情報', en: 'Shipping details'),
          items: shippingIssues,
        ),
      );
    }

    if (!termsAgreed) {
      groups.add(
        PurchaseValidationGroup(
          label: localizedUiText(locale, ja: '同意', en: 'Agreement'),
          items: [
            localizedUiText(
              locale,
              ja: '利用規約への同意',
              en: 'Agree to the terms of service',
            ),
          ],
        ),
      );
    }

    return groups;
  }

  bool get canSubmitPurchase {
    return hasCatalog &&
        !isSubmittingPurchase &&
        purchaseValidationGroups.isEmpty;
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

  List<SealShape> get availableShapes {
    final shapes = <SealShape>[];
    for (final candidate in SealShape.values) {
      final supported = catalog.stoneListings.any(
        (listing) => listing.supportsShape(candidate),
      );
      if (supported) {
        shapes.add(candidate);
      }
    }
    return shapes;
  }

  List<StoneListingOption> get visibleStoneListings {
    if (!hasCatalog) {
      return const [];
    }

    return catalog.stoneListings
        .where((listing) => listing.supportsShape(shape))
        .toList(growable: false);
  }

  StoneListingOption? get selectedStoneListingOrNull {
    if (!hasCatalog) {
      return null;
    }

    final matches = catalog.stoneListings
        .where((listing) => listing.key == selectedStoneListingKey)
        .toList(growable: false);
    if (matches.isNotEmpty) {
      return matches.first;
    }
    return null;
  }

  StoneListingOption get selectedStoneListing {
    return selectedStoneListingOrNull ??
        const StoneListingOption(
          key: '',
          listingCode: '',
          title: '-',
          description: '',
          story: '',
          supportedSealShapes: [],
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

  int get subtotal => selectedStoneListingOrNull?.price ?? 0;
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
      selectedStoneListingKey: '',
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
  late final selectStoneListingMut = mutation<void>(#selectStoneListing);
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

      final runtime = ref.watch(appRuntimeConfigProvider);
      if (runtime.mode == AppMode.mock) {
        final latest = ref.watch(this);
        final fallback = _mockCatalogResponse(
          locale: latest.locale.isNotEmpty
              ? latest.locale
              : runtime.preferredLocale,
        );
        ref.state = _stateWithCatalog(
          state: latest,
          catalog: fallback.catalog,
          locale: fallback.locale,
          currency: fallback.currency,
        );
        return;
      }

      final draftStorage = ref.watch(orderDraftStorageProvider);
      final savedDraft = await draftStorage.load();
      if (savedDraft != null) {
        ref.state = _stateWithDraft(ref.watch(this), savedDraft);
      }

      try {
        final api = ref.watch(orderApiRepositoryProvider);
        final publicConfig = await api.fetchPublicConfig();
        final requestedLocale = ref.watch(this).locale.trim();
        final locale = _resolveLocale(
          requestedLocale.isNotEmpty
              ? requestedLocale
              : runtime.preferredLocale,
          publicConfig,
        );

        final catalogResponse = await api.fetchCatalog(locale: locale);
        final catalog = catalogResponse.catalog;
        if (catalog.fonts.isEmpty ||
            _availableShapesForCatalog(catalog).isEmpty ||
            catalog.countries.isEmpty) {
          throw Exception('catalog is empty');
        }

        final nextState = _stateWithCatalog(
          state: ref.watch(this),
          catalog: catalog,
          locale: normalizeUiLocale(catalogResponse.locale),
          currency: catalogResponse.currency,
        );

        ref.state = nextState;
      } catch (error) {
        if (_shouldUseMockFallback(error, runtime.mode)) {
          final latest = ref.watch(this);
          final fallback = _mockCatalogResponse(
            locale: latest.locale.isNotEmpty
                ? latest.locale
                : runtime.preferredLocale,
          );
          ref.state = _stateWithCatalog(
            state: latest,
            catalog: fallback.catalog,
            locale: fallback.locale,
            currency: fallback.currency,
          );
          return;
        }

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

      final runtime = ref.watch(appRuntimeConfigProvider);

      ref.state = current.copyWith(
        locale: nextLocale,
        purchaseResult: null,
        purchaseError: '',
        suggestions: const [],
        selectedSuggestionIndex: null,
        suggestionsError: '',
      );

      if (current.isLoadingCatalog || !current.hasCatalog) {
        return;
      }

      final snapshot = ref.watch(this);
      ref.state = snapshot.copyWith(isLoadingCatalog: true, catalogError: '');

      if (runtime.mode == AppMode.mock) {
        final latest = ref.watch(this);
        final fallback = _mockCatalogResponse(locale: nextLocale);
        ref.state = _stateWithCatalog(
          state: latest,
          catalog: fallback.catalog,
          locale: fallback.locale,
          currency: fallback.currency,
        );
        return;
      }

      try {
        final api = ref.watch(orderApiRepositoryProvider);
        final catalogResponse = await api.fetchCatalog(locale: nextLocale);
        final catalog = catalogResponse.catalog;
        if (catalog.fonts.isEmpty ||
            _availableShapesForCatalog(catalog).isEmpty ||
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
        var visibleListings = _visibleStoneListingsFor(
          catalog: catalog,
          shape: nextShape,
        );
        if (visibleListings.isEmpty) {
          nextShape = _pickInitialShape(catalog);
          visibleListings = _visibleStoneListingsFor(
            catalog: catalog,
            shape: nextShape,
          );
        }
        final nextListingKey =
            visibleListings.any(
              (listing) => listing.key == active.selectedStoneListingKey,
            )
            ? active.selectedStoneListingKey
            : visibleListings.first.key;

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
          selectedStoneListingKey: nextListingKey,
          selectedCountryCode: nextCountryCode,
        );
      } catch (error) {
        if (_shouldUseMockFallback(error, runtime.mode)) {
          final latest = ref.watch(this);
          final fallback = _mockCatalogResponse(locale: nextLocale);
          ref.state = _stateWithCatalog(
            state: latest,
            catalog: fallback.catalog,
            locale: fallback.locale,
            currency: fallback.currency,
          );
          return;
        }

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
      final sealError = _validateSealText(
        locale: current.locale,
        line1: line1,
        line2: line2,
      );
      ref.state = current.copyWith(
        sealLine1: line1,
        sealLine2: line2,
        sealTextError: sealError,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> updateSealLine2(String value) {
    return mutate(updateSealLine2Mut, (ref) async {
      final current = ref.watch(this);
      final (line1, line2) = _normalizedSealLines(current.sealLine1, value);
      final sealError = _validateSealText(
        locale: current.locale,
        line1: line1,
        line2: line2,
      );
      ref.state = current.copyWith(
        sealLine1: line1,
        sealLine2: line2,
        sealTextError: sealError,
        purchaseResult: null,
        purchaseError: '',
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
      final sealError = _validateSealText(
        locale: current.locale,
        line1: line1,
        line2: line2,
      );
      ref.state = current.copyWith(
        sealLine1: line1,
        sealLine2: line2,
        sealTextError: sealError,
        purchaseResult: null,
        purchaseError: '',
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
        purchaseError: '',
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

      ref.state = current.copyWith(selectedFontKey: key, purchaseError: '');
    });
  }

  Call<void, OrderScreenState> selectShape(SealShape shape) {
    return mutate(selectShapeMut, (ref) async {
      final current = ref.watch(this);
      if (!current.hasCatalog) {
        return;
      }

      final visibleListings = _visibleStoneListingsFor(
        catalog: current.catalog,
        shape: shape,
      );
      if (visibleListings.isEmpty) {
        return;
      }

      final hasSelected = visibleListings.any(
        (listing) => listing.key == current.selectedStoneListingKey,
      );
      final nextListingKey = hasSelected
          ? current.selectedStoneListingKey
          : visibleListings.first.key;

      ref.state = current.copyWith(
        shape: shape,
        selectedStoneListingKey: nextListingKey,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> selectStoneListing(String key) {
    return mutate(selectStoneListingMut, (ref) async {
      final current = ref.watch(this);
      if (!current.hasCatalog) {
        return;
      }

      final allowed = current.visibleStoneListings.any(
        (listing) => listing.key == key,
      );
      if (!allowed) {
        return;
      }

      ref.state = current.copyWith(
        selectedStoneListingKey: key,
        purchaseResult: null,
        purchaseError: '',
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
        purchaseError: '',
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
          locale: current.locale,
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
      ref.state = current.copyWith(
        realName: value,
        suggestions: const [],
        selectedSuggestionIndex: null,
        suggestionsError: '',
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> selectCandidateGender(CandidateGender gender) {
    return mutate(selectCandidateGenderMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(candidateGender: gender, purchaseError: '');
    });
  }

  Call<void, OrderScreenState> generateSuggestions() {
    return mutate(generateSuggestionsMut, (ref) async {
      final current = ref.watch(this);
      final runtime = ref.watch(appRuntimeConfigProvider);
      if (!current.hasCatalog) {
        return;
      }

      final realName = current.realName.trim();
      if (realName.isEmpty) {
        ref.state = current.copyWith(
          suggestions: const [],
          selectedSuggestionIndex: null,
          suggestionsError: localizedUiText(
            current.locale,
            ja: 'お名前を入力してください。',
            en: 'Enter your name.',
          ),
        );
        return;
      }

      ref.state = current.copyWith(
        isGeneratingSuggestions: true,
        suggestionsError: '',
      );

      if (runtime.mode == AppMode.mock) {
        final latest = ref.watch(this);
        final suggestions = _mockKanjiCandidates(
          locale: latest.locale,
          realName: latest.realName,
          gender: latest.candidateGender,
          style: latest.kanjiStyle,
        );
        ref.state = latest.copyWith(
          suggestions: suggestions,
          selectedSuggestionIndex: suggestions.isEmpty ? null : 0,
          suggestionsError: '',
          isGeneratingSuggestions: false,
        );
        return;
      }

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
              suggestionsError: suggestions.isEmpty
                  ? localizedUiText(
                      current.locale,
                      ja: '候補を生成できませんでした。',
                      en: 'No suggestions were generated.',
                    )
                  : '',
              isGeneratingSuggestions: false,
            );
      } catch (error) {
        if (_shouldUseMockFallback(error, runtime.mode)) {
          final latest = ref.watch(this);
          final suggestions = _mockKanjiCandidates(
            locale: latest.locale,
            realName: latest.realName,
            gender: latest.candidateGender,
            style: latest.kanjiStyle,
          );
          ref.state = latest.copyWith(
            suggestions: suggestions,
            selectedSuggestionIndex: suggestions.isEmpty ? null : 0,
            suggestionsError: '',
            isGeneratingSuggestions: false,
          );
          return;
        }

        ref.state = ref
            .watch(this)
            .copyWith(
              suggestions: const [],
              selectedSuggestionIndex: null,
              suggestionsError: _apiErrorMessage(
                error,
                fallback: localizedUiText(
                  current.locale,
                  ja: '候補生成に失敗しました。',
                  en: 'Failed to generate suggestions.',
                ),
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
      final sealError = _validateSealText(
        locale: current.locale,
        line1: line1,
        line2: line2,
      );

      ref.state = current.copyWith(
        selectedSuggestionIndex: index,
        sealLine1: line1,
        sealLine2: line2,
        sealTextError: sealError,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> updateRecipientName(String value) {
    return mutate(updateRecipientNameMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(
        recipientName: value,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> updateEmail(String value) {
    return mutate(updateEmailMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(
        email: value,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> updatePhone(String value) {
    return mutate(updatePhoneMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(
        phone: value,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> updatePostalCode(String value) {
    return mutate(updatePostalCodeMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(
        postalCode: value,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> updateStateName(String value) {
    return mutate(updateStateNameMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(
        stateName: value,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> updateCity(String value) {
    return mutate(updateCityMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(
        city: value,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> updateAddressLine1(String value) {
    return mutate(updateAddressLine1Mut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(
        addressLine1: value,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> updateAddressLine2(String value) {
    return mutate(updateAddressLine2Mut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(
        addressLine2: value,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> setTermsAgreed(bool value) {
    return mutate(setTermsAgreedMut, (ref) async {
      final current = ref.watch(this);
      ref.state = current.copyWith(
        termsAgreed: value,
        purchaseResult: null,
        purchaseError: '',
      );
    });
  }

  Call<void, OrderScreenState> submitPurchase() {
    return mutate(submitPurchaseMut, (ref) async {
      final current = ref.watch(this);
      final runtime = ref.watch(appRuntimeConfigProvider);
      if (!current.hasCatalog || current.isSubmittingPurchase) {
        return;
      }

      final sealError = _validateSealText(
        locale: current.locale,
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
        purchaseResult: null,
      );

      if (runtime.mode == AppMode.mock) {
        final latest = ref.watch(this);
        final mockOrderId =
            'mock_order_${DateTime.now().millisecondsSinceEpoch}';
        final mockSessionId = 'mock_session_$mockOrderId';
        ref.state = latest.copyWith(
          isSubmittingPurchase: false,
          purchaseError: '',
          purchaseResult: PurchaseResultData(
            listingLabel: current.selectedStoneListing.title,
            sealLine1: current.sealLine1,
            sealLine2: current.sealLine2,
            fontLabel: current.selectedFont.label,
            shapeLabel: current.shape.localizedLabel(current.locale),
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
            currency: current.effectiveCurrency,
            orderId: mockOrderId,
            checkoutSessionId: mockSessionId,
            checkoutUrl: '',
            paymentIntentId: 'mock_pi_$mockOrderId',
          ),
        );
        return;
      }

      try {
        final selectedListing = current.selectedStoneListingOrNull;
        if (selectedListing == null) {
          ref.state = current.copyWith(
            isSubmittingPurchase: false,
            purchaseError: localizedUiText(
              current.locale,
              ja: '現在の形状に対応する出品個体が見つかりません。',
              en: 'No listing is available for the selected shape.',
            ),
            purchaseResult: null,
          );
          return;
        }

        final api = ref.watch(orderApiRepositoryProvider);
        final order = await api.createOrder(
          locale: current.locale,
          idempotencyKey: _newIdempotencyKey(),
          termsAgreed: current.termsAgreed,
          sealLine1: current.sealLine1,
          sealLine2: current.sealLine2,
          shape: current.shape,
          fontKey: current.selectedFont.key,
          listingId: selectedListing.key,
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
                listingLabel: current.selectedStoneListing.title,
                sealLine1: current.sealLine1,
                sealLine2: current.sealLine2,
                fontLabel: current.selectedFont.label,
                shapeLabel: current.shape.localizedLabel(current.locale),
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
        if (_shouldUseMockFallback(error, runtime.mode)) {
          final latest = ref.watch(this);
          final mockOrderId =
              'mock_order_${DateTime.now().millisecondsSinceEpoch}';
          final mockSessionId = 'mock_session_$mockOrderId';
          ref.state = latest.copyWith(
            isSubmittingPurchase: false,
            purchaseError: '',
            purchaseResult: PurchaseResultData(
              listingLabel: current.selectedStoneListing.title,
              sealLine1: current.sealLine1,
              sealLine2: current.sealLine2,
              fontLabel: current.selectedFont.label,
              shapeLabel: current.shape.localizedLabel(current.locale),
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
              currency: current.effectiveCurrency,
              orderId: mockOrderId,
              checkoutSessionId: mockSessionId,
              checkoutUrl: '',
              paymentIntentId: 'mock_pi_$mockOrderId',
            ),
          );
          return;
        }

        ref.state = ref
            .watch(this)
            .copyWith(
              isSubmittingPurchase: false,
              purchaseError: _apiErrorMessage(
                error,
                fallback: localizedUiText(
                  current.locale,
                  ja: '購入処理に失敗しました。',
                  en: 'Failed to process the purchase.',
                ),
              ),
              purchaseResult: null,
            );
      }
    });
  }
}

final orderViewModel = OrderViewModel();

const _maxSealCharTotal = 2;

OrderScreenState _stateWithDraft(OrderScreenState state, OrderDraftData draft) {
  final (sealLine1, sealLine2) = _normalizedSealLines(
    draft.sealLine1,
    draft.sealLine2,
  );

  return state.copyWith(
    step: OrderStep.fromValue(draft.stepValue),
    sealLine1: sealLine1,
    sealLine2: sealLine2,
    sealTextError: '',
    kanjiStyle: KanjiStyle.fromCode(draft.kanjiStyleCode),
    selectedFontKey: draft.selectedFontKey,
    shape: SealShape.fromCode(draft.shapeCode),
    selectedStoneListingKey: draft.selectedStoneListingKey,
    selectedCountryCode: draft.selectedCountryCode,
    realName: draft.realName,
    candidateGender: CandidateGender.fromCode(draft.candidateGenderCode),
    suggestions: const [],
    selectedSuggestionIndex: null,
    suggestionsError: '',
    isGeneratingSuggestions: false,
    recipientName: draft.recipientName,
    email: draft.email,
    phone: draft.phone,
    postalCode: draft.postalCode,
    stateName: draft.stateName,
    city: draft.city,
    addressLine1: draft.addressLine1,
    addressLine2: draft.addressLine2,
    termsAgreed: draft.termsAgreed,
    isSubmittingPurchase: false,
    purchaseResult: null,
    purchaseError: '',
  );
}

OrderScreenState _stateWithCatalog({
  required OrderScreenState state,
  required CatalogData catalog,
  required String locale,
  required String currency,
}) {
  var nextStyle = state.kanjiStyle;
  var visibleFonts = _visibleFontsFor(catalog: catalog, style: nextStyle);
  if (visibleFonts.isEmpty) {
    nextStyle = catalog.fonts.first.kanjiStyle;
    visibleFonts = _visibleFontsFor(catalog: catalog, style: nextStyle);
  }

  final nextFontKey =
      visibleFonts.any((font) => font.key == state.selectedFontKey)
      ? state.selectedFontKey
      : visibleFonts.first.key;

  var nextShape = state.shape;
  if (_visibleStoneListingsFor(catalog: catalog, shape: nextShape).isEmpty) {
    nextShape = _pickInitialShape(catalog);
  }
  final visibleListings = _visibleStoneListingsFor(
    catalog: catalog,
    shape: nextShape,
  );
  final nextListingKey =
      visibleListings.any(
        (listing) => listing.key == state.selectedStoneListingKey,
      )
      ? state.selectedStoneListingKey
      : visibleListings.first.key;

  final nextCountryCode =
      catalog.countries.any(
        (country) => country.code == state.selectedCountryCode,
      )
      ? state.selectedCountryCode
      : catalog.countries.first.code;

  return state.copyWith(
    catalog: catalog,
    isLoadingCatalog: false,
    catalogError: '',
    locale: normalizeUiLocale(locale),
    currency: currency,
    kanjiStyle: nextStyle,
    selectedFontKey: nextFontKey,
    shape: nextShape,
    selectedStoneListingKey: nextListingKey,
    selectedCountryCode: nextCountryCode,
  );
}

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

SealShape _pickInitialShape(CatalogData catalog) {
  if (_visibleStoneListingsFor(
    catalog: catalog,
    shape: SealShape.square,
  ).isNotEmpty) {
    return SealShape.square;
  }
  if (_visibleStoneListingsFor(
    catalog: catalog,
    shape: SealShape.round,
  ).isNotEmpty) {
    return SealShape.round;
  }
  return catalog.stoneListings.isNotEmpty &&
          catalog.stoneListings.first.supportsShape(SealShape.square)
      ? SealShape.square
      : SealShape.round;
}

List<FontOption> _visibleFontsFor({
  required CatalogData catalog,
  required KanjiStyle style,
}) {
  return catalog.fonts
      .where((font) => font.kanjiStyle == style)
      .toList(growable: false);
}

List<StoneListingOption> _visibleStoneListingsFor({
  required CatalogData catalog,
  required SealShape shape,
}) {
  return catalog.stoneListings
      .where((listing) => listing.supportsShape(shape))
      .toList(growable: false);
}

List<SealShape> _availableShapesForCatalog(CatalogData catalog) {
  final shapes = <SealShape>[];
  for (final shape in SealShape.values) {
    if (_visibleStoneListingsFor(catalog: catalog, shape: shape).isNotEmpty) {
      shapes.add(shape);
    }
  }
  return shapes;
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

String _validateSealText({
  required String locale,
  required String line1,
  required String line2,
}) {
  if (line1.characters.isEmpty) {
    return localizedUiText(locale, ja: 'お名前を入力してください。', en: 'Enter your name.');
  }

  if (_containsWhitespace(line1)) {
    return localizedUiText(
      locale,
      ja: '1行目に空白は使えません。',
      en: 'Line 1 cannot contain spaces.',
    );
  }

  if (line2.isNotEmpty && _containsWhitespace(line2)) {
    return localizedUiText(
      locale,
      ja: '2行目に空白は使えません。',
      en: 'Line 2 cannot contain spaces.',
    );
  }

  if (line1.characters.length + line2.characters.length > _maxSealCharTotal) {
    return localizedUiText(
      locale,
      ja: '印影テキストは1行目と2行目の合計で2文字以内で入力してください。',
      en: 'Use up to 2 characters total across lines 1 and 2.',
    );
  }

  return '';
}

bool _containsWhitespace(String value) {
  return RegExp(r'\s', unicode: true).hasMatch(value);
}

String _validatePurchase(OrderScreenState state) {
  final groups = state.purchaseValidationGroups;
  if (groups.isEmpty) {
    return '';
  }
  return _formatPurchaseValidationMessage(groups);
}

String _formatPurchaseValidationMessage(List<PurchaseValidationGroup> groups) {
  return groups
      .map((group) {
        if (group.items.length == 1) {
          return group.items.first;
        }
        return '${group.label}: ${group.items.join(' / ')}';
      })
      .join('\n');
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

bool _shouldUseMockFallback(Object error, AppMode mode) {
  if (mode == AppMode.mock) {
    return true;
  }

  if (mode == AppMode.prod) {
    return false;
  }

  if (error is TimeoutException) {
    return true;
  }

  if (error is http.ClientException) {
    return _looksLikeNetworkFailure(error.message);
  }

  return _looksLikeNetworkFailure(error.toString());
}

bool _looksLikeNetworkFailure(String text) {
  final normalized = text.toLowerCase();
  return normalized.contains('connection refused') ||
      normalized.contains('socketexception') ||
      normalized.contains('clientexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('network is unreachable') ||
      normalized.contains('connection reset') ||
      normalized.contains('connection timed out') ||
      normalized.contains('timed out');
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

({String locale, String currency, CatalogData catalog}) _mockCatalogResponse({
  required String locale,
}) {
  final normalizedLocale = normalizeUiLocale(locale);
  final english = isEnglishLocale(normalizedLocale);
  final currency = english ? 'USD' : 'JPY';

  return (
    locale: normalizedLocale,
    currency: currency,
    catalog: CatalogData(
      fonts: const [
        FontOption(
          key: 'zen_maru_gothic',
          label: 'Zen Maru Gothic',
          family: "'Zen Maru Gothic', sans-serif",
          kanjiStyle: KanjiStyle.japanese,
        ),
        FontOption(
          key: 'kosugi_maru',
          label: 'Kosugi Maru',
          family: "'Kosugi Maru', sans-serif",
          kanjiStyle: KanjiStyle.chinese,
        ),
        FontOption(
          key: 'potta_one',
          label: 'Potta One',
          family: "'Potta One', sans-serif",
          kanjiStyle: KanjiStyle.taiwanese,
        ),
        FontOption(
          key: 'kiwi_maru',
          label: 'Kiwi Maru',
          family: "'Kiwi Maru', sans-serif",
          kanjiStyle: KanjiStyle.japanese,
        ),
        FontOption(
          key: 'wdxl_lubrifont_jp_n',
          label: 'WDXL Lubrifont JP N',
          family: "'WDXL Lubrifont JP N', sans-serif",
          kanjiStyle: KanjiStyle.chinese,
        ),
      ],
      stoneListings: [
        StoneListingOption(
          key: 'rose_quartz_01',
          listingCode: 'rose_quartz_01',
          title: english ? 'Rose Quartz 01' : 'ローズクオーツ 01',
          description: english
              ? 'A soft-toned listing with a warm, approachable presence'
              : 'やわらかな色合いで、親しみやすい印象の個体',
          story: english
              ? 'Balanced for everyday use with a gentle finish.'
              : '日常使いしやすい、やわらかな仕上がりの個体です。',
          supportedSealShapes: const ['square', 'round'],
          price: english ? 16500 : 28000,
          photoUrl: 'https://picsum.photos/seed/hf-rose-quartz-01/640/420',
          photoAlt: english ? 'Rose quartz listing photo' : 'ローズクオーツ個体の写真',
          hasPhoto: true,
        ),
        StoneListingOption(
          key: 'lapis_lazuli_01',
          listingCode: 'lapis_lazuli_01',
          title: english ? 'Lapis Lazuli 01' : 'ラピスラズリ 01',
          description: english
              ? 'A deep-blue listing with a strong, distinctive presence'
              : '深い青が印象的な、存在感のある個体',
          story: english
              ? 'Sharp contrast and a vivid finish make it stand out.'
              : 'コントラストが強く、印象に残る仕上がりです。',
          supportedSealShapes: const ['square', 'round'],
          price: english ? 32500 : 55000,
          photoUrl: 'https://picsum.photos/seed/hf-lapis-lazuli-01/640/420',
          photoAlt: english ? 'Lapis lazuli listing photo' : 'ラピスラズリ個体の写真',
          hasPhoto: true,
        ),
        StoneListingOption(
          key: 'jade_01',
          listingCode: 'jade_01',
          title: english ? 'Jade 01' : '翡翠 01',
          description: english
              ? 'A dignified listing with a calm green sheen'
              : '落ち着いた緑の艶が映える、格調ある個体',
          story: english
              ? 'A composed, refined finish for formal use.'
              : 'フォーマルな用途にも合う、落ち着いた仕上がりです。',
          supportedSealShapes: const ['square', 'round'],
          price: english ? 88500 : 150000,
          photoUrl: 'https://picsum.photos/seed/hf-jade-01/640/420',
          photoAlt: english ? 'Jade listing photo' : '翡翠個体の写真',
          hasPhoto: true,
        ),
      ],
      countries: [
        CountryOption(
          code: 'JP',
          label: english ? 'Japan' : '日本',
          shipping: 600,
        ),
        CountryOption(
          code: 'US',
          label: english ? 'United States' : 'アメリカ',
          shipping: 1800,
        ),
        CountryOption(
          code: 'CA',
          label: english ? 'Canada' : 'カナダ',
          shipping: 1900,
        ),
        CountryOption(
          code: 'GB',
          label: english ? 'United Kingdom' : 'イギリス',
          shipping: 2000,
        ),
        CountryOption(
          code: 'AU',
          label: english ? 'Australia' : 'オーストラリア',
          shipping: 2100,
        ),
        CountryOption(
          code: 'SG',
          label: english ? 'Singapore' : 'シンガポール',
          shipping: 1300,
        ),
      ],
    ),
  );
}

List<KanjiCandidate> _mockKanjiCandidates({
  required String locale,
  required String realName,
  required CandidateGender gender,
  required KanjiStyle style,
}) {
  final normalizedLocale = normalizeUiLocale(locale);
  final english = isEnglishLocale(normalizedLocale);
  final nameLabel = realName.trim().isEmpty
      ? (english ? 'your name' : 'お名前')
      : realName.trim();
  final tone = switch (gender) {
    CandidateGender.male => english ? 'Steady and grounded.' : '芯のある印象。',
    CandidateGender.female => english ? 'Soft and elegant.' : 'やわらかく上品な印象。',
    CandidateGender.unspecified =>
      english ? 'Balanced and refined.' : 'バランスのよい印象。',
  };

  final descriptors = switch (style) {
    KanjiStyle.japanese => <({String kanji, String reading, String reason})>[
      (
        kanji: '悠',
        reading: 'yuu',
        reason: english
            ? 'A calm, spacious choice for $nameLabel.'
            : '$nameLabel に落ち着きを添える候補です。',
      ),
      (
        kanji: '凛',
        reading: 'rin',
        reason: english
            ? 'A crisp, composed choice for $nameLabel.'
            : '$nameLabel に端正さを添える候補です。',
      ),
      (
        kanji: '匠',
        reading: 'takumi',
        reason: english
            ? 'A crafted, dependable choice for $nameLabel.'
            : '$nameLabel に確かさを感じさせる候補です。',
      ),
    ],
    KanjiStyle.chinese => <({String kanji, String reading, String reason})>[
      (
        kanji: '安',
        reading: 'an',
        reason: english
            ? 'A steady, grounded choice for $nameLabel.'
            : '$nameLabel に安定感を添える候補です。',
      ),
      (
        kanji: '明',
        reading: 'ming',
        reason: english
            ? 'A bright, clear choice for $nameLabel.'
            : '$nameLabel に明るさを添える候補です。',
      ),
      (
        kanji: '辰',
        reading: 'chen',
        reason: english
            ? 'A dignified, forward-looking choice for $nameLabel.'
            : '$nameLabel に格調と前向きさを添える候補です。',
      ),
    ],
    KanjiStyle.taiwanese => <({String kanji, String reading, String reason})>[
      (
        kanji: '宏',
        reading: 'hong',
        reason: english
            ? 'A broad, confident choice for $nameLabel.'
            : '$nameLabel に広がりを感じさせる候補です。',
      ),
      (
        kanji: '寧',
        reading: 'ning',
        reason: english
            ? 'A calm, graceful choice for $nameLabel.'
            : '$nameLabel に静かな優雅さを添える候補です。',
      ),
      (
        kanji: '昇',
        reading: 'sheng',
        reason: english
            ? 'An uplifting, optimistic choice for $nameLabel.'
            : '$nameLabel に前向きな印象を添える候補です。',
      ),
    ],
  };

  return descriptors
      .map((descriptor) {
        final reading = english
            ? descriptor.reading
            : switch (style) {
                KanjiStyle.japanese => descriptor.reading,
                KanjiStyle.chinese => normalizePinyinWithoutTone(
                  descriptor.reading,
                ),
                KanjiStyle.taiwanese => normalizePinyinWithoutTone(
                  descriptor.reading,
                ),
              };

        return KanjiCandidate(
          kanji: descriptor.kanji,
          line1: descriptor.kanji,
          line2: '',
          reading: reading,
          reason: '${descriptor.reason} $tone',
        );
      })
      .toList(growable: false);
}
