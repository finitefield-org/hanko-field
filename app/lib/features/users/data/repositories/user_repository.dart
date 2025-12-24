// ignore_for_file: public_member_api_docs

import 'package:app/features/users/data/models/user_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class UserRepository {
  static const fallback = Scope<UserRepository>.required('user.repository');

  Future<UserProfile> fetchProfile();

  Future<UserProfile> updateProfile(UserProfile profile);

  Future<List<UserAddress>> listAddresses();

  Future<UserAddress> addAddress(UserAddress address);

  Future<UserAddress> updateAddress(UserAddress address);

  Future<void> deleteAddress(String addressId);

  Future<List<PaymentMethod>> listPaymentMethods();

  Future<PaymentMethod> addPaymentMethod(PaymentMethod method);

  Future<PaymentMethod> updatePaymentMethod(PaymentMethod method);

  Future<void> removePaymentMethod(String methodId);

  Future<List<FavoriteDesign>> listFavorites();

  Future<void> addFavorite(
    String designId, {
    String? note,
    List<String> tags = const <String>[],
  });

  Future<void> removeFavorite(String designId);

  Future<void> deleteAccount();
}
