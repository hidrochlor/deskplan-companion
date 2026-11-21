import 'dart:async';

import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/core/task_repository.dart';
import 'package:deskplan_companion/features/connection/destination.dart';
import 'package:deskplan_companion/features/notes/note_format.dart';
import 'package:deskplan_companion/features/queue/sync_report.dart';
import 'package:deskplan_companion/ui/notes/note_page.dart';
import 'package:deskplan_companion/ui/notes/note_places.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps notes in memory, as the queued repository would.
class _Memory implements TaskRepository {
  final items = <String, Task>{};
  final deleted = <String>[];
  @override
  Future<List<Task>> all() async => items.values.toList();
  @override
  Future<void> delete(String id) async {
    items.remove(id);
    deleted.add(id);
  }

  @override
  Future<Task?> get(String id) async => items[id];
  @override
  Future<void> save(Task task) async => items[task.id] = task;
}

void main() {
  late _Memory repo;
  late StreamController<SyncReport> reports;
  late int syncs;

  setUp(() {
    repo = _Memory();
    reports = StreamController<SyncReport>.broadcast();
    syncs = 0;
  });

  tearDown(() => reports.close());

  final places = NotePlaces([
    const Destination(id: 'folder:csc', label: 'CSC101', name: 'CSC101'),
  ], const []);

  /// Opens [note] (or a new one) from a button, so Back can close it.
  Future<void> open(WidgetTester tester, {Task? note}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => NotePage(
                    note: note,
                    repository: repo,
                    syncNow: () => syncs++,
                    syncReports: reports.stream,
                    places: places,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  testWidgets('a new note left empty is not kept', (tester) async {
    await open(tester);
    await back(tester);
    expect(repo.items, isEmpty);
    expect(syncs, 0);
  });

  testWidgets('a new note saves as it is written, and syncs on leaving', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'Week 3');
    await tester.enterText(find.byType(TextField).at(1), 'Read chapter 3');
    await tester.pump(const Duration(milliseconds: 500)); // the short pause
    expect(repo.items, hasLength(1));

    await back(tester);
    final note = repo.items.values.single;
    expect(note.kind, TaskKind.note);
    expect(note.title, 'Week 3');
    expect(NoteFormat.toPlainText(note.doc), 'Read chapter 3');
    expect(note.details, 'Read chapter 3'); // for the list's preview
    expect(syncs, greaterThan(0));
  });

  testWidgets('moving waits for Save, and Cancel keeps it where it was', (
    tester,
  ) async {
    final note = Task.createNote(title: 'N', doc: NoteFormat.emptyDoc());
    repo.items[note.id] = note;
    await open(tester, note: note);
    expect(find.text('In Home'), findsOneWidget);

    await tester.tap(find.text('In Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last); // the picker row
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSC101'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.items[note.id]!.parentId, isNull);

    await tester.tap(find.text('In Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSC101'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.items[note.id]!.parentId, 'csc');
    expect(find.text('In CSC101'), findsOneWidget);
  });

  testWidgets('delete asks first, then deletes and syncs', (tester) async {
    final note = Task.createNote(title: 'Old', doc: NoteFormat.emptyDoc());
    repo.items[note.id] = note;
    await open(tester, note: note);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete note?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(repo.deleted, [note.id]);
    expect(find.text('open'), findsOneWidget); // back on the list
  });

  testWidgets('a newer version from the PC is shown after a sync', (
    tester,
  ) async {
    final note = Task.createNote(title: 'Mine', doc: NoteFormat.emptyDoc());
    repo.items[note.id] = note;
    await open(tester, note: note);

    repo.items[note.id] = note.copyWith(
      title: 'Changed on the PC',
      doc: NoteFormat.fromPlainText('PC text'),
    );
    reports.add(SyncReport());
    await tester.pumpAndSettle();

    expect(find.text('Changed on the PC'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller!.text.contains('PC text'),
      ),
      findsOneWidget,
    );
  });
}
