import 'package:uuid/uuid.dart';

import '../calendar/calendar_event.dart';
import '../calendar/calendar_event_kind.dart';
import '../calendar/calendar_store.dart';
import '../calendar/exam_reminders.dart';
import 'feed_fetcher.dart';
import 'feed_mappers.dart';
import 'feed_store.dart';
import 'ics_parser.dart';
import 'phone_feed.dart';

/// One course of a feed, for the list in Timetables and courses.
class FeedCourse {
  final String key;
  final String name;

  /// Lectures and exams still to come.
  final int lectures;
  final int exams;
  final bool hidden;

  const FeedCourse(this.key, this.name, this.lectures, this.exams, this.hidden);
}

/// What the user can do with calendar feeds on the phone, and downloading
/// them. Every change is marked to send to DeskPlan (FeedSettingsSync), and
/// each feed is downloaded straight from its server: no PC needed.
class FeedService {
  /// A feed is downloaded again when its copy is older than this.
  static const maxAge = Duration(hours: 6);

  final FeedStore store;
  final CalendarStore calendar;
  final FeedFetcher fetcher;
  final ExamReminders? reminders;
  final DateTime Function() _now;

  FeedService(
    this.store,
    this.calendar,
    this.fetcher, {
    this.reminders,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Subscribes to an address: it is downloaded first, so nothing is saved
  /// when it is not a calendar. Returns the feed, or throws [FeedFetchError].
  Future<PhoneFeed> add(String input) async {
    final url = FeedFetcher.normalizeUrl(input);
    for (final f in await store.active()) {
      if (await store.urls.read(f.id) == url) {
        throw const FeedFetchError('This calendar is already added.');
      }
    }
    final parsed = _parse(await fetcher.fetchText(url));
    final kind = FeedKind.ofProducer(parsed.producer);
    final host = Uri.parse(url).host;
    final now = _now();
    final feed = PhoneFeed(
      id: const Uuid().v4(),
      name: kind.nameFor(parsed.name, host),
      kind: kind,
      host: host,
      updatedAt: now,
      dirty: true,
    );
    await store.urls.write(feed.id, url);
    await _apply(feed, parsed, now);
    return (await store.get(feed.id))!;
  }

  Future<void> rename(String id, String name) async {
    final feed = await store.get(id);
    final trimmed = name.trim();
    if (feed == null || trimmed.isEmpty || trimmed == feed.name) return;
    await store.save(
      feed.copyWith(name: trimmed, updatedAt: _now(), dirty: true),
    );
  }

  /// Removed here and, at the next sync, on DeskPlan. Its events go now.
  Future<void> remove(String id) async {
    final feed = await store.get(id);
    if (feed == null) return;
    await _replaceEvents(() => calendar.removeFeed(id));
    await store.urls.delete(id);
    await store.save(
      feed.copyWith(removed: true, updatedAt: _now(), dirty: true),
    );
  }

  /// Shows or hides courses of a feed, here and (next sync) on DeskPlan.
  Future<void> setHidden(String feedId, Iterable<String> keys, bool hidden) =>
      _replaceEvents(() async {
        for (final key in keys) {
          await store.saveChoice(
            CourseChoice(
              feedId: feedId,
              key: key,
              hidden: hidden,
              updatedAt: _now(),
              dirty: true,
            ),
          );
        }
      });

  /// DeskPlan's course choices replace the phone's (FeedSettingsSync).
  Future<void> replaceChoices(List<CourseChoice> choices) =>
      _replaceEvents(() => store.replaceChoices(choices));

  /// The courses in a feed's last download, A-Z.
  Future<List<FeedCourse>> courses(String feedId) async {
    final hidden = {
      for (final c in await store.choices())
        if (c.feedId == feedId && c.hidden) c.key,
    };
    final now = _now();
    final byKey = <String, ({String name, int lectures, int exams})>{};
    for (final e in await calendar.feedEvents(feedId)) {
      final course = e.course;
      if (course == null || course.isEmpty) continue;
      final key = CalendarEvent.courseKeyOf(course);
      final c = byKey[key] ?? (name: course, lectures: 0, exams: 0);
      final ahead = e.end.isAfter(now);
      final exam = e.kind == CalendarEventKind.exam;
      byKey[key] = (
        name: exam ? c.name : course,
        lectures: c.lectures + (ahead && !exam ? 1 : 0),
        exams: c.exams + (ahead && exam ? 1 : 0),
      );
    }
    return [
      for (final MapEntry(:key, :value) in byKey.entries)
        FeedCourse(
          key,
          value.name,
          value.lectures,
          value.exams,
          hidden.contains(key),
        ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Downloads every feed whose copy is older than [maxAge] (or all, with
  /// [force]). A feed that fails keeps its last events and says why.
  Future<void> refreshDue({bool force = false}) async {
    final now = _now();
    for (final feed in await store.active()) {
      final last = feed.lastFetched;
      if (force || last == null || now.difference(last) >= maxAge) {
        await refresh(feed.id);
      }
    }
  }

  /// Downloads one feed. Returns the problem, or null.
  Future<String?> refresh(String id) async {
    final feed = await store.get(id);
    final url = await store.urls.read(id);
    if (feed == null || feed.removed) return null;
    if (url == null) {
      const problem = 'This calendar has no address on this phone yet.';
      await store.save(feed.copyWith(lastError: problem));
      return problem;
    }
    try {
      final parsed = _parse(await fetcher.fetchText(url));
      await _apply(feed, parsed, _now());
      return null;
    } on FeedFetchError catch (e) {
      await store.save(feed.copyWith(lastError: e.message));
      return e.message;
    }
  }

  ParsedFeed _parse(String text) {
    try {
      return IcsParser.parse(text, now: _now());
    } on FormatException catch (e) {
      throw FeedFetchError(e.message);
    }
  }

  /// Keeps a download: its lectures, exams and other events, named as
  /// DeskPlan names them (`feed:<feedId>|<uid>`), so both agree. Moodle due
  /// dates are not events: DeskPlan makes them assignments, which sync.
  Future<void> _apply(PhoneFeed feed, ParsedFeed parsed, DateTime now) async {
    final kind = FeedKind.ofProducer(parsed.producer);
    final events = <CalendarEvent>[];
    for (final e in parsed.events) {
      final m = FeedMappers.map(kind, e);
      final type = switch (m.type) {
        MappedType.lecture => CalendarEventKind.lecture,
        MappedType.exam => CalendarEventKind.exam,
        MappedType.event => CalendarEventKind.event,
        _ => null,
      };
      if (type == null) continue;
      events.add(
        CalendarEvent(
          id: 'feed:${feed.id}|${e.uid}',
          kind: type,
          title: m.title.isEmpty ? 'Untitled' : m.title,
          context: m.context,
          start: e.start,
          end: e.end ?? e.start,
          course: m.course.isEmpty ? null : m.course,
          feedId: feed.id,
        ),
      );
    }
    await _replaceEvents(() => calendar.replaceFeed(feed.id, events, now));
    await store.save(
      feed.copyWith(
        kind: kind,
        lastFetched: now,
        clearError: true,
        count: parsed.events.length,
      ),
    );
  }

  /// Runs [change] and puts exam reminders right for what it changed.
  Future<void> _replaceEvents(Future<void> Function() change) async {
    final before = reminders == null ? null : await calendar.events();
    await change();
    if (before == null) return;
    try {
      await reminders!.replace(before, await calendar.events());
    } catch (_) {
      // Reminders are a bonus: the events are kept either way.
    }
  }
}
