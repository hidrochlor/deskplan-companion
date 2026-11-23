import 'package:flutter/services.dart';

/// Capitalizes as the user types, whatever the keyboard does: the first
/// letter of a line or of a sentence (after ". ", "! ", "? "), and "i" on its
/// own ("i ", "i'm" → "I ", "I'm"). It only acts on a single typed
/// character, so pasting, deleting and undo are left alone, and it never
/// changes the text's length (styled spans stay where they are).
class AutoCapitalizeFormatter extends TextInputFormatter {
  const AutoCapitalizeFormatter();

  static final _letter = RegExp(r'[a-z]');

  /// True when a letter at [i] of [text] starts a sentence.
  static bool startsSentence(String text, int i) {
    var j = i - 1;
    var sawSpace = false;
    while (j >= 0 && (text[j] == ' ' || text[j] == '\t')) {
      sawSpace = true;
      j--;
    }
    if (j < 0 || text[j] == '\n') return true;
    if (!sawSpace) return false;
    final c = text[j];
    if (c == '.' && j > 0 && text[j - 1] == '.') return false; // "..."
    return c == '.' || c == '!' || c == '?';
  }

  /// A word boundary before [i] (or the start).
  static bool _boundaryBefore(String text, int i) =>
      i == 0 || !RegExp(r"[A-Za-z0-9'’]").hasMatch(text[i - 1]);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final cursor = newValue.selection.baseOffset;
    // One character typed at the cursor, nothing else changed.
    if (!newValue.selection.isCollapsed ||
        text.length != oldValue.text.length + 1 ||
        cursor < 1 ||
        cursor > text.length ||
        text.substring(0, cursor - 1) !=
            oldValue.text.substring(0, cursor - 1) ||
        newValue.composing.isValid && newValue.composing.end > cursor) {
      return newValue;
    }
    final typed = text[cursor - 1];
    final chars = text.split('');

    if (_letter.hasMatch(typed) && startsSentence(text, cursor - 1)) {
      chars[cursor - 1] = typed.toUpperCase();
    }
    // "i" followed by a space, punctuation or an apostrophe becomes "I".
    if (!_letter.hasMatch(typed) && cursor >= 2) {
      final i = cursor - 2;
      if (chars[i] == 'i' && _boundaryBefore(text, i)) chars[i] = 'I';
    }
    final out = chars.join();
    return out == text ? newValue : newValue.copyWith(text: out);
  }
}
