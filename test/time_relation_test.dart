import 'package:deskplan_companion/core/time_relation.dart';
import 'package:deskplan_companion/features/notes/auto_capitalize.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _t(int h, [int m = 0]) => DateTime(2026, 11, 23, h, m);

/// The line shown on X about Y.
String? _rel(DateTime xs, DateTime xe, DateTime ys, DateTime ye, String y) =>
    TimeRelation.of(xs, xe, ys, ye, y);

TextEditingValue _edit(String before, String after) {
  final old = TextEditingValue(
    text: before,
    selection: TextSelection.collapsed(offset: before.length),
  );
  final now = TextEditingValue(
    text: after,
    selection: TextSelection.collapsed(offset: after.length),
  );
  return const AutoCapitalizeFormatter().formatEditUpdate(old, now);
}

TextEditingValue _type(String before, String char) =>
    _edit(before, before + char);

void main() {
  group('TimeRelation: A end against B start', () {
    test('B starts 15m before A ends; A ends 15m after B starts', () {
      // A 13:00-16:15, B 16:00-17:00.
      expect(
        _rel(_t(16), _t(17), _t(13), _t(16, 15), 'A'),
        'Starts 15m before A ends',
      );
      expect(
        _rel(_t(13), _t(16, 15), _t(16), _t(17), 'B'),
        'Ends 15m after B starts',
      );
    });

    test('B inside A: still only A end and B start', () {
      // EPE 13:30-17:45, HS1 16:00-17:00.
      expect(
        _rel(_t(16), _t(17), _t(13, 30), _t(17, 45), 'EPE'),
        'Starts 1h 45m before EPE ends',
      );
      expect(
        _rel(_t(13, 30), _t(17, 45), _t(16), _t(17), 'HS1'),
        'Ends 1h 45m after HS1 starts',
      );
    });

    test('same start: the longer one is A', () {
      expect(_rel(_t(1), _t(5), _t(1), _t(8), 'A'), 'Starts 7h before A ends');
      expect(_rel(_t(1), _t(8), _t(1), _t(5), 'B'), 'Ends 7h after B starts');
    });

    test('same times', () {
      expect(
        _rel(_t(13, 30), _t(17, 45), _t(13, 30), _t(17, 45), 'EPE'),
        'Starts 4h 15m before EPE ends',
      );
    });

    test('no overlap: nothing, also right after', () {
      expect(_rel(_t(8), _t(9), _t(1), _t(8), 'A'), isNull);
      expect(_rel(_t(8, 15), _t(9), _t(1), _t(8), 'A'), isNull);
      expect(_rel(_t(1), _t(8), _t(8, 15), _t(9), 'B'), isNull);
    });
  });

  test('span text', () {
    expect(TimeRelation.span(const Duration(minutes: 90)), '1h 30m');
    expect(TimeRelation.span(const Duration(minutes: 30)), '30m');
    expect(TimeRelation.span(const Duration(hours: 2)), '2h');
  });

  group('AutoCapitalizeFormatter', () {
    test('first letter', () => expect(_type('', 'h').text, 'H'));
    test('after a new line', () => expect(_type('x\n', 'h').text, 'x\nH'));
    test('after a full stop', () => expect(_type('Ok. ', 'n').text, 'Ok. N'));
    test('not mid-sentence', () => expect(_type('Ok ', 'n').text, 'Ok n'));
    test('not after ...', () => expect(_type('so... ', 'n').text, 'so... n'));
    test('lone i', () => expect(_type('so i', ' ').text, 'so I '));
    test('i apostrophe', () => expect(_type('i', "'").text, "I'"));
    test('not inside words', () => expect(_type('Ok hi', ' ').text, 'Ok hi '));
    test('not "in"', () => expect(_type('so i', 'n').text, 'so in'));

    // Each note line starts with an invisible zero-width space.
    test('a note line, after its invisible first character', () {
      expect(_type('​', 'h').text, '​H');
      expect(_type('​Ok. ', 'n').text, '​Ok. N');
    });

    // The keyboard sends the word again with each key, lower case.
    test('a keyboard resending the word keeps the capital', () {
      expect(_edit('​H', '​he').text, '​He');
      expect(_edit('Ok. N', 'Ok. no').text, 'Ok. No');
      expect(_edit("so I'", "so i'm").text, "so I'm");
    });

    test('a word in the middle is left alone', () {
      expect(_edit('Ok he', 'Ok hel').text, 'Ok hel');
    });

    test('deleting is left alone', () {
      expect(_edit('​He', '​h').text, '​h');
    });
  });
}
