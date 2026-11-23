import 'package:flutter/services.dart';

/// Capitalizes as the user types, whatever the keyboard does: the first
/// letter of a line or of a sentence (after ". ", "! ", "? "), and "i" on its
/// own ("i ", "i'm" → "I ", "I'm"). It never changes the text's length
/// (styled spans stay where they are), and acts only while text is being
/// added at the caret, so deleting and undo are left alone.
///
/// Android keyboards send the whole word being typed again with every key
/// ("h", then "he"), which would undo a capital made a key earlier. So the
/// word at the caret is looked at as a whole each time, not just the last
/// character.
class AutoCapitalizeFormatter extends TextInputFormatter {
  const AutoCapitalizeFormatter();

  /// Each note line starts with an invisible zero-width space (see
  /// StyledLineController), which counts as the start of the line.
  static const _lineStart = '​';

  static final _wordChar = RegExp(r"[\p{L}\p{N}'’]", unicode: true);

  static bool _isLower(String ch) =>
      ch != ch.toUpperCase() && ch == ch.toLowerCase();

  /// True when a letter at [i] of [text] starts a sentence.
  static bool startsSentence(String text, int i) {
    var j = i - 1;
    var sawSpace = false;
    while (j >= 0 && (text[j] == ' ' || text[j] == '\t')) {
      sawSpace = true;
      j--;
    }
    if (j < 0 || text[j] == '\n' || text[j] == _lineStart) return true;
    if (!sawSpace) return false;
    final c = text[j];
    if (c == '.' && j > 0 && text[j - 1] == '.') return false; // "..."
    return c == '.' || c == '!' || c == '?';
  }

  /// Where the word that ends at [end] starts.
  static int _wordStart(String text, int end) {
    var i = end;
    while (i > 0 && _wordChar.hasMatch(text[i - 1])) {
      i--;
    }
    return i;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final old = oldValue.text;
    final cursor = newValue.selection.baseOffset;
    if (!newValue.selection.isCollapsed ||
        text.length <= old.length ||
        cursor < 1 ||
        cursor > text.length) {
      return newValue;
    }
    // Everything after the caret is as it was: the change is at the caret.
    final after = text.length - cursor;
    if (text.substring(cursor) != old.substring(old.length - after)) {
      return newValue;
    }
    final chars = text.split('');

    // The word at the caret, or the one just finished by a space or mark.
    final typedEndsWord = !_wordChar.hasMatch(text[cursor - 1]);
    final wordEnd = typedEndsWord ? cursor - 1 : cursor;
    final start = _wordStart(text, wordEnd);
    // Only the word being typed may change: what comes before it is as it was.
    final untouched =
        start <= old.length &&
        text.substring(0, start) == old.substring(0, start);
    if (start < wordEnd && untouched) {
      final word = text.substring(start, wordEnd);
      if (_isLower(word[0]) && startsSentence(text, start)) {
        chars[start] = word[0].toUpperCase();
      }
      // A lone "i" once the word is over, and "i'm", "i’ve".
      if (word[0] == 'i' &&
          ((word.length == 1 && typedEndsWord) ||
              (word.length > 1 && (word[1] == "'" || word[1] == '’')))) {
        chars[start] = 'I';
      }
    }
    final out = chars.join();
    return out == text ? newValue : newValue.copyWith(text: out);
  }
}
