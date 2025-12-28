// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/features/checkout/view_model/checkout_flow_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/features/users/data/repositories/local_user_repository.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum AddressFormLayout { domestic, international }

class AddressFormInput {
  const AddressFormInput({
    this.id,
    this.label = '',
    this.recipient = '',
    this.company = '',
    this.line1 = '',
    this.line2 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = 'JP',
    this.phone = '',
    this.isDefault = false,
    this.layout = AddressFormLayout.domestic,
  });

  final String? id;
  final String label;
  final String recipient;
  final String company;
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String phone;
  final bool isDefault;
  final AddressFormLayout layout;

  AddressFormInput copyWith({
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
    AddressFormLayout? layout,
  }) {
    return AddressFormInput(
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
      layout: layout ?? this.layout,
    );
  }
}

class AddressValidationResult {
  const AddressValidationResult({this.fieldErrors = const {}, this.message});

  final Map<String, String> fieldErrors;
  final String? message;

  bool get isValid => fieldErrors.isEmpty && message == null;
}

class AddressSaveResult {
  const AddressSaveResult({
    required this.validation,
    this.saved,
    this.created = false,
  });

  final AddressValidationResult validation;
  final UserAddress? saved;
  final bool created;

  bool get isSuccess => validation.isValid && saved != null;
}

class AddressLookupResult {
  const AddressLookupResult({
    required this.state,
    required this.city,
    this.line1Hint,
  });

  final String state;
  final String city;
  final String? line1Hint;
}

class CheckoutAddressState {
  const CheckoutAddressState({
    required this.addresses,
    this.selectedAddressId,
    this.lastValidation,
  });

  final List<UserAddress> addresses;
  final String? selectedAddressId;
  final AddressValidationResult? lastValidation;

  UserAddress? get defaultAddress =>
      addresses.firstWhereOrNull((item) => item.isDefault);

  UserAddress? get selectedAddress {
    final effectiveId =
        selectedAddressId ?? defaultAddress?.id ?? addresses.firstOrNull?.id;
    return addresses.firstWhereOrNull((item) => item.id == effectiveId);
  }

  CheckoutAddressState copyWith({
    List<UserAddress>? addresses,
    String? selectedAddressId,
    AddressValidationResult? lastValidation,
    bool clearValidation = false,
  }) {
    return CheckoutAddressState(
      addresses: addresses ?? this.addresses,
      selectedAddressId: selectedAddressId ?? this.selectedAddressId,
      lastValidation: clearValidation
          ? null
          : (lastValidation ?? this.lastValidation),
    );
  }
}

final _addressLogger = Logger('CheckoutAddressViewModel');

class CheckoutAddressViewModel extends AsyncProvider<CheckoutAddressState> {
  CheckoutAddressViewModel() : super.args(null, autoDispose: true);

  late final selectAddressMut = mutation<String?>(#selectAddress);
  late final saveAddressMut = mutation<AddressSaveResult>(#saveAddress);
  late final confirmSelectionMut = mutation<UserAddress?>(#confirmSelection);
  late final postalLookupMut = mutation<AddressLookupResult?>(#postalLookup);

  @override
  Future<CheckoutAddressState> build(Ref ref) async {
    final repository = ref.watch(userRepositoryProvider);
    final flow = ref.watch(checkoutFlowProvider);
    final addresses = await repository.listAddresses();
    final defaultId =
        flow.addressId ??
        addresses.firstWhereOrNull((item) => item.isDefault)?.id;
    final selectedId = defaultId ?? addresses.firstOrNull?.id;

    return CheckoutAddressState(
      addresses: _sort(addresses),
      selectedAddressId: selectedId,
    );
  }

  Call<String?> selectAddress(String? addressId) => mutate(selectAddressMut, (
    ref,
  ) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return addressId;
    final selection =
        current.addresses.firstWhereOrNull((item) => item.id == addressId) ??
        current.selectedAddress;
    ref.state = AsyncData(
      current.copyWith(selectedAddressId: addressId, clearValidation: true),
    );
    if (selection != null) {
      await ref.invoke(
        checkoutFlowProvider.setAddress(
          addressId: selection.id,
          isInternational: _isInternational(selection.country),
        ),
      );
    }
    return addressId;
  }, concurrency: Concurrency.dropLatest);

  Call<AddressSaveResult> saveAddress(
    AddressFormInput input,
  ) => mutate(saveAddressMut, (ref) async {
    final l10n = AppLocalizations(ref.watch(appLocaleProvider));
    final normalized = _normalize(input);
    final validation = _validate(normalized, l10n);
    final current = ref.watch(this).valueOrNull;

    if (!validation.isValid) {
      if (current != null) {
        ref.state = AsyncData(current.copyWith(lastValidation: validation));
      }
      return AddressSaveResult(validation: validation);
    }

    final repository = ref.watch(userRepositoryProvider);
    final now = DateTime.now().toUtc();
    final existing = current?.addresses ?? await repository.listAddresses();

    final baseCreatedAt =
        existing
            .firstWhereOrNull((item) => item.id == normalized.id)
            ?.createdAt ??
        now;

    final candidate = _buildAddress(
      normalized,
      createdAt: baseCreatedAt,
      now: now,
    );
    final saved = normalized.id == null
        ? await repository.addAddress(candidate)
        : await repository.updateAddress(candidate);

    final updated = [...existing.where((item) => item.id != saved.id), saved];
    final sorted = _sort(updated);

    ref.state = AsyncData(
      CheckoutAddressState(
        addresses: sorted,
        selectedAddressId:
            saved.id ?? normalized.id ?? current?.selectedAddressId,
      ),
    );

    try {
      await ref.invoke(
        checkoutFlowProvider.setAddress(
          addressId: saved.id ?? normalized.id,
          isInternational: _isInternational(saved.country),
        ),
      );
    } catch (e, stack) {
      _addressLogger.warning('Failed to persist checkout selection', e, stack);
    }

    final analytics = ref.watch(analyticsClientProvider);
    unawaited(
      analytics.track(
        CheckoutAddressSavedEvent(
          isNew: normalized.id == null,
          isDefault: saved.isDefault,
          country: saved.country,
          isInternational: _isInternational(saved.country),
        ),
      ),
    );

    return AddressSaveResult(
      validation: const AddressValidationResult(),
      saved: saved,
      created: normalized.id == null,
    );
  }, concurrency: Concurrency.restart);

  Call<UserAddress?> confirmSelection() =>
      mutate(confirmSelectionMut, (ref) async {
        final state = ref.watch(this).valueOrNull;
        final selected = state?.selectedAddress ?? state?.defaultAddress;
        if (selected == null) return null;

        await ref.invoke(
          checkoutFlowProvider.setAddress(
            addressId: selected.id,
            isInternational: _isInternational(selected.country),
          ),
        );
        final analytics = ref.watch(analyticsClientProvider);
        unawaited(
          analytics.track(
            CheckoutAddressConfirmedEvent(
              country: selected.country,
              isInternational: _isInternational(selected.country),
              addressCount: state?.addresses.length ?? 0,
            ),
          ),
        );
        return selected;
      }, concurrency: Concurrency.dropLatest);

  Call<AddressLookupResult?> lookupPostalCode(String postalCode) =>
      mutate(postalLookupMut, (ref) async {
        final normalized = postalCode.replaceAll(RegExp('[^0-9]'), '');
        await Future<void>.delayed(const Duration(milliseconds: 120));
        return _postalHints[normalized];
      }, concurrency: Concurrency.restart);
}

final checkoutAddressViewModel = CheckoutAddressViewModel();

UserAddress _buildAddress(
  AddressFormInput input, {
  required DateTime createdAt,
  required DateTime now,
}) {
  return UserAddress(
    id: input.id,
    label: input.label.trim().isEmpty ? null : input.label.trim(),
    recipient: input.recipient.trim(),
    company: input.company.trim().isEmpty ? null : input.company.trim(),
    line1: input.line1.trim(),
    line2: input.line2.trim().isEmpty ? null : input.line2.trim(),
    city: input.city.trim(),
    state: input.state.trim().isEmpty ? null : input.state.trim(),
    postalCode: input.postalCode.trim(),
    country: input.country.trim().toUpperCase(),
    phone: input.phone.trim().isEmpty ? null : input.phone.trim(),
    isDefault: input.isDefault,
    createdAt: createdAt,
    updatedAt: now,
  );
}

AddressFormInput _normalize(AddressFormInput input) {
  final trimmedCountry = input.country.trim().toUpperCase();
  final layout = trimmedCountry == 'JP'
      ? AddressFormLayout.domestic
      : AddressFormLayout.international;
  return input.copyWith(
    country: trimmedCountry,
    layout: layout,
    postalCode: input.postalCode.trim(),
  );
}

AddressValidationResult _validate(
  AddressFormInput input,
  AppLocalizations l10n,
) {
  final errors = <String, String>{};
  final postal = input.postalCode.trim();
  final phone = input.phone.trim();
  final country = input.country.trim().toUpperCase();

  final requiredLabel = l10n.checkoutAddressRequired;
  if (input.recipient.trim().isEmpty) {
    errors['recipient'] = l10n.checkoutAddressRecipientRequired;
  }
  if (input.line1.trim().isEmpty) {
    errors['line1'] = l10n.checkoutAddressLine1Required;
  }
  if (input.city.trim().isEmpty) {
    errors['city'] = l10n.checkoutAddressCityRequired;
  }
  if (country.isEmpty) {
    errors['country'] = requiredLabel;
  }

  if (input.layout == AddressFormLayout.domestic) {
    final regex = RegExp(r'^\d{3}-?\d{4}$');
    if (!regex.hasMatch(postal)) {
      errors['postalCode'] = l10n.checkoutAddressPostalFormat;
    }
    if (input.state.trim().isEmpty) {
      errors['state'] = l10n.checkoutAddressStateRequired;
    }
    if (country != 'JP') {
      errors['country'] = l10n.checkoutAddressCountryJapanRequired;
    }
    if (phone.isNotEmpty && phone.replaceAll('-', '').length < 10) {
      errors['phone'] = l10n.checkoutAddressPhoneDomestic;
    }
  } else {
    if (postal.length < 3) {
      errors['postalCode'] = l10n.checkoutAddressPostalShort;
    }
    if (country.length < 2) {
      errors['country'] = l10n.checkoutAddressCountryRequired;
    }
    if (phone.isNotEmpty && phone.length < 8) {
      errors['phone'] = l10n.checkoutAddressPhoneInternational;
    }
  }

  return AddressValidationResult(
    fieldErrors: errors.isEmpty ? const {} : errors,
  );
}

List<UserAddress> _sort(List<UserAddress> addresses) {
  final sorted = [...addresses];
  sorted.sort((a, b) {
    if (a.isDefault == b.isDefault) {
      final aUpdated = a.updatedAt ?? a.createdAt;
      final bUpdated = b.updatedAt ?? b.createdAt;
      return bUpdated.compareTo(aUpdated);
    }
    return a.isDefault ? -1 : 1;
  });
  return sorted;
}

bool _isInternational(String country) => country.toUpperCase() != 'JP';

const Map<String, AddressLookupResult> _postalHints =
    <String, AddressLookupResult>{
      '1000001': AddressLookupResult(
        state: '東京都',
        city: '千代田区千代田',
        line1Hint: '1-1',
      ),
      '1500001': AddressLookupResult(
        state: '東京都',
        city: '渋谷区神宮前',
        line1Hint: '1-2-3',
      ),
      '6048006': AddressLookupResult(
        state: '京都府',
        city: '京都市中京区',
        line1Hint: '烏丸通',
      ),
    };
