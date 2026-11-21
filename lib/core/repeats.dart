import 'repeat_rule.dart';
import 'task.dart';

/// The next copy of a repeating item, worked out exactly as DeskPlan does
/// (renderer/modules/workspace/Repeats.js), so when both make it they make
/// the same item: same id, same times. "Last edit wins" then merges them.
class Repeats {
  static const _maxId = 64;
  static const _rootMax = 52;
  static const _maxSteps = 1000;
  static final _copy = RegExp(r'^(.*)\.r(\d+)$');

  /// "abc" -> "abc.r1", "abc.r1" -> "abc.r2". A root too long to fit is cut
  /// to its first 52 characters.
  static String nextId(String id) {
    final m = _copy.firstMatch(id);
    final root = m == null ? id : m.group(1)!;
    final n = m == null ? 1 : int.parse(m.group(2)!) + 1;
    final next = '$root.r$n';
    return next.length <= _maxId ? next : '${root.substring(0, _rootMax)}.r$n';
  }

  /// "abc.r3" -> "abc", "abc" -> "abc": the id every copy of a series shares.
  static String rootOf(String id) => _copy.firstMatch(id)?.group(1) ?? id;

  /// "abc" -> 0, "abc.r3" -> 3: where a copy comes in its series.
  static int numberOf(String id) {
    final m = _copy.firstMatch(id);
    return m == null ? 0 : int.parse(m.group(2)!);
  }

  /// [time] moved on by [steps] of [rule], in local time (a 9:00 class stays
  /// at 9:00 across a clock change). A monthly date past the end of a shorter
  /// month falls on its last day.
  static DateTime shift(DateTime time, RepeatRule rule, int steps) {
    final t = time.toLocal();
    DateTime at(int y, int mo, int d) =>
        DateTime(y, mo, d, t.hour, t.minute, t.second, t.millisecond);
    switch (rule.every) {
      case RepeatEvery.day:
        return at(t.year, t.month, t.day + rule.interval * steps);
      case RepeatEvery.week:
        return at(t.year, t.month, t.day + 7 * rule.interval * steps);
      case RepeatEvery.month:
        final first = DateTime(t.year, t.month + rule.interval * steps);
        final last = DateTime(first.year, first.month + 1, 0).day;
        return at(first.year, first.month, t.day < last ? t.day : last);
    }
  }

  /// The next copy's start and end, or null when the series has ended. Both
  /// move by the fewest steps that put the end after [now].
  static ({DateTime? start, DateTime end})? nextTimes({
    required DateTime end,
    DateTime? start,
    required RepeatRule rule,
    required DateTime now,
  }) {
    var steps = 1;
    while (!shift(end, rule, steps).isAfter(now) && steps < _maxSteps) {
      steps++;
    }
    final nextEnd = shift(end, rule, steps);
    final until = rule.until;
    if (until != null && nextEnd.isAfter(until)) return null;
    return (
      start: start == null ? null : shift(start, rule, steps).toUtc(),
      end: nextEnd.toUtc(),
    );
  }

  /// A task or assignment with a due time, not imported from a feed.
  static bool canRepeat(Task t) => !t.isNote && t.end != null && !t.isImported;

  /// The next copy of [task], or null (no rule, or the series ended). Does
  /// not check whether it exists already: the caller does.
  static Task? nextCopy(Task task, DateTime now) {
    final rule = task.repeat;
    final end = task.end;
    if (rule == null || end == null || !canRepeat(task)) return null;
    final times = nextTimes(end: end, start: task.start, rule: rule, now: now);
    if (times == null) return null;
    return Task(
      id: nextId(task.id),
      title: task.title,
      start: times.start,
      end: times.end,
      updatedAt: now,
      kind: task.kind,
      parentId: task.parentId,
      placeKnown: task.placeKnown,
      details: task.details,
      detailsKnown: task.detailsKnown,
      // A new item: its details go with it.
      detailsEdited: task.details.isNotEmpty,
      createdAt: now,
      repeat: rule,
    );
  }

  /// The copies due because an occurrence ended without being ticked off
  /// (protocol.md "Repeating items", auto-advance): its next copy is made
  /// all the same, and it stays not done (missed). Only a series' latest
  /// copy qualifies: the older ones' next ids exist already.
  static List<Task> dueCopies(List<Task> tasks, DateTime now) {
    final ids = {for (final t in tasks) t.id};
    final copies = <Task>[];
    for (final t in tasks) {
      final end = t.end;
      if (t.done || t.repeat == null || end == null || end.isAfter(now)) {
        continue;
      }
      if (ids.contains(nextId(t.id))) continue;
      final copy = nextCopy(t, now);
      if (copy != null && ids.add(copy.id)) copies.add(copy);
    }
    return copies;
  }

  /// The repeating series among [tasks]: copies sharing a root id where at
  /// least one has a rule. Soonest next occurrence first, ended ones last.
  static List<TaskSeries> seriesOf(List<Task> tasks) {
    final byRoot = <String, List<Task>>{};
    for (final t in tasks) {
      if (t.isNote) continue;
      byRoot.putIfAbsent(rootOf(t.id), () => []).add(t);
    }
    final series = [
      for (final MapEntry(:key, :value) in byRoot.entries)
        if (value.any((t) => t.repeat != null))
          TaskSeries(
            key,
            value..sort((a, b) => numberOf(a.id).compareTo(numberOf(b.id))),
          ),
    ];
    final now = DateTime.now();
    series.sort((a, b) {
      final ae = a.ended(now), be = b.ended(now);
      if (ae != be) return ae ? 1 : -1;
      final at = a.latest.end, bt = b.latest.end;
      if (at == null || bt == null) return 0;
      return at.compareTo(bt);
    });
    return series;
  }
}

/// The copies of one repeating item, oldest first. The last is the current
/// one: the next to happen, or the last that happened when it has ended.
class TaskSeries {
  final String root;
  final List<Task> members;

  const TaskSeries(this.root, this.members);

  Task get latest => members.last;

  /// The earlier copies, newest first: done or missed.
  List<Task> get past => members.reversed.skip(1).toList();

  /// No more copies to come: the rule was removed, or the latest is done or
  /// over and nothing follows before `until`.
  bool ended(DateTime now) {
    final l = latest;
    final end = l.end;
    if (l.repeat == null || end == null) return true;
    if (!l.done && end.isAfter(now)) return false;
    return Repeats.nextTimes(
          end: end,
          start: l.start,
          rule: l.repeat!,
          now: now,
        ) ==
        null;
  }

  /// Up to [max] times after the latest copy that its rule will make,
  /// stopping at its `until` and at [horizon]. Not stored: shown ahead.
  List<({DateTime? start, DateTime end})> upcoming({
    int max = 12,
    DateTime? horizon,
  }) {
    final rule = latest.repeat;
    final end = latest.end;
    if (rule == null || end == null || !Repeats.canRepeat(latest)) {
      return const [];
    }
    final out = <({DateTime? start, DateTime end})>[];
    for (var step = 1; out.length < max; step++) {
      final e = Repeats.shift(end, rule, step);
      final until = rule.until;
      if (until != null && e.isAfter(until)) break;
      if (horizon != null && e.isAfter(horizon)) break;
      final s = latest.start;
      out.add((
        start: s == null ? null : Repeats.shift(s, rule, step).toUtc(),
        end: e.toUtc(),
      ));
    }
    return out;
  }

  /// The copies still ahead of [now] (ticked off early), changed to follow
  /// the latest copy after an edit there: the same title, details
  /// and rule, and times one step of the rule apart, counted back from the
  /// latest. Only those that differ are answered. The ones whose time has
  /// passed are history and keep what they were.
  List<Task> followers(DateTime now) {
    final rule = latest.repeat;
    final end = latest.end;
    if (rule == null || end == null) return const [];
    final changed = <Task>[];
    var steps = 0;
    for (var i = members.length - 2; i >= 0; i--) {
      final m = members[i];
      final mEnd = m.end;
      if (mEnd == null || !mEnd.isAfter(now)) break;
      steps--;
      final start = latest.start == null
          ? null
          : Repeats.shift(latest.start!, rule, steps).toUtc();
      final newEnd = Repeats.shift(end, rule, steps).toUtc();
      final same =
          m.title == latest.title &&
          m.details == latest.details &&
          m.repeat == rule &&
          m.start == start &&
          m.end == newEnd;
      if (same) continue;
      changed.add(
        m.copyWith(
          title: latest.title,
          details: m.details == latest.details ? null : latest.details,
          repeat: rule,
          start: start,
          clearStart: start == null,
          end: newEnd,
          updatedAt: now,
        ),
      );
    }
    return changed;
  }

  bool contains(String id) => members.any((t) => t.id == id);
}
