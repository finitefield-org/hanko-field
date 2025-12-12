// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:app/core/storage/preferences.dart';
import 'package:app/features/users/data/dtos/user_dtos.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/features/users/data/repositories/user_repository.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/security/secure_storage.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userProfileKey = 'user.profile';
const _userAddressesKey = 'user.addresses';
const _userPaymentsKey = 'user.payments';
const _paymentProviderRefPrefix = 'user.payment.providerRef.';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  try {
    return ref.scope(UserRepository.fallback);
  } on StateError {
    return LocalUserRepository(ref);
  }
});

class LocalUserRepository implements UserRepository {
  LocalUserRepository(this._ref) : _logger = Logger('LocalUserRepository');

  final Ref _ref;
  final Logger _logger;

  @override
  Future<UserProfile> fetchProfile() async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final cached = prefs.getString(_userProfileKey);
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, Object?>;
        return UserProfileDto.fromJson(map).toDomain();
      } catch (e, stack) {
        _logger.warning('Failed to parse cached profile', e, stack);
      }
    }

    final firebaseUser = _ref.watch(firebaseAuthProvider).currentUser;
    final locale = _ref.watch(appLocaleProvider);
    final now = DateTime.now().toUtc();

    final profile = UserProfile(
      id: firebaseUser?.uid,
      displayName: firebaseUser?.displayName ?? firebaseUser?.email,
      email: firebaseUser?.email,
      phone: firebaseUser?.phoneNumber,
      avatarUrl: firebaseUser?.photoURL,
      persona: _personaForLocale(locale.languageCode),
      preferredLang: locale.languageCode,
      country: locale.countryCode,
      onboarding: const {},
      marketingOptIn: null,
      role: UserRole.user,
      isActive: true,
      piiMasked: false,
      createdAt: now,
      updatedAt: now,
    );

    await _saveProfile(profile);
    return profile;
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final updated = profile.copyWith(updatedAt: DateTime.now().toUtc());
    await _saveProfile(updated);
    return updated;
  }

  @override
  Future<List<UserAddress>> listAddresses() async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final cached = prefs.getString(_userAddressesKey);
    if (cached != null) {
      try {
        return _decodeAddresses(cached);
      } catch (e, stack) {
        _logger.warning('Failed to parse cached addresses', e, stack);
      }
    }

    final seeded = _seedAddresses();
    await _persistAddresses(prefs, seeded);
    return seeded;
  }

  @override
  Future<UserAddress> addAddress(UserAddress address) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final existing = await listAddresses();
    final now = DateTime.now().toUtc();
    final newAddress = address.copyWith(
      id: address.id ?? 'addr_${now.microsecondsSinceEpoch}',
      isDefault: address.isDefault || existing.isEmpty,
      createdAt: address.createdAt,
      updatedAt: now,
    );

    final updated = newAddress.isDefault
        ? [
            newAddress,
            ...existing.map((item) => item.copyWith(isDefault: false)),
          ]
        : [...existing, newAddress];

    await _persistAddresses(prefs, updated);
    return newAddress;
  }

  @override
  Future<UserAddress> updateAddress(UserAddress address) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final existing = await listAddresses();
    final index = existing.indexWhere((item) => item.id == address.id);
    if (index == -1) {
      throw StateError('Address ${address.id} not found');
    }

    final now = DateTime.now().toUtc();
    final updatedAddress = address.copyWith(
      createdAt: address.createdAt,
      updatedAt: now,
    );

    final next = existing
        .map((item) => item.id == updatedAddress.id ? updatedAddress : item)
        .toList();

    final normalized = updatedAddress.isDefault
        ? [
            updatedAddress,
            ...next
                .where((item) => item.id != updatedAddress.id)
                .map((item) => item.copyWith(isDefault: false)),
          ]
        : next;

    await _persistAddresses(prefs, normalized);
    return updatedAddress;
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final existing = await listAddresses();
    final filtered = existing.where((item) => item.id != addressId).toList();
    if (filtered.isNotEmpty && filtered.every((item) => !item.isDefault)) {
      final first = filtered.first;
      final updated = first.copyWith(
        isDefault: true,
        updatedAt: DateTime.now().toUtc(),
      );
      filtered
        ..removeAt(0)
        ..insert(0, updated);
    }
    await _persistAddresses(prefs, filtered);
  }

  @override
  Future<List<PaymentMethod>> listPaymentMethods() async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final cached = prefs.getString(_userPaymentsKey);
    if (cached != null) {
      try {
        final secure = _ref.watch(secureStorageProvider);
        final list = jsonDecode(cached) as List;
        var didMigrate = false;
        final decoded = <PaymentMethod>[];

        for (final raw in list) {
          final map = (raw as Map).cast<String, Object?>();
          final id = map['id'] as String?;
          final providerRefFromPrefs = map['providerRef'] as String?;

          if (id != null && providerRefFromPrefs != null) {
            await secure.write(
              key: '$_paymentProviderRefPrefix$id',
              value: providerRefFromPrefs,
            );
            didMigrate = true;
          }

          final providerRef =
              providerRefFromPrefs ??
              (id == null
                  ? null
                  : await secure.read(key: '$_paymentProviderRefPrefix$id'));

          if (providerRef == null || providerRef.isEmpty) {
            _logger.warning(
              'Payment method missing providerRef; skipping (id=$id)',
            );
            continue;
          }

          decoded.add(
            PaymentMethodDto.fromJson({
              ...map,
              'providerRef': providerRef,
            }, id: id).toDomain(),
          );
        }

        if (didMigrate) {
          await _persistPayments(prefs, decoded);
        }

        return decoded;
      } catch (e, stack) {
        _logger.warning('Failed to parse cached payments', e, stack);
      }
    }
    return const [];
  }

  @override
  Future<PaymentMethod> addPaymentMethod(PaymentMethod method) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final secure = _ref.watch(secureStorageProvider);
    final existing = await listPaymentMethods();
    final now = DateTime.now().toUtc();
    final id = method.id ?? 'pm_${now.microsecondsSinceEpoch}';
    final newMethod = method.copyWith(id: id, updatedAt: now);
    await secure.write(
      key: '$_paymentProviderRefPrefix$id',
      value: method.providerRef,
    );
    final updated = [newMethod, ...existing];
    await _persistPayments(prefs, updated);
    return newMethod;
  }

  @override
  Future<void> removePaymentMethod(String methodId) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final secure = _ref.watch(secureStorageProvider);
    final existing = await listPaymentMethods();
    final filtered = existing.where((item) => item.id != methodId).toList();
    await _persistPayments(prefs, filtered);
    await secure.delete(key: '$_paymentProviderRefPrefix$methodId');
  }

  @override
  Future<List<FavoriteDesign>> listFavorites() async => const [];

  @override
  Future<void> addFavorite(
    String designId, {
    String? note,
    List<String> tags = const <String>[],
  }) {
    throw UnimplementedError('Favorites not implemented yet.');
  }

  @override
  Future<void> removeFavorite(String designId) {
    throw UnimplementedError('Favorites not implemented yet.');
  }

  Future<void> _saveProfile(UserProfile profile) async {
    final prefs = await _ref.watch(sharedPreferencesProvider.future);
    final dto = UserProfileDto.fromDomain(profile);
    await prefs.setString(_userProfileKey, jsonEncode(dto.toJson()));
  }

  Future<void> _persistAddresses(
    SharedPreferences prefs,
    List<UserAddress> addresses,
  ) async {
    final normalized = [...addresses];
    if (normalized.isNotEmpty && normalized.every((item) => !item.isDefault)) {
      final first = normalized.first;
      normalized
        ..removeAt(0)
        ..insert(
          0,
          first.copyWith(isDefault: true, updatedAt: DateTime.now().toUtc()),
        );
    }

    final sorted = [...normalized];
    sorted.sort(
      (a, b) => a.isDefault == b.isDefault ? 0 : (a.isDefault ? -1 : 1),
    );
    final encoded = sorted.map((item) {
      final dto = UserAddressDto.fromDomain(item);
      final json = dto.toJson();
      return <String, Object?>{'id': item.id, ...json};
    }).toList();
    await prefs.setString(_userAddressesKey, jsonEncode(encoded));
  }

  Future<void> _persistPayments(
    SharedPreferences prefs,
    List<PaymentMethod> methods,
  ) async {
    final encoded = methods.map((method) {
      final dto = PaymentMethodDto.fromDomain(method);
      final map = dto.toJson();
      if (method.id != null) {
        map['id'] = method.id;
      }
      map.remove('providerRef');
      return map;
    }).toList();
    await prefs.setString(_userPaymentsKey, jsonEncode(encoded));
  }

  List<UserAddress> _decodeAddresses(String raw) {
    final list = (jsonDecode(raw) as List).cast<Map<String, Object?>>();
    return list
        .map(
          (item) => UserAddressDto.fromJson(
            item,
            id: item['id'] as String?,
          ).toDomain(),
        )
        .toList();
  }

  List<UserAddress> _seedAddresses() {
    final now = DateTime.now().toUtc();
    return [
      UserAddress(
        id: 'addr_default',
        label: '自宅',
        recipient: '山田 太郎',
        company: null,
        line1: '1-2-3',
        line2: 'ハンコフィールド101',
        city: '渋谷区神宮前',
        state: '東京都',
        postalCode: '150-0001',
        country: 'JP',
        phone: '03-1234-5678',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      UserAddress(
        id: 'addr_intl',
        label: 'Office',
        recipient: 'Alex Kim',
        company: 'Hanko Field Inc.',
        line1: '42 Market Street',
        line2: 'Suite 500',
        city: 'San Francisco',
        state: 'CA',
        postalCode: '94103',
        country: 'US',
        phone: '+1 415 555 1212',
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

UserPersona _personaForLocale(String languageCode) {
  final normalized = languageCode.toLowerCase();
  const jpCodes = {'ja', 'ja-jp'};
  if (jpCodes.contains(normalized)) return UserPersona.japanese;
  return UserPersona.foreigner;
}
