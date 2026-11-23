import 'package:deskplan_companion/core/time_relation.dart';
import 'package:deskplan_companion/features/notes/auto_capitalize.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _t(int h, [int m = 0]) => DateTime(2026, 11, 23, h, m);

/// B against A.
TimeRelation? _rel(
  DateTime bs,
  DateTime be,
  DateTime as,
  DateTime ae, [
  String a = 'A',
]) => TimeRelation.of(bs, be, as, ae, a);

TextEditingValue _type(String before, String char) {
  final old = TextEditingValue(
    text: before,
    selection: TextSelection.collapsed(offset: before.length),
  );
  final now = TextEditingValue(
    text: before + char,
    selection: TextSelection.collapsed(offset: before.length + 1),
  );
  return const AutoCapitalizeFormatter().formatEditUpdate(old, now);
}

void main() {
  group('TimeRelation clash', () {
    test('HS1 16:00-17:00 inside EPE 13:30-17:45', () {
      final r = _rel(_t(16), _t(17), _t(13, 30), _t(17, 45), 'EPE')!;
      expect(
        r.text,
        'Starts 2h 30m after EPE starts (1h 45m before it ends), '
        'ends 45m before EPE ends',
      );
      expect(r.overlaps, isTrue);
    });

    test('A 1-8, B 1:30-9', () {
      expect(
        _rel(_t(1, 30), _t(9), _t(1), _t(8))!.text,
        'Starts 30m after A starts (6h 30m before it ends), '
        'ends 1h after A ends',
      );
    });

    test('A 1-8, B 7-9', () {
      expect(
        _rel(_t(7), _t(9), _t(1), _t(8))!.text,
        'Starts 6h after A starts (1h before it ends), ends 1h after A ends',
      );
    });

    test('A 13:00-16:15 against B 16:00-17:00', () {
      expect(
        _rel(_t(13), _t(16, 15), _t(16), _t(17), 'B')!.text,
        'Starts 3h before B starts, '
        'ends 45m before B ends (15m after it starts)',
      );
    });

    test('same start', () {
      expect(
        _rel(_t(1), _t(5), _t(1), _t(8))!.text,
        'Starts at the same time as A starts, ends 3h before A ends',
      );
    });
  });

  group('TimeRelation arrow', () {
    test('30m after', () {
      final r = _rel(_t(8, 30), _t(9), _t(1), _t(8))!;
      expect(r.text, 'Starts 30m after A ends');
      expect(r.overlaps, isFalse);
    });
    test('right when it ends', () {
      expect(
        _rel(_t(8), _t(9), _t(1), _t(8))!.text,
        'Starts right when A ends',
      );
    });
    test('more than 30m: nothing', () {
      expect(_rel(_t(8, 31), _t(9), _t(1), _t(8)), isNull);
    });
    test('the earlier one gets no arrow', () {
      expect(_rel(_t(1), _t(8), _t(8, 15), _t(9)), isNull);
    });
  });

  test('span text', () {
    expect(TimeRelation.span(const Duration(minutes: 90)), '1h 30m');
    expect(TimeRelation.span(const Duration(minutes: 30)), '30m');
  });

  group('AutoCapitalizeFormatter', () {
    test('first letter', () => expect(_type('', 'h').text, 'H'));
    test('after a new line', () => expect(_type('x\n', 'h').text, 'x\nH'));
    test('after a full stop', () => expect(_type('Ok. ', 'n').text, 'Ok. N'));
    test('not mid-sentence', () => expect(_type('Ok ', 'n').text, 'Ok n'));
    test('not after ...', () => expect(_type('so... ', 'n').text, 'so... n'));
    test('lone i', () => expect(_type('so i', ' ').text, 'so I '));
    test('i apostrophe', () => expect(_type('i', "'").text, "I'"));
    test('not inside words', () => expect(_type('hi', ' ').text, 'hi '));
  });
}
