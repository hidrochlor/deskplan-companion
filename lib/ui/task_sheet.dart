import 'package:flutter/material.dart';

import 'clash_notice.dart';
import 'package:flutter/services.dart';

import '../core/repeat_rule.dart';
import '../core/task.dart';
import '../core/task_kind.dart';
import '../features/connection/destination.dart';
import 'date_text.dart';
import 'date_time_field.dart';
import 'destination_picker.dart';
import 'repeat_field.dart';
import 'source_badge.dart';
import 'theme/deskplan_colors.dart';

/// Add or edit one task, assignment or step in a sheet that slides up from
/// the bottom. Pops with the saved [Task], or with [TaskSheet.deleted] when
/// the user deletes it. Every change is a draft until Save: Cancel, going
/// back or dismissing the sheet changes nothing (null).
///
/// The rules are DeskPlan's (docs/protocol.md section 4), so the phone never
/// sends something it would refuse:
/// - an assignment needs a folder and a due time, and never has a start;
/// - a new task (a step too) is a time block: From and To, From earlier;
/// - a task that has a start keeps one (an old due-time-only task can be
///   given one);
/// - a task may be in Home or in a folder;
/// - a step stays inside its assignment;
/// - an assignment imported from a feed (Moodle) shows its due date read-only:
///   it belongs to the feed, so the old one is always sent back.
class TaskSheet extends StatefulWidget {
  /// The task to edit, or null to create a new one.
  final Task? task;

  /// What a new item is. For an existing one its own kind is used.
  final TaskKind kind;

  /// DeskPlan's folders, from the last time it was reached. Without any, a
  /// task stays where it is and an assignment cannot be made.
  final List<Destination> folders;

  /// Set for a step: the assignment it sits in, which cannot be changed here.
  final String? fixedParentId;

  /// The title a new item starts with (for example a step typed in the
  /// assignment's "Add a step" box).
  final String initialTitle;

  /// How it sits against the day's other blocks, when opened from the
  /// calendar.
  final List<(String, bool)> clashes;

  const TaskSheet({
    super.key,
    this.task,
    this.kind = TaskKind.task,
    this.folders = const [],
    this.fixedParentId,
    this.initialTitle = '',
    this.clashes = const [],
  });

  /// Returned in place of a Task when the user taps Delete.
  static const deleted = Object();

  /// Shows the sheet and returns what it popped with.
  static Future<Object?> show(
    BuildContext context, {
    Task? task,
    TaskKind kind = TaskKind.task,
    List<Destination> folders = const [],
    String? fixedParentId,
    String initialTitle = '',
    List<(String, bool)> clashes = const [],
  }) => showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TaskSheet(
      task: task,
      kind: kind,
      folders: folders,
      fixedParentId: fixedParentId,
      initialTitle: initialTitle,
      clashes: clashes,
    ),
  );

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  /// `Destination.id` of Home in the place picker (folders use `folder:<id>`).
  static const _homeId = '';
  static const _folderPrefix = 'folder:';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _details;
  DateTime? _start;
  DateTime? _end;
  late bool _done;
  late String? _parentId;
  RepeatRule? _repeat;
  String? _timeError;
  String? _placeError;

  bool get _isNew => widget.task == null;

  bool get _repeatChanged => _repeat != widget.task?.repeat;

  /// A rule needs a due time to repeat from; an imported item never repeats
  /// (its dates are the feed's).
  bool get _canRepeat => _end != null && !_dueFromFeed;

  bool get _detailsChanged =>
      widget.task != null && _details.text.trim() != widget.task!.details;

  /// Details can be edited once DeskPlan's own have been seen (or for a new
  /// task). Until then the box waits, so an edit cannot blank a description
  /// the PC has.
  bool get _canEditDetails => widget.task == null || widget.task!.detailsKnown;
  TaskKind get _kind => widget.task?.kind ?? widget.kind;
  bool get _isAssignment => _kind == TaskKind.assignment;
  bool get _isStep => widget.fixedParentId != null;

  /// Imported from a calendar feed: the due date is the feed's
  /// (protocol.md section 4 "Imported assignments").
  bool get _dueFromFeed => widget.task?.isImported ?? false;

  /// A task that is (or must become) a time block: every new task, and an
  /// old one that already has a start. Its start can never be cleared.
  bool get _needsBlock =>
      !_isAssignment && (_isNew || widget.task!.start != null);

  /// Whether the place can be chosen here. A step stays in its assignment,
  /// and an old task that does not know its place must not be moved by an edit.
  bool get _canChoosePlace =>
      !_isStep &&
      widget.folders.isNotEmpty &&
      (widget.task == null || widget.task!.placeKnown);

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? widget.initialTitle);
    _details = TextEditingController(text: t?.details ?? '');
    // An assignment never has a start, even an old one that was given one.
    _start = _isAssignment ? null : t?.start;
    _end = t?.end;
    _done = t?.done ?? false;
    _parentId = widget.fixedParentId ?? t?.parentId;
    _repeat = t?.repeat;
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  /// Sets the due time to 23:59 on the day [days] from today, like the
  /// Today / Tomorrow / +1 week buttons on DeskPlan.
  void _dueIn(int days) {
    final day = DateTime.now().add(Duration(days: days));
    setState(() => _end = DateTime(day.year, day.month, day.day, 23, 59));
  }

  /// A one-hour time block starting at [from].
  void _blockFrom(DateTime from) => setState(() {
    _start = from;
    _end = from.add(const Duration(hours: 1));
    _timeError = null;
  });

  /// From the next full hour.
  void _nextHour() {
    final now = DateTime.now();
    _blockFrom(DateTime(now.year, now.month, now.day, now.hour + 1));
  }

  void _tomorrowMorning() {
    final day = DateTime.now().add(const Duration(days: 1));
    _blockFrom(DateTime(day.year, day.month, day.day, 9));
  }

  /// Picking a From with no To yet (or a To that is now too early) moves the
  /// To an hour later, so the block stays valid.
  void _setStart(DateTime? value) => setState(() {
    _start = value;
    final end = _end;
    if (value != null && (end == null || !end.isAfter(value))) {
      _end = value.add(const Duration(hours: 1));
    }
    _timeError = null;
  });

  /// What is wrong with the times, or null. DeskPlan's rules
  /// (protocol.md section 4 "Shapes"), checked before anything is sent.
  String? _timeProblem() {
    final start = _start;
    final end = _end;
    if (_isAssignment) {
      return end == null ? 'An assignment needs a due time' : null;
    }
    if (_needsBlock && (start == null || end == null)) {
      return 'A task needs a From and a To time';
    }
    if (start != null && end == null) return 'A start needs a To time';
    if (start != null && !start.isBefore(end!)) {
      return 'From must be earlier than To';
    }
    return null;
  }

  void _save() {
    final valid = _formKey.currentState!.validate();
    final timeError = _timeProblem();
    final placeError = _isAssignment && _parentId == null
        ? 'An assignment needs a folder'
        : null;
    setState(() {
      _timeError = timeError;
      _placeError = placeError;
    });
    if (!valid || timeError != null || placeError != null) return;

    final title = _title.text.trim();
    final old = widget.task;
    final Task saved;
    if (old == null) {
      saved =
          Task.create(
            title: title,
            start: _start,
            end: _end,
            kind: _kind,
            parentId: _parentId,
          ).copyWith(
            done: _done,
            // A new task has no details unless the user wrote some.
            details: _details.text.trim().isEmpty ? null : _details.text.trim(),
            repeat: _canRepeat ? _repeat : null,
          );
    } else {
      final moved = _canChoosePlace && _parentId != old.parentId;
      saved = old.copyWith(
        title: title,
        start: _start,
        end: _end,
        // Only an assignment (which never has one) or an old due-time-only
        // task (which never got one) is saved without a start.
        clearStart: _start == null,
        clearEnd: _end == null,
        done: _done,
        // Only when the user changed it: an old task has not heard
        // DeskPlan's description yet, and must not send an empty one.
        details: _detailsChanged ? _details.text.trim() : null,
        parentId: moved ? _parentId : null,
        clearParent: moved && _parentId == null,
        // Only when the user changed it, so an item that has not heard
        // DeskPlan's rule yet does not send one.
        repeat: _repeatChanged && _canRepeat ? _repeat : null,
        clearRepeat: _repeatChanged && (_repeat == null || !_canRepeat),
      );
    }
    Navigator.pop(context, saved);
  }

  /// The places the picker offers: Home (not for an assignment) and folders.
  List<Destination> get _places => [
    if (!_isAssignment) const Destination(id: _homeId, label: 'Home'),
    ...widget.folders,
  ];

  String get _heading {
    if (_isStep) return _isNew ? 'New step' : 'Step';
    if (_isAssignment) return _isNew ? 'New assignment' : 'Assignment';
    return _isNew ? 'New task' : 'Task';
  }

  /// Deletes at once, but a repeating task only after a yes: all its
  /// occurrences go with it.
  Future<void> _delete() async {
    if (widget.task?.repeat != null) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this repeating task?'),
          content: const Text(
            'It stops repeating, and all its occurrences are deleted, on '
            'DeskPlan too.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: DeskPlanColors.of(context).danger,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    Navigator.pop(context, TaskSheet.deleted);
  }

  /// "To" for a time block, "Due" for an assignment or a due-time-only task.
  Widget _endField({bool compact = false}) => DateTimeField(
    compact: compact,
    label: _isAssignment
        ? 'Due (required)'
        : (_needsBlock || _start != null ? 'To' : 'Due'),
    value: _end,
    canClear: !_isAssignment && !_needsBlock && _start == null,
    onChanged: (v) => setState(() {
      _end = v;
      _timeError = null;
    }),
  );

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    return Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isAssignment ? c.danger : c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _heading,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                    ),
                    if (widget.task?.sourceLabel case final label?)
                      SourceBadge(label: label),
                    if (!_isNew)
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: c.danger),
                        tooltip: 'Delete',
                        onPressed: _delete,
                      ),
                  ],
                ),
                ClashNotice(lines: widget.clashes),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _title,
                  autofocus: _isNew,
                  textCapitalization: TextCapitalization.sentences,
                  // DeskPlan refuses titles over 500 characters (protocol.md).
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                ),
                if (_canChoosePlace || (_isAssignment && _isNew)) ...[
                  const SizedBox(height: 12),
                  DestinationPicker(
                    title: _isAssignment ? 'Folder' : 'Put in',
                    subtitle: _isAssignment
                        ? 'The course folder it belongs to'
                        : 'Home or a folder on your PC',
                    topIcon: Icons.home_outlined,
                    emptyLabel: _isAssignment ? 'Choose a folder' : null,
                    destinations: _places,
                    selectedId: _parentId == null
                        ? _homeId
                        : '$_folderPrefix$_parentId',
                    onChanged: (id) => setState(() {
                      _parentId = id == _homeId
                          ? null
                          : id.substring(_folderPrefix.length);
                      _placeError = null;
                    }),
                  ),
                  if (_placeError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        _placeError!,
                        style: TextStyle(color: c.danger, fontSize: 12.5),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(_isAssignment ? 'Not submitted' : 'To do'),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(_isAssignment ? 'Submitted' : 'Done'),
                    ),
                  ],
                  selected: {_done},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _done = s.first),
                ),
                const SizedBox(height: 8),
                // An assignment is due at one time; a task is a time block
                // (an old due-time-only task may stay one, or get a From).
                if (!_isAssignment && _dueFromFeed)
                  DateTimeField(
                    label: 'From',
                    value: _start,
                    canClear: false,
                    onChanged: _setStart,
                  ),
                if (_dueFromFeed)
                  _FeedDueField(due: _end, feed: widget.task!.sourceLabel!)
                else ...[
                  // A task's From and To share one row, an arrow between.
                  if (!_isAssignment)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: DateTimeField(
                              compact: true,
                              label: 'From',
                              value: _start,
                              // A task keeps its start for good.
                              canClear: false,
                              onChanged: _setStart,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: c.muted,
                            ),
                          ),
                          Expanded(child: _endField(compact: true)),
                        ],
                      ),
                    )
                  else
                    _endField(),
                  Wrap(
                    spacing: 8,
                    children: _isAssignment
                        ? [
                            ActionChip(
                              label: const Text('Today'),
                              onPressed: () => _dueIn(0),
                            ),
                            ActionChip(
                              label: const Text('Tomorrow'),
                              onPressed: () => _dueIn(1),
                            ),
                            ActionChip(
                              label: const Text('+1 week'),
                              onPressed: () => _dueIn(7),
                            ),
                          ]
                        : [
                            ActionChip(
                              label: const Text('Next hour'),
                              onPressed: _nextHour,
                            ),
                            ActionChip(
                              label: const Text('Tomorrow 9:00'),
                              onPressed: _tomorrowMorning,
                            ),
                          ],
                  ),
                ],
                if (_timeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_timeError!, style: TextStyle(color: c.danger)),
                  ),
                // Only tasks repeat; an assignment that already does (made so
                // on an older DeskPlan) can still be set to Never.
                if (!_dueFromFeed &&
                    (!_isAssignment || widget.task?.repeat != null)) ...[
                  const SizedBox(height: 12),
                  RepeatField(
                    value: _repeat,
                    enabled: _end != null,
                    onChanged: (r) => setState(() => _repeat = r),
                  ),
                ],
                const SizedBox(height: 12),
                // The task's details: DeskPlan's `description`, shared both ways.
                TextField(
                  controller: _details,
                  enabled: _canEditDetails,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 16000, // DeskPlan's limit
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Details',
                    alignLabelWithHint: true,
                    helperText: _canEditDetails
                        ? 'Shared with DeskPlan'
                        : 'Sync with DeskPlan first, to load its details',
                    counterText: '',
                  ),
                ),
                if (widget.task != null) ...[
                  const SizedBox(height: 12),
                  _InfoLine(
                    icon: Icons.add_circle_outline,
                    text:
                        'Created ${DateText.when(context, widget.task!.createdAt)}',
                  ),
                  _InfoLine(
                    icon: Icons.edit_calendar_outlined,
                    text:
                        'Last changed ${DateText.when(context, widget.task!.updatedAt)}',
                  ),
                ],
                const SizedBox(height: 16),
                // Nothing is kept until Save: Cancel drops the draft.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The due date of an imported assignment: shown, not editable, with where
/// it comes from. To plan their own time the user adds steps.
class _FeedDueField extends StatelessWidget {
  final DateTime? due;
  final String feed;

  const _FeedDueField({required this.due, required this.feed});

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final due = this.due;
    return ListTile(
      key: const Key('feed-due'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.lock_clock_outlined, color: c.muted),
      title: Text(
        due == null ? 'No due date' : 'Due ${DateText.when(context, due)}',
      ),
      subtitle: Text(
        'Set by $feed. Add steps to plan your own time.',
        style: TextStyle(color: c.muted),
      ),
    );
  }
}

/// One small line of facts about the task, such as when it was added.
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = DeskPlanColors.of(context).muted;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
