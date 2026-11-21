import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pc_info.dart';
import 'pc_info_store.dart';

/// [PcInfoStore] kept in shared preferences.
class PrefsPcInfoStore implements PcInfoStore {
  static const _key = 'pc.info';

  @override
  Future<PcInfo?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key);
    if (text == null) return null;
    try {
      return PcInfo.fromJson(jsonDecode(text));
    } on FormatException {
      return null; // damaged: behave as if nothing was saved
    }
  }

  @override
  Future<void> save(PcInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(info.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
