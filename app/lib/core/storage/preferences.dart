// ignore_for_file: public_member_api_docs

import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sharedPreferencesScope = Scope<SharedPreferences>.required(
  'sharedPreferences',
);

final sharedPreferencesProvider = AsyncProvider<SharedPreferences>((ref) async {
  try {
    return ref.scope(sharedPreferencesScope);
  } on StateError {
    return SharedPreferences.getInstance();
  }
});
