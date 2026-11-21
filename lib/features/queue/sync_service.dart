import 'dart:async';

import '../../core/repeat_advancer.dart';
import '../background/background_sync.dart';
import '../calendar/calendar_fetcher.dart';
import '../connection/connection_checker.dart';
import '../connection/ping_result.dart';
import '../feeds/feed_service.dart';
import '../feeds/feed_settings_sync.dart';
import '../files/upload_processor.dart';
import '../pull/change_puller.dart';
import 'queue_processor.dart';
import 'sync_report.dart';

/// Pings DeskPlan, then (if it answered) sends the queued tasks and files, and
/// tells listeners what happened. Safe to call [syncNow] from anywhere, as often as
/// you like.
class SyncService {
  final ConnectionChecker _checker;
  final QueueProcessor _processor;
  final UploadProcessor _uploads;
  final ChangePuller _puller;
  final BackgroundSync _background;

  /// Null where nothing shows a calendar (the background worker).
  final CalendarFetcher? _calendar;

  /// The calendar feeds the phone downloads itself, and the list it shares
  /// with DeskPlan (protocol.md section 5,
  /// `/v1/feed-settings`). Null where nothing shows them.
  final FeedService? _feeds;
  final FeedSettingsSync? _feedSync;

  /// Makes the next copy of a repeating item whose time passed unticked,
  /// before the queue is sent. Null in tests that do not care.
  final RepeatAdvancer? _advancer;
  final _reports = StreamController<SyncReport>.broadcast();
  bool _busy = false;
  bool _again = false;

  SyncService(
    this._checker,
    this._processor,
    this._uploads,
    this._puller, {
    this._background = const NoBackgroundSync(),
    this._calendar,
    this._feeds,
    this._feedSync,
    this._advancer,
  });

  /// One report per finished run.
  Stream<SyncReport> get reports => _reports.stream;

  /// Starts a run. If one is already going, asks it to go round once more
  /// afterwards, so a change made mid-run is not left waiting.
  Future<void> syncNow() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        final report = await _runOnce();
        await _askForRetryIfNeeded(report);
        _reports.add(report);
      } while (_again);
    } finally {
      _busy = false;
    }
  }

  /// If something is still waiting (the PC could not be reached, or a file
  /// has to be tried again), have the background worker look again when the
  /// phone is next on Wi-Fi, even if the app is closed by then.
  Future<void> _askForRetryIfNeeded(SyncReport report) async {
    if (report.unreachableReason == null && report.retryLater == 0) return;
    try {
      await _background.requestSoon();
    } catch (_) {
      // Without it the regular check and the next app start still sync.
    }
  }

  Future<SyncReport> _runOnce() async {
    await _advancer?.run();
    switch (await _checker.check()) {
      case PingBlocked(:final problem):
        // The feeds come from their own servers: they still update, on
        // mobile data too.
        await _refreshFeeds();
        // Not worth trying the queue: every request would fail the same way.
        return SyncReport()
          ..unreachableReason = problem.message
          ..unreachableCause = problem.cause
          ..retrySoon = problem.retrySoon;
      case PingOk(:final info):
        // Notes go only to a DeskPlan that syncs them (ping `features`).
        final report = await _processor.run(syncNotes: info.syncsNotes);
        report.pcInfo = info;
        // If the tasks could not get through, the files would not either.
        if (report.unreachableReason == null) {
          await _uploads.run(report, pc: info);
        }
        // Send first, then pull (protocol.md section 5), so the phone's own
        // newer edits are with DeskPlan before its changes come back.
        if (report.unreachableReason == null) {
          await _pull(report, notes: info.syncsNotes);
        }
        // The calendar is fetched on the same triggers as the pull, and only
        // while the ping lists it (protocol.md section 5).
        if (report.unreachableReason == null) {
          if (info.sharesFeeds && _feedSync != null) {
            await _syncFeeds(report);
          } else {
            await _fetchCalendar(report, enabled: info.hasCalendar);
            await _refreshFeeds();
          }
        }
        return report;
    }
  }

  Future<void> _pull(SyncReport report, {required bool notes}) async {
    final outcome = await _puller.pull(notes: notes);
    report.pulled = outcome.changed;
    report.pullUnsupported = outcome.unsupported;
    report.pullFailure = outcome.failure;
    final blocked = outcome.blocked;
    if (blocked != null) {
      report
        ..unreachableReason = blocked.message
        ..unreachableCause = blocked.cause
        ..retrySoon = blocked.retrySoon;
    }
  }

  Future<void> _fetchCalendar(
    SyncReport report, {
    required bool enabled,
  }) async {
    final calendar = _calendar;
    if (calendar == null) return;
    if (!enabled) {
      await calendar.hide();
      return;
    }
    final outcome = await calendar.fetch();
    report.calendarUpdated = outcome.updated;
    report.calendarFailure = outcome.failure;
    final blocked = outcome.blocked;
    if (blocked != null) {
      report
        ..unreachableReason = blocked.message
        ..unreachableCause = blocked.cause
        ..retrySoon = blocked.retrySoon;
    }
  }

  /// The shared feed list first, then the downloads; DeskPlan's own copy of
  /// the events is no longer needed (the phone has the feeds themselves).
  Future<void> _syncFeeds(SyncReport report) async {
    final outcome = await _feedSync!.run();
    final blocked = outcome.blocked;
    if (blocked != null) {
      report
        ..unreachableReason = blocked.message
        ..unreachableCause = blocked.cause
        ..retrySoon = blocked.retrySoon;
      return;
    }
    report.calendarFailure = outcome.failure;
    try {
      await _feeds?.calendar.clearFromPc();
    } catch (_) {}
    await _refreshFeeds();
    report.calendarUpdated = outcome.failure == null;
  }

  Future<void> _refreshFeeds() async {
    try {
      await _feeds?.refreshDue();
    } catch (_) {
      // Each feed keeps its last copy and says why; tried again next time.
    }
  }

  void dispose() => _reports.close();
}
