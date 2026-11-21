import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/task.dart';
import '../../core/task_repository.dart';
import '../../features/notes/json_equality.dart';
import '../../features/notes/note_autosaver.dart';
import '../../features/notes/note_format.dart';
import '../../features/queue/sync_report.dart';
import '../../features/upload/https_task_uploader.dart';
import '../theme/deskplan_colors.dart';
import 'note_details_sheet.dart';
import 'note_editor.dart';
import 'note_line_view.dart';
import 'note_move_sheet.dart';
import 'note_places.dart';

/// A note, opened to read and write, like DeskPlan's note page: the title,
/// then the text. It saves as you type (there is no Save button, as on the
/// PC); moving it to another place still needs a Save.
///
/// A new note is only stored once something is typed, so opening one and
/// going back leaves nothing behind.
class NotePage extends StatefulWidget {
  /// The note to open, or null for a new one.
  final Task? note;

  /// The repository that queues changes for DeskPlan.
  final TaskRepository repository;

  /// Starts a sync (`SyncService.syncNow`).
  final void Function() syncNow;

  /// One report per finished sync (`SyncService.reports`): a newer version
  /// from the PC may have arrived.
  final Stream<SyncReport> syncReports;
  final NotePlaces places;

  /// Where a new note goes (null: the top level of Home).
  final String? newParentId;

  const NotePage({
    super.key,
    required this.note,
    required this.repository,
    required this.syncNow,
    required this.syncReports,
    required this.places,
    this.newParentId,
  });

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final _editorKey = GlobalKey<NoteEditorState>();
  late Task _note;
  late final NoteAutosaver _saver;
  late final TextEditingController _title;
  StreamSubscription<SyncReport>? _reports;

  /// Whether the note is in the phone's database yet.
  late bool _stored;

  /// Goes up when a newer version is loaded into the editor.
  int _version = 0;
  bool _tooBig = false;

  @override
  void initState() {
    super.initState();
    _note =
        widget.note ??
        Task.createNote(
          parentId: widget.newParentId,
          doc: NoteFormat.emptyDoc(),
        );
    _stored = widget.note != null;
    _tooBig = HttpsTaskUploader.tooBig(_note);
    _title = TextEditingController(text: _note.title);
    _saver = NoteAutosaver(widget.repository, widget.syncNow);
    _reports = widget.syncReports.listen((_) => _takeNewerVersion());
  }

  @override
  void dispose() {
    _reports?.cancel();
    _saver.flush();
    _title.dispose();
    super.dispose();
  }

  void _save(Task note) {
    _note = note;
    _stored = true;
    _saver.change(note);
    final tooBig = HttpsTaskUploader.tooBig(note);
    if (tooBig != _tooBig) setState(() => _tooBig = tooBig);
  }

  void _docChanged(Map<String, Object?> doc) => _save(
    _note.copyWith(
      doc: doc,
      // DeskPlan makes its own copy; this one is for the phone's previews
      // and is never sent for a note.
      details: NoteFormat.toPlainText(doc),
      detailsEdited: false,
    ),
  );

  void _titleChanged(String title) => _save(_note.copyWith(title: title));

  /// After a sync: if DeskPlan's version reached the phone (a pull, or a
  /// "kept-newer" reply), show it, unless something typed here is still
  /// waiting to be written.
  Future<void> _takeNewerVersion() async {
    if (!_stored || _saver.hasUnsaved) return;
    final stored = await widget.repository.get(_note.id);
    if (!mounted || _saver.hasUnsaved) return;
    if (stored == null) {
      _saver.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This note was deleted on your PC')),
      );
      Navigator.pop(context);
      return;
    }
    final same =
        stored.title == _note.title &&
        stored.parentId == _note.parentId &&
        JsonEquality.equals(stored.doc, _note.doc);
    if (same) return;
    setState(() {
      _note = stored;
      _title.text = stored.title;
      _tooBig = HttpsTaskUploader.tooBig(stored);
      _version++;
    });
  }

  Future<void> _move() async {
    final picked = await NoteMoveSheet.show(
      context,
      places: widget.places,
      selectedId: widget.places.idFor(_note.parentId),
    );
    if (picked == null || !mounted) return;
    final parentId = NotePlaces.parentIdFor(picked);
    if (parentId == _note.parentId) return;
    setState(() {
      _save(
        parentId == null
            ? _note.copyWith(clearParent: true)
            : _note.copyWith(parentId: parentId),
      );
    });
    await _saver.flush();
  }

  /// The note's properties: where it is, when it was made and changed, and
  /// how long it is.
  Future<void> _showDetails() => NoteDetailsSheet.show(
    context,
    note: _note,
    place: widget.places.pathOf(_note.parentId),
    course: _note.courseKnown ? _note.course : null,
  );

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          '"${_note.title.isEmpty ? 'Untitled' : _note.title}" will be '
          'deleted here and on your PC.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: DeskPlanColors.of(context).danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _saver.cancel();
    if (_stored) {
      await widget.repository.delete(_note.id);
      widget.syncNow();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final place = widget.places.nameOf(_note.parentId) ?? 'Home';

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _title,
          autofocus: widget.note == null,
          textCapitalization: TextCapitalization.sentences,
          // DeskPlan refuses titles over 500 characters (protocol.md).
          inputFormatters: [LengthLimitingTextInputFormatter(500)],
          textInputAction: TextInputAction.next,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
          decoration: NoteLineView.bare(
            hint: 'Untitled',
            hintStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: c.faint,
            ),
          ),
          onChanged: _titleChanged,
          onSubmitted: (_) => _editorKey.currentState?.focusStart(),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _move,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open, size: 15, color: c.muted),
                const SizedBox(width: 6),
                Text(
                  'In $place',
                  style: TextStyle(fontSize: 12.5, color: c.muted),
                ),
              ],
            ),
          ),
        ),
        if (_tooBig)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'This note is too big to sync (over 1 MB). It is kept on '
              'this phone.',
              style: TextStyle(fontSize: 12.5, color: c.danger),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Details',
            onPressed: _showDetails,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (choice) => switch (choice) {
              'move' => _move(),
              _ => _delete(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'move', child: Text('Move…')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: NoteEditor(
        key: _editorKey,
        doc: _note.doc ?? NoteFormat.emptyDoc(),
        version: _version,
        header: header,
        onChanged: _docChanged,
      ),
    );
  }
}
