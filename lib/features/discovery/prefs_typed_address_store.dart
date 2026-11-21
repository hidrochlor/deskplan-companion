import 'package:shared_preferences/shared_preferences.dart';

import 'typed_address_store.dart';

/// [TypedAddressStore] kept in shared preferences.
class PrefsTypedAddressStore implements TypedAddressStore {
  static const _key = 'pc.typedAddress';

  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> save(String text) async =>
      (await SharedPreferences.getInstance()).setString(_key, text);

  @override
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
