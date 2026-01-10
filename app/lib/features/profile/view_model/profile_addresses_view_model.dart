// ignore_for_file: public_member_api_docs

import 'package:app/features/checkout/view_model/checkout_flow_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/features/users/data/repositories/local_user_repository.dart';
import 'package:app/features/users/data/repositories/user_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileAddressesState {
  const ProfileAddressesState({required this.addresses});

  final List<UserAddress> addresses;

  UserAddress? get defaultAddress =>
      addresses.firstWhereOrNull((item) => item.isDefault);
}

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

final _logger = Logger('ProfileAddressesViewModel');

class ProfileAddressesViewModel extends AsyncProvider<ProfileAddressesState> {
  ProfileAddressesViewModel() : super.args(null, autoDispose: true);

  late final setDefaultMut = mutation<void>(#setDefault);
  late final saveAddressMut = mutation<AddressSaveResult>(#saveAddress);
  late final deleteAddressMut = mutation<void>(#deleteAddress);

  @override
  Future<ProfileAddressesState> build(
    Ref<AsyncValue<ProfileAddressesState>> ref,
  ) async {
    final repository = ref.watch(userRepositoryProvider);
    final addresses = await repository.listAddresses();
    return ProfileAddressesState(addresses: _sort(addresses));
  }

  Call<void, AsyncValue<ProfileAddressesState>> setDefault(String addressId) =>
      mutate(setDefaultMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return;

        final previousDefaultId = current.defaultAddress?.id;
        final now = DateTime.now().toUtc();
        final next = current.addresses
            .map(
              (item) => item.copyWith(
                isDefault: item.id == addressId,
                updatedAt: item.id == addressId ? now : item.updatedAt,
              ),
            )
            .toList();
        ref.state = AsyncData(ProfileAddressesState(addresses: _sort(next)));

        final repository = ref.watch(userRepositoryProvider);
        final target = next.firstWhereOrNull((item) => item.id == addressId);
        if (target == null) return;
        await repository.updateAddress(target);

        var refreshed = await repository.listAddresses();
        refreshed = await _ensureSingleDefault(
          repository,
          refreshed,
          now: now,
          preferredDefaultId: addressId,
        );
        ref.state = AsyncData(
          ProfileAddressesState(addresses: _sort(refreshed)),
        );

        await _syncCheckoutAddressIfNeeded(
          ref,
          previousDefaultId: previousDefaultId,
          newDefaultId: addressId,
        );
      }, concurrency: Concurrency.dropLatest);

  Call<AddressSaveResult, AsyncValue<ProfileAddressesState>> saveAddress(
    AddressFormInput input,
  ) => mutate(saveAddressMut, (ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    final normalized = _normalize(input);
    final validation = _validate(normalized, gates.prefersEnglish);
    if (!validation.isValid) {
      return AddressSaveResult(validation: validation);
    }

    final repository = ref.watch(userRepositoryProvider);
    final now = DateTime.now().toUtc();

    final current = ref.watch(this).valueOrNull;
    final previousDefaultId = current?.defaultAddress?.id;
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

    var refreshed = await repository.listAddresses();
    refreshed = await _ensureSingleDefault(
      repository,
      refreshed,
      now: now,
      preferredDefaultId: normalized.isDefault ? saved.id : null,
    );
    if (refreshed.isNotEmpty && refreshed.every((item) => !item.isDefault)) {
      final sorted = _sort(refreshed);
      final fallbackDefault =
          sorted.firstWhereOrNull((item) => item.id != saved.id) ??
          sorted.first;
      await repository.updateAddress(
        fallbackDefault.copyWith(isDefault: true, updatedAt: now),
      );
      refreshed = await repository.listAddresses();
    }

    ref.state = AsyncData(ProfileAddressesState(addresses: _sort(refreshed)));

    final newDefaultId = refreshed
        .firstWhereOrNull((item) => item.isDefault)
        ?.id;
    if (newDefaultId != null) {
      await _syncCheckoutAddressIfNeeded(
        ref,
        previousDefaultId: previousDefaultId,
        newDefaultId: newDefaultId,
      );
    }

    return AddressSaveResult(
      validation: const AddressValidationResult(),
      saved: saved,
      created: normalized.id == null,
    );
  }, concurrency: Concurrency.restart);

  Call<void, AsyncValue<ProfileAddressesState>> deleteAddress(
    String addressId,
  ) => mutate(deleteAddressMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      final wasDefault = current.defaultAddress?.id == addressId;
      final next = current.addresses
          .where((item) => item.id != addressId)
          .toList();
      if (wasDefault &&
          next.isNotEmpty &&
          next.every((item) => !item.isDefault)) {
        final promoted = next.first.copyWith(
          isDefault: true,
          updatedAt: DateTime.now().toUtc(),
        );
        next
          ..removeAt(0)
          ..insert(0, promoted);
      }
      ref.state = AsyncData(ProfileAddressesState(addresses: _sort(next)));
    }

    final repository = ref.watch(userRepositoryProvider);
    await repository.deleteAddress(addressId);

    var refreshed = await repository.listAddresses();
    refreshed = await _ensureSingleDefault(
      repository,
      refreshed,
      now: DateTime.now().toUtc(),
    );
    if (refreshed.isNotEmpty && refreshed.every((item) => !item.isDefault)) {
      final sorted = _sort(refreshed);
      final fallbackDefault = sorted.first;
      if (fallbackDefault.id != null) {
        await repository.updateAddress(
          fallbackDefault.copyWith(
            isDefault: true,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        refreshed = await repository.listAddresses();
      }
    }

    ref.state = AsyncData(ProfileAddressesState(addresses: _sort(refreshed)));

    await _syncCheckoutAfterDelete(
      ref,
      deletedId: addressId,
      addresses: refreshed,
    );
  }, concurrency: Concurrency.queue);

  Future<void> _syncCheckoutAddressIfNeeded(
    Ref<AsyncValue<ProfileAddressesState>> ref, {
    required String? previousDefaultId,
    required String newDefaultId,
  }) async {
    final flow = ref.watch(checkoutFlowProvider);
    final currentShippingId = flow.addressId;
    if (currentShippingId != null && currentShippingId != previousDefaultId) {
      return;
    }

    final state = ref.watch(this).valueOrNull;
    final defaultAddress = state?.addresses.firstWhereOrNull(
      (item) => item.id == newDefaultId,
    );
    if (defaultAddress == null) return;

    try {
      await ref.invoke(
        checkoutFlowProvider.setAddress(
          addressId: defaultAddress.id,
          isInternational: _isInternational(defaultAddress.country),
        ),
      );
    } catch (e, stack) {
      _logger.warning('Failed to sync checkout shipping address', e, stack);
    }
  }

  Future<void> _syncCheckoutAfterDelete(
    Ref<AsyncValue<ProfileAddressesState>> ref, {
    required String deletedId,
    required List<UserAddress> addresses,
  }) async {
    final flow = ref.watch(checkoutFlowProvider);
    if (flow.addressId != deletedId) return;

    final defaultAddress = addresses.firstWhereOrNull((item) => item.isDefault);
    try {
      await ref.invoke(
        checkoutFlowProvider.setAddress(
          addressId: defaultAddress?.id,
          isInternational: defaultAddress == null
              ? false
              : _isInternational(defaultAddress.country),
        ),
      );
    } catch (e, stack) {
      _logger.warning('Failed to sync checkout after address delete', e, stack);
    }
  }
}

final profileAddressesViewModel = ProfileAddressesViewModel();

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

AddressValidationResult _validate(AddressFormInput input, bool prefersEnglish) {
  final errors = <String, String>{};
  final postal = input.postalCode.trim();
  final phone = input.phone.trim();
  final country = input.country.trim().toUpperCase();

  final requiredLabel = prefersEnglish ? 'Required' : '必須項目です';
  if (input.recipient.trim().isEmpty) {
    errors['recipient'] = prefersEnglish
        ? 'Recipient is required'
        : '受取人を入力してください';
  }
  if (input.line1.trim().isEmpty) {
    errors['line1'] = prefersEnglish
        ? 'Address line is required'
        : '住所（番地）を入力してください';
  }
  if (input.city.trim().isEmpty) {
    errors['city'] = prefersEnglish ? 'City/Ward is required' : '市区町村を入力してください';
  }
  if (country.isEmpty) {
    errors['country'] = requiredLabel;
  }

  if (input.layout == AddressFormLayout.domestic) {
    final regex = RegExp(r'^\d{3}-?\d{4}$');
    if (!regex.hasMatch(postal)) {
      errors['postalCode'] = prefersEnglish
          ? 'Use 123-4567 format'
          : '郵便番号は123-4567の形式で入力してください';
    }
    if (input.state.trim().isEmpty) {
      errors['state'] = prefersEnglish
          ? 'Prefecture is required'
          : '都道府県を入力してください';
    }
    if (country != 'JP') {
      errors['country'] = prefersEnglish
          ? 'Set country to Japan (JP)'
          : '国内配送は国をJPにしてください';
    }
    if (phone.isNotEmpty && phone.replaceAll('-', '').length < 10) {
      errors['phone'] = prefersEnglish
          ? 'Include area code (10+ digits)'
          : '市外局番を含めて10桁以上で入力してください';
    }
  } else {
    if (postal.length < 3) {
      errors['postalCode'] = prefersEnglish
          ? 'Postal/ZIP is too short'
          : '郵便番号を正しく入力してください';
    }
    if (country.length < 2) {
      errors['country'] = prefersEnglish
          ? 'Country/region is required'
          : '国・地域を入力してください';
    }
    if (phone.isNotEmpty && phone.length < 8) {
      errors['phone'] = prefersEnglish
          ? 'Add country code (e.g., +1)'
          : '国番号付きで入力してください（例: +81）';
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

Future<List<UserAddress>> _ensureSingleDefault(
  UserRepository repository,
  List<UserAddress> addresses, {
  required DateTime now,
  String? preferredDefaultId,
}) async {
  if (addresses.isEmpty) return addresses;

  final defaults = addresses.where((item) => item.isDefault).toList();
  final preferred = preferredDefaultId == null
      ? null
      : addresses.firstWhereOrNull((item) => item.id == preferredDefaultId);

  if (preferred != null) {
    final needsChange =
        !preferred.isDefault ||
        defaults.length != 1 ||
        (defaults.length == 1 && defaults.first.id != preferred.id);
    if (!needsChange) return addresses;

    for (final address in addresses) {
      final id = address.id;
      if (id == null) continue;
      final shouldBeDefault = id == preferred.id;
      if (address.isDefault == shouldBeDefault) continue;
      await repository.updateAddress(
        address.copyWith(isDefault: shouldBeDefault, updatedAt: now),
      );
    }
    return repository.listAddresses();
  }

  if (defaults.length <= 1) return addresses;

  final keepId = defaults.first.id;
  for (final address in addresses) {
    final id = address.id;
    if (id == null) continue;
    final shouldBeDefault = id == keepId;
    if (address.isDefault == shouldBeDefault) continue;
    await repository.updateAddress(
      address.copyWith(isDefault: shouldBeDefault, updatedAt: now),
    );
  }
  return repository.listAddresses();
}
