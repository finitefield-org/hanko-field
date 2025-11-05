import 'package:app/core/app_state/app_locale.dart';
import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/user_repository.dart';
import 'package:app/features/cart/application/checkout_address_controller.dart';
import 'package:app/features/cart/application/checkout_state_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubExperienceGateNotifier extends ExperienceGateNotifier {
  _StubExperienceGateNotifier(this.gate);

  final ExperienceGate gate;

  @override
  Future<ExperienceGate> build() async => gate;
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository(List<UserAddress> seed)
    : _addresses = List<UserAddress>.from(seed);

  final List<UserAddress> _addresses;
  int _nextId = 100;

  @override
  Future<List<UserAddress>> fetchAddresses() async {
    return List<UserAddress>.unmodifiable(_addresses);
  }

  @override
  Future<UserAddress> upsertAddress(UserAddress address) async {
    if (address.id.isEmpty) {
      final newId = 'addr_${_nextId++}';
      final created = address.copyWith(
        id: newId,
        createdAt: address.createdAt,
        updatedAt: address.updatedAt,
      );
      _addresses.add(created);
      return created;
    }
    final index = _addresses.indexWhere((item) => item.id == address.id);
    if (index == -1) {
      _addresses.add(address);
      return address;
    }
    _addresses[index] = address;
    return address;
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    _addresses.removeWhere((item) => item.id == addressId);
  }

  // Unused members in these tests.
  @override
  Future<UserProfile> fetchCurrentUser() => Future.error(UnimplementedError());

  @override
  Future<UserProfile> updateProfile(UserProfile profile) =>
      Future.error(UnimplementedError());

  @override
  Future<List<UserPaymentMethod>> fetchPaymentMethods() =>
      Future.error(UnimplementedError());

  @override
  Future<void> removePaymentMethod(String methodId) =>
      Future.error(UnimplementedError());

  @override
  Future<List<UserFavoriteDesign>> fetchFavorites() =>
      Future.error(UnimplementedError());

  @override
  Future<void> addFavorite(UserFavoriteDesign favorite) =>
      Future.error(UnimplementedError());

  @override
  Future<void> removeFavorite(String favoriteId) =>
      Future.error(UnimplementedError());
}

ExperienceGate _buildExperience({bool international = false}) {
  return ExperienceGate(
    locale: const Locale('ja', 'JP'),
    systemLocale: const Locale('ja', 'JP'),
    localeSource: AppLocaleSource.system,
    persona: UserPersona.japanese,
    region: international
        ? ExperienceRegion.international
        : ExperienceRegion.japanDomestic,
    currencyCode: international ? 'USD' : 'JPY',
    currencySymbol: international ? r'$' : '¥',
    creationStages: const [],
    creationSubtitle: '',
    shopSubtitle: '',
    ordersSubtitle: '',
    librarySubtitle: '',
    profileSubtitle: '',
  );
}

UserAddress _address({
  required String id,
  bool isDefault = false,
  String country = 'JP',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final baseCreated = createdAt ?? DateTime.utc(2024, 1, 1);
  return UserAddress(
    id: id,
    label: null,
    recipient: 'Recipient $id',
    company: null,
    line1: 'Line 1 $id',
    line2: null,
    city: 'City $id',
    state: country == 'JP' ? 'Prefecture $id' : 'State $id',
    postalCode: country == 'JP' ? '100-0001' : '90210',
    country: country,
    phone: null,
    isDefault: isDefault,
    createdAt: baseCreated,
    updatedAt: updatedAt,
  );
}

void main() {
  group('CheckoutAddressController', () {
    test('build selects default address and sorts list', () async {
      final experience = _buildExperience();
      final repo = _FakeUserRepository([
        _address(id: 'b', createdAt: DateTime.utc(2024, 1, 2)),
        _address(id: 'a', isDefault: true, createdAt: DateTime.utc(2024, 1, 1)),
      ]);

      final container = ProviderContainer(
        overrides: [
          experienceGateProvider.overrideWith(
            () => _StubExperienceGateNotifier(experience),
          ),
          userRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(
        checkoutAddressControllerProvider.future,
      );

      expect(state.addresses.first.id, 'a');
      expect(state.selectedAddressId, 'a');
      final checkoutState = container.read(checkoutStateProvider);
      expect(checkoutState.selectedAddressId, 'a');
    });

    test('saveAddress inserts new address and selects it', () async {
      final experience = _buildExperience();
      final repo = _FakeUserRepository([
        _address(id: 'existing', isDefault: true),
      ]);

      final container = ProviderContainer(
        overrides: [
          experienceGateProvider.overrideWith(
            () => _StubExperienceGateNotifier(experience),
          ),
          userRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(checkoutAddressControllerProvider.future);
      final notifier = container.read(
        checkoutAddressControllerProvider.notifier,
      );

      final draft = CheckoutAddressDraft(
        recipient: 'New Recipient',
        label: 'Home',
        company: '',
        line1: '1-2-3 Street',
        city: 'Tokyo',
        state: 'Tokyo',
        postalCode: '1500001',
        country: 'JP',
        phone: '0312345678',
      );

      final saved = await notifier.saveAddress(draft);
      expect(saved, isNotNull);

      final state = container.read(checkoutAddressControllerProvider).value;
      expect(state?.addresses.length, 2);
      expect(state?.selectedAddressId, saved?.id);

      final checkoutState = container.read(checkoutStateProvider);
      expect(checkoutState.selectedAddressId, saved?.id);
    });

    test(
      'deleteAddress removes selected address and falls back to next one',
      () async {
        final experience = _buildExperience();
        final repo = _FakeUserRepository([
          _address(id: 'one', isDefault: true),
          _address(id: 'two'),
        ]);

        final container = ProviderContainer(
          overrides: [
            experienceGateProvider.overrideWith(
              () => _StubExperienceGateNotifier(experience),
            ),
            userRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(checkoutAddressControllerProvider.future);
        final notifier = container.read(
          checkoutAddressControllerProvider.notifier,
        );

        final deleted = await notifier.deleteAddress('one');
        expect(deleted, isTrue);

        final state = container.read(checkoutAddressControllerProvider).value;
        expect(state?.addresses.length, 1);
        expect(state?.selectedAddressId, 'two');
        final checkoutState = container.read(checkoutStateProvider);
        expect(checkoutState.selectedAddressId, 'two');
      },
    );

    test('lookupPostalCode returns sample dataset matches', () async {
      final experience = _buildExperience();
      final repo = _FakeUserRepository([
        _address(id: 'default', isDefault: true),
      ]);
      final container = ProviderContainer(
        overrides: [
          experienceGateProvider.overrideWith(
            () => _StubExperienceGateNotifier(experience),
          ),
          userRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(checkoutAddressControllerProvider.future);
      final notifier = container.read(
        checkoutAddressControllerProvider.notifier,
      );

      final result = await notifier.lookupPostalCode('100-0001');
      expect(result, isNotNull);
      expect(result?.prefecture, '東京都');
      expect(result?.city, '千代田区');
    });
  });
}
