import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'fields_read.dart';
import 'repeat_rule.dart';
import 'task_kind.dart';

/// One task, assignment or note. Field names match DeskPlan so syncing is a
/// straight copy.
///
/// Times are held in UTC. Convert with `.toLocal()` only when showing them.
/// A note has no times and no tick: its text is [doc], and [details] holds
/// the plain-text copy DeskPlan makes of it (for previews).
class Task {
  final String id;
  final String title;
  final DateTime? start;
  final DateTime? end;
  final bool done;
  final DateTime updatedAt;

  /// A task or an assignment. A task inside an assignment is a step.
  final TaskKind kind;

  /// The id of the folder or assignment this sits in, or null for the top
  /// level of Home. A folder's id here has no `folder:` prefix.
  final String? parentId;

  /// False for a task saved before the phone knew about `kind` and `parentId`,
  /// or from a DeskPlan too old to send them. Then neither is sent back, so
  /// DeskPlan keeps its own (leaving them out means "keep what the PC has").
  final bool placeKnown;

  /// The task's details (DeskPlan calls the field `description`).
  final String details;

  /// False while the phone has not yet seen DeskPlan's description (an old
  /// task, or an older DeskPlan).
  final bool detailsKnown;

  /// True when the user changed the details and DeskPlan has not confirmed it
  /// yet. Only then is `description` sent, so editing a title can never
  /// overwrite a description typed on the PC (leaving it out means "keep what
  /// the PC has").
  final bool detailsEdited;

  /// When the task was created. DeskPlan owns it: the phone only reads it and
  /// never sends it.
  final DateTime createdAt;

  /// False while the phone has not seen DeskPlan's creation time, so
  /// [createdAt] is only a stand-in (when it was made or first seen here).
  final bool createdKnown;

  /// A note's formatted text: Tiptap JSON, `{ "type": "doc", ... }`, kept
  /// exactly as DeskPlan sent it (parts the phone cannot edit included).
  /// Null for tasks and assignments.
  final Map<String, Object?>? doc;

  /// The course DeskPlan says this belongs to, or null (protocol.md section
  /// 4 "Assignments, steps and courses"). DeskPlan works it out; the phone
  /// only reads it and never sends it.
  final String? course;

  /// False while the phone has not seen DeskPlan's `course` (an older
  /// DeskPlan, from before the calendar): then the top-level folder stands in.
  final bool courseKnown;

  /// Where DeskPlan imported this from, e.g. `{ "label": "Moodle" }`, or null
  /// for an item made by hand (protocol.md section 4 "Imported assignments").
  /// Read only, never sent. An item never gets or loses it after it is made.
  final Map<String, Object?>? source;

  /// How often it repeats: ticking it off adds the next copy (repeats.dart).
  /// Null: it does not repeat. Notes never repeat.
  final RepeatRule? repeat;

  /// False while the phone has not seen DeskPlan's `repeat` (an item pulled
  /// from a DeskPlan without repeats). Then it is not sent, so DeskPlan
  /// keeps its own rule.
  final bool repeatKnown;

  Task({
    required this.id,
    required this.title,
    DateTime? start,
    DateTime? end,
    this.done = false,
    required DateTime updatedAt,
    this.kind = TaskKind.task,
    this.parentId,
    this.placeKnown = true,
    this.details = '',
    this.detailsKnown = true,
    this.detailsEdited = false,
    DateTime? createdAt,
    this.createdKnown = false,
    this.doc,
    this.course,
    this.courseKnown = false,
    this.source,
    this.repeat,
    this.repeatKnown = true,
  }) : start = start?.toUtc(),
       end = end?.toUtc(),
       updatedAt = updatedAt.toUtc(),
       createdAt = (createdAt ?? updatedAt).toUtc();

  /// New task with a fresh UUID v4 id (never collides with the PC's ids).
  factory Task.create({
    required String title,
    DateTime? start,
    DateTime? end,
    TaskKind kind = TaskKind.task,
    String? parentId,
  }) {
    return Task(
      id: const Uuid().v4(),
      title: title,
      start: start,
      end: end,
      updatedAt: DateTime.now(),
      kind: kind,
      parentId: parentId,
      createdAt: DateTime.now(),
    );
  }

  /// New, empty note with a fresh UUID v4 id.
  factory Task.createNote({
    String title = '',
    String? parentId,
    Map<String, Object?>? doc,
  }) {
    final now = DateTime.now();
    return Task(
      id: const Uuid().v4(),
      title: title,
      updatedAt: now,
      kind: TaskKind.note,
      parentId: parentId,
      createdAt: now,
      doc:
          doc ??
          {
            'type': 'doc',
            'content': [
              {'type': 'paragraph'},
            ],
          },
    );
  }

  bool get isAssignment => kind == TaskKind.assignment;
  bool get isNote => kind == TaskKind.note;

  /// Imported from a calendar feed: its due date belongs to the feed.
  bool get isImported => source != null;

  /// The feed's name to show ("Moodle").
  String? get sourceLabel {
    final s = source;
    if (s == null) return null;
    final label = s['label'];
    return label is String && label.isNotEmpty ? label : 'Calendar feed';
  }

  /// Returns an edited copy. `updatedAt` is now unless you pass one: a user
  /// edit bumps it, but a task copied from DeskPlan passes the PC's own value
  /// so it is never bumped. Pass `clearStart` / `clearEnd` to remove a time
  /// (null alone means "keep"). Giving a [kind] or [parentId], or asking to
  /// [clearParent] (move to the top level of Home), makes the place known.
  Task copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    bool clearStart = false,
    bool clearEnd = false,
    bool? done,
    DateTime? updatedAt,
    TaskKind? kind,
    String? parentId,
    bool clearParent = false,
    String? details,
    bool? detailsEdited,
    Map<String, Object?>? doc,
    RepeatRule? repeat,
    bool clearRepeat = false,
  }) {
    final placeChanged = kind != null || parentId != null || clearParent;
    return Task(
      id: id,
      title: title ?? this.title,
      start: clearStart ? null : (start ?? this.start),
      end: clearEnd ? null : (end ?? this.end),
      done: done ?? this.done,
      updatedAt: updatedAt ?? DateTime.now(),
      kind: kind ?? this.kind,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      placeKnown: placeChanged ? true : placeKnown,
      // Writing details makes them known, and marks them to be sent.
      details: details ?? this.details,
      detailsKnown: details != null ? true : detailsKnown,
      detailsEdited:
          detailsEdited ?? (details != null ? true : this.detailsEdited),
      createdAt: createdAt,
      createdKnown: createdKnown,
      doc: doc ?? this.doc,
      course: course,
      courseKnown: courseKnown,
      source: source,
      repeat: clearRepeat ? null : (repeat ?? this.repeat),
      // Setting or clearing it makes it known, so it is sent.
      repeatKnown: repeat != null || clearRepeat ? true : repeatKnown,
    );
  }

  /// This task, as DeskPlan sent it, with whatever DeskPlan did not say
  /// filled in from [local]: an older DeskPlan sends no description or
  /// creation time, and the phone's copy must not lose what it has.
  Task withMissingFieldsFrom(Task local) => Task(
    id: id,
    title: title,
    start: start,
    end: end,
    done: done,
    updatedAt: updatedAt,
    kind: kind,
    parentId: parentId,
    placeKnown: placeKnown,
    details: detailsKnown ? details : local.details,
    detailsKnown: detailsKnown || local.detailsKnown,
    createdAt: createdKnown ? createdAt : local.createdAt,
    createdKnown: createdKnown || local.createdKnown,
    doc: doc ?? local.doc,
    course: courseKnown ? course : local.course,
    courseKnown: courseKnown || local.courseKnown,
    source: source ?? local.source,
    repeat: repeatKnown ? repeat : local.repeat,
    repeatKnown: repeatKnown || local.repeatKnown,
  );

  /// [local] with what only DeskPlan decides taken from this reply to its
  /// `PUT` (`course`, `source`, and an imported item's `end`, which belongs
  /// to the feed). Nothing the user typed is touched.
  Task serverFieldsOnto(Task local) {
    final imported = source ?? local.source;
    return Task(
      id: local.id,
      title: local.title,
      start: local.start,
      end: imported != null ? end : local.end,
      done: local.done,
      updatedAt: local.updatedAt,
      kind: local.kind,
      parentId: local.parentId,
      placeKnown: local.placeKnown,
      details: local.details,
      detailsKnown: local.detailsKnown,
      detailsEdited: local.detailsEdited,
      createdAt: createdKnown ? createdAt : local.createdAt,
      createdKnown: createdKnown || local.createdKnown,
      doc: local.doc,
      course: courseKnown ? course : local.course,
      courseKnown: courseKnown || local.courseKnown,
      source: imported,
      repeat: local.repeat,
      repeatKnown: local.repeatKnown,
    );
  }

  /// The body DeskPlan expects (docs/protocol.md section 4):
  /// `done` is a real boolean and times are UTC text ending in "Z".
  /// A note sends its `doc` and never times, a tick or a description.
  Map<String, Object?> toSyncJson() =>
      isNote ? _noteSyncJson() : _taskSyncJson();

  Map<String, Object?> _noteSyncJson() => {
    'id': id,
    'title': title,
    'start': null,
    'end': null,
    'done': false,
    'updatedAt': updatedAt.toIso8601String(),
    'kind': kind.wireName,
    'parentId': parentId,
    'doc': ?doc,
  };

  Map<String, Object?> _taskSyncJson() => {
    'id': id,
    'title': title,
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'done': done,
    'updatedAt': updatedAt.toIso8601String(),
    // Left out when unknown, so DeskPlan keeps its own.
    if (placeKnown) 'kind': kind.wireName,
    if (placeKnown) 'parentId': parentId,
    // Only what the user changed. The creation time is never sent: DeskPlan
    // owns it.
    if (detailsEdited) 'description': details,
    if (repeatKnown) 'repeat': repeat?.toJson(),
  };

  /// Every field of DeskPlan's item that [Task.fromSyncJson] reads. When the
  /// PC starts sending one of these (or a phone update starts reading one the
  /// PC already sent), the next pull reads everything once, so items that did
  /// not change learn it too (ServerChangePuller, protocol.md `fields`).
  /// Found by watching fromSyncJson read one small item of each kind, so it
  /// never needs updating by hand.
  static final Set<String> syncFields = fieldsRead(Task.fromSyncJson, [
    for (final kind in ['task', 'assignment', 'note'])
      {
        'id': 'probe',
        'title': '',
        'done': false,
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'kind': kind,
      },
  ]);

  /// Reads DeskPlan's reply. Throws [FormatException] if it isn't a valid task.
  factory Task.fromSyncJson(Map<String, Object?> j) {
    try {
      // A DeskPlan from before assignments sends neither; the place is then
      // unknown and is not sent back.
      final hasPlace = j.containsKey('kind');
      final description = j['description'];
      if (description != null && description is! String) {
        throw const FormatException('description is not text');
      }
      final created = j['createdAt'];
      if (created != null && created is! String) {
        throw const FormatException('createdAt is not text');
      }
      final parent = j['parentId'];
      if (parent != null && parent is! String) {
        throw const FormatException('parentId is not text');
      }
      final kind = hasPlace ? TaskKind.fromWire(j['kind']) : TaskKind.task;
      final doc = j['doc'];
      if (doc != null && (doc is! Map || doc['type'] != 'doc')) {
        throw const FormatException('doc is not a note');
      }
      final course = j['course'];
      if (course != null && course is! String) {
        throw const FormatException('course is not text');
      }
      final source = j['source'];
      if (source != null && source is! Map) {
        throw const FormatException('source is not an object');
      }
      final isNote = kind == TaskKind.note;
      final repeat = j['repeat'];
      return Task(
        id: j['id'] as String,
        title: j['title'] as String,
        // A note has no times or tick on the phone, whatever the PC keeps.
        start: isNote || j['start'] == null
            ? null
            : DateTime.parse(j['start'] as String),
        end: isNote || j['end'] == null
            ? null
            : DateTime.parse(j['end'] as String),
        done: isNote ? false : j['done'] as bool,
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        kind: kind,
        parentId: parent as String?,
        placeKnown: hasPlace,
        details: description as String? ?? '',
        detailsKnown: j.containsKey('description'),
        // Without DeskPlan's, the time it is first seen here stands in.
        createdAt: created == null
            ? DateTime.now()
            : DateTime.parse(created as String),
        createdKnown: created != null,
        doc: isNote && doc != null
            ? Map<String, Object?>.from(doc as Map)
            : null,
        course: course as String?,
        // An older DeskPlan does not send it: then the folder stands in.
        courseKnown: j.containsKey('course'),
        source: source == null
            ? null
            : Map<String, Object?>.from(source as Map),
        repeat: isNote || repeat == null ? null : RepeatRule.fromJson(repeat),
        // An older DeskPlan does not send it: then the phone keeps its own.
        repeatKnown: j.containsKey('repeat'),
      );
    } on TypeError {
      throw const FormatException('Not a valid task');
    }
  }

  /// Database row. Times are UTC ISO text ending in "Z".
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'done': done ? 1 : 0,
    'updatedAt': updatedAt.toIso8601String(),
    'kind': kind.wireName,
    'parentId': parentId,
    'placeKnown': placeKnown ? 1 : 0,
    'details': details,
    'detailsKnown': detailsKnown ? 1 : 0,
    'detailsEdited': detailsEdited ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'createdKnown': createdKnown ? 1 : 0,
    'doc': doc == null ? null : jsonEncode(doc),
    'course': course,
    'courseKnown': courseKnown ? 1 : 0,
    'source': source == null ? null : jsonEncode(source),
    'repeat': repeat == null ? null : jsonEncode(repeat!.toJson()),
    'repeatKnown': repeatKnown ? 1 : 0,
  };

  factory Task.fromMap(Map<String, Object?> m) {
    return Task(
      id: m['id'] as String,
      title: m['title'] as String,
      start: m['start'] == null ? null : DateTime.parse(m['start'] as String),
      end: m['end'] == null ? null : DateTime.parse(m['end'] as String),
      done: (m['done'] as int) == 1,
      updatedAt: DateTime.parse(m['updatedAt'] as String),
      kind: TaskKind.fromWire(m['kind']),
      parentId: m['parentId'] as String?,
      placeKnown: (m['placeKnown'] as int) == 1,
      details: (m['details'] as String?) ?? '',
      detailsKnown: (m['detailsKnown'] as int?) == 1,
      detailsEdited: (m['detailsEdited'] as int?) == 1,
      createdAt: m['createdAt'] == null
          ? null
          : DateTime.parse(m['createdAt'] as String),
      createdKnown: (m['createdKnown'] as int?) == 1,
      doc: m['doc'] == null
          ? null
          : Map<String, Object?>.from(jsonDecode(m['doc'] as String) as Map),
      course: m['course'] as String?,
      courseKnown: (m['courseKnown'] as int?) == 1,
      source: m['source'] == null
          ? null
          : Map<String, Object?>.from(jsonDecode(m['source'] as String) as Map),
      repeat: m['repeat'] == null
          ? null
          : RepeatRule.fromJson(jsonDecode(m['repeat'] as String)),
      repeatKnown: (m['repeatKnown'] as int?) == 1,
    );
  }
}
