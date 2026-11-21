/// Compares decoded JSON values (maps, lists, text, numbers, booleans, null)
/// by what they hold, not by how they were written: the order of keys in a
/// map does not matter, the order of a list does. protocol.md section 4,
/// rule 5, says a note's `doc` is compared this way, never as text.
class JsonEquality {
  const JsonEquality._();

  static bool equals(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !equals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!equals(a[i], b[i])) return false;
      }
      return true;
    }
    // 1 and 1.0 are the same JSON number.
    if (a is num && b is num) return a == b;
    return a == b;
  }
}
