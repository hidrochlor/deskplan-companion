import 'package:deskplan_companion/core/fields_read.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Task.syncFields decides when the phone reads everything again (a field
  // from DeskPlan it reads but did not have). It is found by watching
  // fromSyncJson, so it can not drift from what the phone really reads.
  test('Task.syncFields holds what fromSyncJson reads, for every kind', () {
    expect(
      Task.syncFields,
      containsAll([
        'id', 'title', 'start', 'end', 'done', 'updatedAt', 'kind', //
        'parentId', 'description', 'createdAt', 'course', 'source',
        'doc', // read only for a note
      ]),
    );
    expect(
      Task.syncFields,
      isNot(contains('result')),
    ); // in a PUT reply, not read
  });

  test(
    'fieldsRead notes keys that are checked for or read, present or not',
    () {
      final read = fieldsRead(
        (j) {
          j['a'];
          j.containsKey('b');
        },
        [
          {'a': 1},
        ],
      );
      expect(read, {'a', 'b'});
    },
  );
}
