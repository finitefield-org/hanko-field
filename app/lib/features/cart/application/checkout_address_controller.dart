import 'dart:async';
import 'dart:collection';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/user_repository.dart';
import 'package:app/features/cart/application/checkout_state_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkoutAddressControllerProvider =
    AsyncNotifierProvider<CheckoutAddressController, CheckoutAddressState>(
      CheckoutAddressController.new,
      name: 'checkoutAddressControllerProvider',
    );

const Object _sentinel = Object();

class CheckoutAddressState {
  CheckoutAddressState({
    required this.addresses,
    required this.selectedAddressId,
    this.isRefreshing = false,
    this.isSaving = false,
    this.savingAddressId,
    Set<String>? deletingAddressIds,
    this.feedbackMessage,
    this.errorMessage,
  }) : deletingAddressIds = UnmodifiableSetView<String>(
         deletingAddressIds ?? const <String>{},
       );

  final UnmodifiableListView<UserAddress> addresses;
  final String? selectedAddressId;
  final bool isRefreshing;
  final bool isSaving;
  final String? savingAddressId;
  final UnmodifiableSetView<String> deletingAddressIds;
  final String? feedbackMessage;
  final String? errorMessage;

  bool get hasAddresses => addresses.isNotEmpty;

  CheckoutAddressState copyWith({
    List<UserAddress>? addresses,
    Object? selectedAddressId = _sentinel,
    bool? isRefreshing,
    bool? isSaving,
    Object? savingAddressId = _sentinel,
    Set<String>? deletingAddressIds,
    String? feedbackMessage,
    bool clearFeedback = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CheckoutAddressState(
      addresses: addresses == null
          ? this.addresses
          : UnmodifiableListView<UserAddress>(addresses),
      selectedAddressId: identical(selectedAddressId, _sentinel)
          ? this.selectedAddressId
          : selectedAddressId as String?,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
      savingAddressId: identical(savingAddressId, _sentinel)
          ? this.savingAddressId
          : savingAddressId as String?,
      deletingAddressIds: deletingAddressIds == null
          ? this.deletingAddressIds
          : UnmodifiableSetView<String>(deletingAddressIds),
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CheckoutAddressController extends AsyncNotifier<CheckoutAddressState> {
  late ExperienceGate _experience;

  UserRepository get _repository => ref.read(userRepositoryProvider);

  CheckoutStateNotifier get _checkoutState =>
      ref.read(checkoutStateProvider.notifier);

  @override
  Future<CheckoutAddressState> build() async {
    _experience = await ref.watch(experienceGateProvider.future);
    final addresses = await _repository.fetchAddresses();
    final sorted = _sortAddresses(addresses);
    final selected = _resolveInitialSelection(sorted);
    if (selected != null) {
      _checkoutState.setSelectedAddress(selected);
    } else {
      _checkoutState.clearSelectedAddress();
    }
    return CheckoutAddressState(
      addresses: UnmodifiableListView<UserAddress>(sorted),
      selectedAddressId: selected?.id,
    );
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current == null) {
      state = const AsyncValue.loading();
    } else {
      state = AsyncValue.data(
        current.copyWith(
          isRefreshing: true,
          clearFeedback: true,
          clearError: true,
        ),
      );
    }
    try {
      final addresses = await _repository.fetchAddresses();
      final sorted = _sortAddresses(addresses);
      final selected = _resolveSelectionAfterRefresh(
        sorted,
        current?.selectedAddressId,
      );
      if (selected != null) {
        _checkoutState.setSelectedAddress(selected);
      } else {
        _checkoutState.clearSelectedAddress();
      }
      state = AsyncValue.data(
        CheckoutAddressState(
          addresses: UnmodifiableListView<UserAddress>(sorted),
          selectedAddressId: selected?.id,
        ),
      );
    } catch (error, stackTrace) {
      if (current == null) {
        state = AsyncValue.error(error, stackTrace);
        return;
      }
      state = AsyncValue.data(
        current.copyWith(
          isRefreshing: false,
          errorMessage: _localized(
            '住所帳の更新に失敗しました',
            'Unable to refresh addresses.',
          ),
          clearFeedback: true,
        ),
      );
    }
  }

  void clearMessages() {
    final current = state.value;
    if (current == null ||
        (current.feedbackMessage == null && current.errorMessage == null)) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(clearFeedback: true, clearError: true),
    );
  }

  void selectAddress(String addressId) {
    final current = state.value;
    if (current == null || current.selectedAddressId == addressId) {
      return;
    }
    final address = _findAddress(current.addresses, addressId);
    if (address == null) {
      return;
    }
    _checkoutState.setSelectedAddress(address);
    state = AsyncValue.data(
      current.copyWith(
        selectedAddressId: addressId,
        clearFeedback: true,
        clearError: true,
      ),
    );
  }

  Future<UserAddress?> saveAddress(CheckoutAddressDraft draft) async {
    final current = state.value;
    if (current == null || state.isLoading) {
      return null;
    }
    state = AsyncValue.data(
      current.copyWith(
        isSaving: true,
        savingAddressId: draft.original?.id,
        clearFeedback: true,
        clearError: true,
      ),
    );
    try {
      final normalizedDraft = _normalizeDraft(draft);
      final saved = await _repository.upsertAddress(normalizedDraft.toDomain());
      final merged = _mergeAddresses(current.addresses, saved);
      final sorted = _sortAddresses(merged);
      final shouldSelect =
          draft.selectAfterSave ??
          draft.isNew ||
              current.selectedAddressId == null ||
              (draft.original != null &&
                  draft.original!.id == current.selectedAddressId);
      if (shouldSelect) {
        _checkoutState.setSelectedAddress(saved);
      }
      state = AsyncValue.data(
        current.copyWith(
          addresses: sorted,
          selectedAddressId: shouldSelect
              ? saved.id
              : current.selectedAddressId,
          isSaving: false,
          savingAddressId: null,
          feedbackMessage: _localized('住所を保存しました', 'Address saved.'),
        ),
      );
      return saved;
    } catch (error) {
      state = AsyncValue.data(
        current.copyWith(
          isSaving: false,
          savingAddressId: null,
          errorMessage: _localized('住所の保存に失敗しました', 'Failed to save address.'),
        ),
      );
      return null;
    }
  }

  Future<bool> deleteAddress(String addressId) async {
    final current = state.value;
    if (current == null ||
        state.isLoading ||
        current.deletingAddressIds.contains(addressId)) {
      return false;
    }
    final target = _findAddress(current.addresses, addressId);
    if (target == null) {
      return false;
    }
    final deleting = {...current.deletingAddressIds, addressId};
    state = AsyncValue.data(
      current.copyWith(
        deletingAddressIds: deleting,
        clearFeedback: true,
        clearError: true,
      ),
    );

    try {
      await _repository.deleteAddress(addressId);
      final remaining = [
        for (final address in current.addresses)
          if (address.id != addressId) address,
      ];
      final sorted = _sortAddresses(remaining);
      final wasSelected = current.selectedAddressId == addressId;
      UserAddress? nextSelection;
      if (wasSelected) {
        nextSelection = _resolveSelectionAfterRefresh(sorted, null);
        if (nextSelection != null) {
          _checkoutState.setSelectedAddress(nextSelection);
        } else {
          _checkoutState.clearSelectedAddress();
        }
      }
      state = AsyncValue.data(
        current.copyWith(
          addresses: sorted,
          selectedAddressId: wasSelected
              ? nextSelection?.id
              : current.selectedAddressId,
          deletingAddressIds: current.deletingAddressIds.toSet()
            ..remove(addressId),
          feedbackMessage: _localized('住所を削除しました', 'Address deleted.'),
        ),
      );
      return true;
    } catch (error) {
      state = AsyncValue.data(
        current.copyWith(
          deletingAddressIds: current.deletingAddressIds.toSet()
            ..remove(addressId),
          errorMessage: _localized('住所の削除に失敗しました', 'Failed to delete address.'),
        ),
      );
      return false;
    }
  }

  Future<PostalLookupResult?> lookupPostalCode(String postalCode) async {
    final normalized = _normalizePostalCode(postalCode);
    if (normalized.length != 7) {
      return null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _postalSamples[normalized];
  }

  UserAddress? _resolveInitialSelection(List<UserAddress> addresses) {
    if (addresses.isEmpty) {
      return null;
    }
    final checkout = ref.read(checkoutStateProvider);
    final storedId = checkout.selectedAddressId;
    if (storedId != null) {
      final stored = _findAddress(addresses, storedId);
      if (stored != null) {
        return stored;
      }
    }
    final defaultAddress = _findDefault(addresses);
    return defaultAddress ?? addresses.first;
  }

  UserAddress? _resolveSelectionAfterRefresh(
    List<UserAddress> addresses,
    String? previousSelection,
  ) {
    if (addresses.isEmpty) {
      return null;
    }
    if (previousSelection != null) {
      final existing = _findAddress(addresses, previousSelection);
      if (existing != null) {
        return existing;
      }
    }
    final checkout = ref.read(checkoutStateProvider);
    final storedId = checkout.selectedAddressId;
    if (storedId != null) {
      final existing = _findAddress(addresses, storedId);
      if (existing != null) {
        return existing;
      }
    }
    final defaultAddress = _findDefault(addresses);
    return defaultAddress ?? addresses.first;
  }

  UserAddress? _findDefault(Iterable<UserAddress> addresses) {
    for (final address in addresses) {
      if (address.isDefault) {
        return address;
      }
    }
    return null;
  }

  UserAddress? _findAddress(Iterable<UserAddress> addresses, String id) {
    for (final address in addresses) {
      if (address.id == id) {
        return address;
      }
    }
    return null;
  }

  List<UserAddress> _mergeAddresses(
    Iterable<UserAddress> existing,
    UserAddress next,
  ) {
    final result = <UserAddress>[];
    var replaced = false;
    for (final address in existing) {
      if (address.id == next.id) {
        result.add(next);
        replaced = true;
      } else {
        result.add(address);
      }
    }
    if (!replaced) {
      result.add(next);
    }
    return result;
  }

  List<UserAddress> _sortAddresses(Iterable<UserAddress> addresses) {
    final list = [...addresses];
    list.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      final aTimestamp = a.updatedAt ?? a.createdAt;
      final bTimestamp = b.updatedAt ?? b.createdAt;
      return bTimestamp.compareTo(aTimestamp);
    });
    return list;
  }

  CheckoutAddressDraft _normalizeDraft(CheckoutAddressDraft draft) {
    final now = DateTime.now();
    final base = draft.original;
    final uppercaseCountry = draft.country.trim().toUpperCase();
    String? normalizeOptional(String? value) {
      if (value == null) {
        return null;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final normalizedPostal = uppercaseCountry == 'JP'
        ? _formatJapanesePostalCode(draft.postalCode)
        : draft.postalCode.trim();

    return draft.copyWith(
      recipient: draft.recipient.trim(),
      postalCode: normalizedPostal,
      country: uppercaseCountry,
      state: normalizeOptional(draft.state),
      city: draft.city.trim(),
      line1: draft.line1.trim(),
      line2: normalizeOptional(draft.line2),
      phone: normalizeOptional(draft.phone),
      label: normalizeOptional(draft.label),
      company: normalizeOptional(draft.company),
      updatedAt: now,
      createdAt: base?.createdAt ?? now,
    );
  }

  String _localized(String japanese, String english) {
    return _experience.isInternational ? english : japanese;
  }
}

class CheckoutAddressDraft {
  CheckoutAddressDraft({
    this.original,
    this.label,
    required this.recipient,
    this.company,
    required this.line1,
    this.line2,
    required this.city,
    this.state,
    required this.postalCode,
    required this.country,
    this.phone,
    this.createdAt,
    this.updatedAt,
    this.selectAfterSave,
  });

  final UserAddress? original;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? selectAfterSave;

  bool get isNew => original == null || original!.id.isEmpty;

  CheckoutAddressDraft copyWith({
    UserAddress? original,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? selectAfterSave,
  }) {
    return CheckoutAddressDraft(
      original: original ?? this.original,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      selectAfterSave: selectAfterSave ?? this.selectAfterSave,
    );
  }

  UserAddress toDomain() {
    final now = updatedAt ?? DateTime.now();
    final created = createdAt ?? now;
    final originalId = original?.id ?? '';
    final isDefault = original?.isDefault ?? false;
    return UserAddress(
      id: originalId,
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
      createdAt: created,
      updatedAt: now,
    );
  }

  factory CheckoutAddressDraft.fromAddress(UserAddress address) {
    return CheckoutAddressDraft(
      original: address,
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
      createdAt: address.createdAt,
      updatedAt: address.updatedAt,
    );
  }
}

class PostalLookupResult {
  const PostalLookupResult({
    required this.prefecture,
    required this.city,
    required this.town,
  });

  final String prefecture;
  final String city;
  final String town;
}

const Map<String, PostalLookupResult>
_postalSamples = <String, PostalLookupResult>{
  '1000001': PostalLookupResult(prefecture: '東京都', city: '千代田区', town: '千代田'),
  '1500001': PostalLookupResult(prefecture: '東京都', city: '渋谷区', town: '神宮前'),
  '5420081': PostalLookupResult(prefecture: '大阪府', city: '大阪市中央区', town: '南船場'),
};

String _normalizePostalCode(String postalCode) {
  return postalCode.replaceAll(RegExp(r'[^0-9]'), '');
}

String _formatJapanesePostalCode(String postalCode) {
  final normalized = _normalizePostalCode(postalCode);
  if (normalized.length != 7) {
    return postalCode;
  }
  return '${normalized.substring(0, 3)}-${normalized.substring(3)}';
}
