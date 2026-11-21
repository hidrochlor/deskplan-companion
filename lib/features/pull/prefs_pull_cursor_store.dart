import 'package:shared_preferences/shared_preferences.dart';

import 'pull_cursor_store.dart';

/// [PullCursorStore] kept in shared preferences.
class PrefsPullCursorStore implements PullCursorStore {
  // The number changes when the pull gains fields (v2: kind and parentId, v3:
  // description and createdAt, v4: course and source). A new key makes the
  // next pull ask for everything, so tasks saved before that learn what
  // DeskPlan says about them. Without v4 an imported assignment fetched before
  // `source` existed stayed unlocked until the user edited it.
  // From v4 on this no longer needs bumping by hand: DeskPlan lists its fields
  // and the puller reads everything again when one it reads is new (_fieldsKey).
  static const _key = 'pull.serverTime.v4';
  static const _kindsKey = 'pull.kinds';
  static const _fieldsKey = 'pull.fields';

  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<String?> kinds() async =>
      (await SharedPreferences.getInstance()).getString(_kindsKey);

  @override
  Future<Set<String>?> fields() async => (await SharedPreferences.getInstance())
      .getStringList(_fieldsKey)
      ?.toSet();

  @override
  Future<void> save(
    String serverTime, {
    required String kinds,
    Set<String>? fields,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, serverTime);
    await prefs.setString(_kindsKey, kinds);
    if (fields == null) {
      await prefs.remove(_fieldsKey);
    } else {
      await prefs.setStringList(_fieldsKey, fields.toList()..sort());
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_kindsKey);
    await prefs.remove(_fieldsKey);
  }
}
