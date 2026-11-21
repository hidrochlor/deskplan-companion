import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the "keep syncing in the background" guide has been
/// shown, so it appears once, the first time the app is used.
class BackgroundGuideStore {
  static const _key = 'guide.background.shown';

  Future<bool> wasShown() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  Future<void> markShown() async =>
      (await SharedPreferences.getInstance()).setBool(_key, true);
}
