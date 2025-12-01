// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:app/core/storage/preferences.dart';
import 'package:app/features/users/data/dtos/user_dtos.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/features/users/data/repositories/user_repository.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

const _userProfileKey = 'user.profile';

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
  Future<List<UserAddress>> listAddresses() async => const [];

  @override
  Future<UserAddress> addAddress(UserAddress address) {
    throw UnimplementedError('Address management not implemented yet.');
  }

  @override
  Future<UserAddress> updateAddress(UserAddress address) {
    throw UnimplementedError('Address management not implemented yet.');
  }

  @override
  Future<void> deleteAddress(String addressId) {
    throw UnimplementedError('Address management not implemented yet.');
  }

  @override
  Future<List<PaymentMethod>> listPaymentMethods() async => const [];

  @override
  Future<PaymentMethod> addPaymentMethod(PaymentMethod method) {
    throw UnimplementedError('Payment method management not implemented yet.');
  }

  @override
  Future<void> removePaymentMethod(String methodId) {
    throw UnimplementedError('Payment method management not implemented yet.');
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
}

UserPersona _personaForLocale(String languageCode) {
  final normalized = languageCode.toLowerCase();
  const jpCodes = {'ja', 'ja-jp'};
  if (jpCodes.contains(normalized)) return UserPersona.japanese;
  return UserPersona.foreigner;
}
