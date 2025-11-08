import 'package:app/core/data/dtos/user_dto.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/user_repository.dart';
import 'package:app/core/network/network_client.dart';
import 'package:app/core/network/network_exception.dart';
import 'package:app/core/network/network_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiUserRepository extends UserRepository {
  ApiUserRepository(this._client);

  final NetworkClient _client;

  @override
  Future<UserProfile> fetchCurrentUser() async {
    final json = await _client.get<Map<String, dynamic>>(
      '/me',
      parser: _expectMap,
    );
    return mapUserProfile(UserProfileDto.fromJson(json));
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final dto = mapUserProfileToDto(profile);
    final json = await _client.put<Map<String, dynamic>>(
      '/me',
      data: dto.toJson(),
      parser: _expectMap,
    );
    return mapUserProfile(UserProfileDto.fromJson(json));
  }

  @override
  Future<List<UserAddress>> fetchAddresses() async {
    final list = await _client.get<List<dynamic>>(
      '/me/addresses',
      parser: _expectList,
    );
    return [
      for (final item in list)
        mapUserAddress(UserAddressDto.fromJson(_expectMap(item))),
    ];
  }

  @override
  Future<UserAddress> upsertAddress(UserAddress address) async {
    final dto = mapUserAddressToDto(address);
    final payload = dto.toJson();
    Map<String, dynamic>? response;

    if (address.id.isEmpty) {
      response = await _client.post<Map<String, dynamic>>(
        '/me/addresses',
        data: payload,
        parser: _expectMap,
      );
    } else {
      response = await _client.put<Map<String, dynamic>?>(
        '/me/addresses/${dto.id}',
        data: payload,
        parser: _expectMapOrNull,
      );
    }

    return mapUserAddress(UserAddressDto.fromJson(response ?? payload));
  }

  @override
  Future<void> deleteAddress(String addressId) {
    return _client.delete<void>('/me/addresses/$addressId');
  }

  @override
  Future<List<UserPaymentMethod>> fetchPaymentMethods() async {
    final list = await _client.get<List<dynamic>>(
      '/me/payment-methods',
      parser: _expectList,
    );
    return [
      for (final item in list)
        mapPaymentMethod(UserPaymentMethodDto.fromJson(_expectMap(item))),
    ];
  }

  @override
  Future<UserPaymentMethod> addPaymentMethod(UserPaymentMethod method) async {
    final dto = mapPaymentMethodToDto(method);
    final response = await _client.post<Map<String, dynamic>>(
      '/me/payment-methods',
      data: dto.toJson(),
      parser: _expectMap,
    );
    return mapPaymentMethod(UserPaymentMethodDto.fromJson(response));
  }

  @override
  Future<void> removePaymentMethod(String methodId) {
    return _client.delete<void>('/me/payment-methods/$methodId');
  }

  @override
  Future<List<UserFavoriteDesign>> fetchFavorites() async {
    final list = await _client.get<List<dynamic>>(
      '/me/favorites',
      parser: _expectList,
    );
    return [
      for (final item in list)
        mapFavoriteDesign(UserFavoriteDesignDto.fromJson(_expectMap(item))),
    ];
  }

  @override
  Future<void> addFavorite(UserFavoriteDesign favorite) {
    final dto = mapFavoriteDesignToDto(favorite);
    return _client.put<void>(
      '/me/favorites/${dto.designRef}',
      data: dto.toJson(),
    );
  }

  @override
  Future<void> removeFavorite(String favoriteId) {
    return _client.delete<void>('/me/favorites/$favoriteId');
  }

  static Map<String, dynamic> _expectMap(dynamic value) {
    if (value == null) {
      throw const NetworkSerializationException(
        'Expected response payload but received empty body.',
      );
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw NetworkSerializationException(
      'Expected map payload but received ${value.runtimeType}.',
    );
  }

  static Map<String, dynamic>? _expectMapOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    return _expectMap(value);
  }

  static List<dynamic> _expectList(dynamic value) {
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    throw NetworkSerializationException(
      'Expected list payload but received ${value.runtimeType}.',
    );
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final client = ref.watch(networkClientProvider);
  return ApiUserRepository(client);
});
