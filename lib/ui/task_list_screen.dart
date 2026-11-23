import 'dart:async';

import 'package:flutter/material.dart';

import '../features/background/background_guide_store.dart';
import '../features/calendar/calendar_event.dart';
import '../features/calendar/calendar_store.dart';
import '../features/connection/connection_light.dart';
import '../features/connection/unreachable_cause.dart';
import '../features/discovery/typed_address_store.dart';
import '../features/feeds/feed_service.dart';
import '../features/files/file_services.dart';
import '../features/pairing/pairing_screen.dart';
import '../features/share_intake/shared_item.dart';
import '../features/pairing/pairing_store.dart';
import '../features/queue/action_queue.dart';
import '../features/queue/sync_report.dart';
import '../features/queue/sync_service.dart';
import '../features/reminders/goal_reminder_store.dart';
import '../features/reminders/reminder_options_store.dart';
import '../features/reminders/reminder_permissions.dart';
import '../features/reminders/notification_target.dart';
import '../features/reminders/notification_taps.dart';
import '../features/reminders/pushed_items.dart';
import '../features/reminders/reminder_scheduler.dart';
import '../core/repeat_advancer.dart';
import '../core/repeats.dart';
import '../core/task.dart';
import '../core/task_kind.dart';
import '../core/task_remover.dart';
import '../core/task_tree.dart';
import '../features/connection/destination.dart';
import '../core/task_repository.dart';
import 'add_sheet.dart';
import 'assignment_card.dart';
import 'assignment_sheet.dart';
import 'background_guide_screen.dart';
import 'calendar/calendar_entry.dart';
import 'calendar/calendar_view.dart';
import 'calendar/event_details_sheet.dart';
import 'connection_banner.dart';
import 'connection_icon_button.dart';
import 'course_names.dart';
import 'date_text.dart';
import 'feeds_screen.dart';
import 'notes/note_page.dart';
import 'notes/note_places.dart';
import 'notes/note_tile.dart';
import 'reminder_settings_screen.dart';
import 'section_header.dart';
import 'series_card.dart';
import 'series_details_sheet.dart';
import 'settings_tab.dart';
import 'share_screen.dart';
import 'sync_refresh.dart';
import 'task_groups.dart';
import 'task_sheet.dart';
import 'task_tile.dart';
import 'theme/deskplan_colors.dart';
import 'uploads_screen.dart';

/// The tabs of the bar at the bottom, in its order.
/// Filled icons; the open one is coloured, with no pill around it.
enum _Section {
  calendar('Calendar', Icons.calendar_month),
  assignments('Assignments', Icons.assignment),
  tasks('Tasks', Icons.check_circle),
  notes('Notes', Icons.sticky_note_2),
  settings('Settings', Icons.settings);

  final String label;
  final IconData icon;
  const _Section(this.label, this.icon);
}

/// The pages Settings opens, remembered so they can be opened again when
/// Android brings the app back after closing it.
enum _SettingsPage { connection, files, reminders, timetables }

/// The app's main screen: a bar of icons at the bottom (Calendar,
/// Assignments, Tasks, Notes, Settings), each opening its own page. Tap a
/// row to open it, "+" to add. Changes sync to DeskPlan in the background.
class TaskListScreen extends StatefulWidget {
  /// Should be the repository that queues changes for DeskPlan.
  final TaskRepository repository;
  final ActionQueue queue;
  final SyncService sync;
  final PairingStore pairingStore;
  final TypedAddressStore addressStore;
  final FileServices files;
  final GoalReminderStore goalStore;
  final ReminderOptionsStore reminderOptions;

  /// Sets the task and exam reminders again after [reminderOptions] changed.
  final Future<void> Function() onReminderOptionsChanged;
  final ReminderScheduler reminders;
  final ReminderPermissions reminderPermissions;
  final BackgroundGuideStore guideStore;

  /// DeskPlan's calendar events kept on the phone.
  final CalendarStore calendar;

  /// Tapped notifications: each opens the item or exam it is about.
  final NotificationTaps notificationTaps;

  /// The calendar feeds shared with DeskPlan. Null hides Timetables and
  /// courses.
  final FeedService? feeds;

  const TaskListScreen({
    super.key,
    required this.repository,
    required this.queue,
    required this.sync,
    required this.pairingStore,
    required this.addressStore,
    required this.files,
    required this.goalStore,
    required this.reminderOptions,
    required this.onReminderOptionsChanged,
    required this.reminders,
    required this.reminderPermissions,
    required this.guideStore,
    required this.calendar,
    required this.notificationTaps,
    this.feeds,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen>
    with WidgetsBindingObserver, RestorationMixin {
  /// While the app is open, look again this often (in the background, the
  /// worker does it).
  static const _syncEvery = Duration(minutes: 5);

  TaskRepository get _storage => widget.repository;
  TaskTree _tree = TaskTree(const []);

  /// The tab that is open. The calendar comes first. Kept by Android while
  /// the app is in the background, so it comes back on the same tab.
  final _openSection = RestorableEnum<_Section>(
    _Section.calendar,
    values: _Section.values,
  );
  _Section get _section => _openSection.value;
  set _section(_Section section) => _openSection.value = section;

  /// The settings page open on top, if any, kept the same way.
  final _openPage = RestorableEnumN<_SettingsPage>(
    null,
    values: _SettingsPage.values,
  );

  @override
  String get restorationId => 'tasks';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_openSection, 'section');
    registerForRestoration(_openPage, 'page');
    // Android closed the app while a settings page was open: open it again.
    final page = _openPage.value;
    if (initialRestore && page != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSettingsPage(page);
      });
    }
  }

  /// DeskPlan's folders, from the last time it was reached (empty before).
  List<Destination> _folders = [];
  int _waiting = 0;

  /// The repeating tasks: one card each at the top of Tasks, their
  /// occurrences out of the list.
  List<TaskSeries> _series = const [];

  /// True when DeskPlan said (last time it was reached) that it syncs notes.
  bool _notesOn = false;

  /// True when DeskPlan said (last time it was reached) that it has calendar
  /// feeds. Only then are its events shown (protocol.md section 5).
  bool _calendarOn = false;
  List<CalendarEvent> _events = const [];
  DateTime? _eventsAsOf;

  /// The PC's name, from the last time it was reached.
  String? _pcName;

  /// Why the last sync couldn't reach DeskPlan, if it couldn't.
  String? _blockedReason;
  UnreachableCause? _blockedCause;

  /// True when DeskPlan answered the last time; and whether a PC is paired.
  bool _reached = false;

  /// When DeskPlan last answered while the app was open.
  DateTime? _lastSynced;

  /// The "DeskPlan is too old" note is shown once, not at every sync.
  bool _toldPullUnsupported = false;
  bool _isPaired = false;
  StreamSubscription<SyncReport>? _reports;
  StreamSubscription<NotificationTarget>? _taps;
  Timer? _retryTimer;
  Timer? _regularSync;

  /// A reminder's "Extend 1 hr" button, pressed while the app is open.
  final _pushed = PushedItems();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reports = widget.sync.reports.listen(_onReport);
    _taps = widget.notificationTaps.stream.listen(_openTarget);
    _pushed.listen(_reload);
    // A notification that started the app opens its item once the list is
    // loaded.
    _reload().then((_) {
      final launch = widget.notificationTaps.takeLaunch();
      if (launch != null) _openTarget(launch);
    });
    widget.sync.syncNow();
    _regularSync = Timer.periodic(_syncEvery, (_) => widget.sync.syncNow());
    _showGuideOnce();
    _refreshPaired();
  }

  Future<void> _refreshPaired() async {
    final paired = await widget.pairingStore.load() != null;
    if (mounted) setState(() => _isPaired = paired);
  }

  /// What the dot on the connection icon shows.
  ConnectionLight get _light => (!_isPaired && !_reached)
      ? ConnectionLight.off
      : ConnectionLight.from(cause: _blockedCause, reached: _reached);

  /// Coming back to the app (for example after a Wi-Fi change) syncs at once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.sync.syncNow();
  }

  /// The first time the app is used, explain how to keep it syncing while
  /// closed (it opens Android's battery settings).
  Future<void> _showGuideOnce() async {
    if (await widget.guideStore.wasShown()) return;
    await widget.guideStore.markShown();
    if (mounted) _openGuide();
  }

  Future<void> _openGuide() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => BackgroundGuideScreen(
        onOpenSettings: widget.reminderPermissions.openBatterySettings,
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _regularSync?.cancel();
    _reports?.cancel();
    _taps?.cancel();
    _pushed.close();
    _retryTimer?.cancel();
    _openSection.dispose();
    _openPage.dispose();
    super.dispose();
  }

  void _onReport(SyncReport report) {
    // A run that did nothing (another was going) says nothing new.
    if (!report.skipped) {
      _blockedReason = report.unreachableReason;
      _blockedCause = report.unreachableCause;
      _reached = report.pcInfo != null && report.unreachableReason == null;
      if (_reached) _lastSynced = DateTime.now();
    }
    // For example "Waiting for approval on your PC": look again every few
    // seconds while this screen is open (protocol.md section 1).
    _retryTimer?.cancel();
    if (report.retrySoon) {
      _retryTimer = Timer(const Duration(seconds: 8), widget.sync.syncNow);
    }
    if (report.rejections.isNotEmpty && mounted) _toast(report.rejections);
    // A DeskPlan from before the pull cannot send its changes. The phone
    // keeps working as it did (it only sends), so this is a note, not an
    // error, and it is shown only once.
    if (report.pullUnsupported && !_toldPullUnsupported && mounted) {
      _toldPullUnsupported = true;
      _toast([
        'Your DeskPlan is too old to send changes to this phone. '
            'Update DeskPlan on your PC to see tasks changed there.',
      ]);
    }
    _reload(); // a run may have removed actions or updated tasks
  }

  /// Shows the first message, and how many more there are.
  void _toast(List<String> messages) {
    final more = messages.length > 1 ? '  (+${messages.length - 1} more)' : '';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${messages.first}$more'),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Opens what a tapped notification is about: the task or assignment (a
  /// step opens its assignment), or the exam's details in the calendar.
  Future<void> _openTarget(NotificationTarget target) async {
    if (!mounted) return;
    // Close anything open on top (a sheet, another page) first.
    Navigator.of(context).popUntil((route) => route.isFirst);
    switch (target) {
      case ItemTarget(:final id):
        await _reload();
        final task = await _storage.get(id);
        if (!mounted) return;
        if (task == null) {
          _toast(['That item is no longer on this phone']);
          return;
        }
        setState(() {
          _section = task.isAssignment || _tree.isStep(task)
              ? _Section.assignments
              : task.isNote
              ? _Section.notes
              : _Section.tasks;
        });
        await _openFromCalendar(task);
      case EventTarget(:final id):
        final found = (await widget.calendar.events()).where((e) => e.id == id);
        if (!mounted) return;
        setState(() => _section = _Section.calendar);
        if (found.isEmpty) {
          _toast(['That event is no longer in your calendar']);
          return;
        }
        await EventDetailsSheet.show(context, found.first, all: _events);
    }
  }

  Future<void> _reload() async {
    // An occurrence that ended unticked: its next one comes all the same.
    await RepeatAdvancer(_storage).run();
    final tasks = await _storage.all();
    // Feed and course changes wait for DeskPlan too.
    final waiting =
        await widget.queue.pendingCount() +
        (await widget.feeds?.store.dirtyCount() ?? 0);
    final info = await widget.files.pcInfoStore.load();
    // The phone's own feeds show even before DeskPlan was ever reached.
    final calendarOn =
        (info?.hasCalendar ?? false) ||
        (await widget.feeds?.store.active() ?? const []).isNotEmpty;
    final events = calendarOn
        ? await widget.calendar.events()
        : const <CalendarEvent>[];
    final asOf = calendarOn ? await widget.calendar.asOf() : null;
    if (mounted) {
      setState(() {
        _folders = [...?info?.destinations.where((d) => !d.isReceivedFiles)];
        _tree = TaskTree(tasks);
        _series = Repeats.seriesOf(
          _tree.listed.where((t) => t.kind == TaskKind.task).toList(),
        );
        _waiting = waiting;
        _notesOn = info?.syncsNotes ?? false;
        _calendarOn = calendarOn;
        _events = events;
        _eventsAsOf = asOf;
        _pcName = info?.name;
      });
    }
  }

  /// The "+" button: a task, or files picked from inside the app. In the
  /// notes list it writes a new note straight away.
  Future<void> _add() async {
    if (_section == _Section.notes) {
      await _openNote(null);
      return;
    }
    final choice = await AddSheet.show(
      context,
      assignmentAvailable: _folders.isNotEmpty,
      noteAvailable: _notesOn,
    );
    if (!mounted) return;
    switch (choice) {
      case AddChoice.task:
        await _open();
      case AddChoice.assignment:
        await _open(null, TaskKind.assignment);
      case AddChoice.note:
        await _openNote(null);
      case AddChoice.files:
        await _pickFiles();
      case null:
        break;
    }
  }

  /// Where notes can go: Home, DeskPlan's folders and the assignments here.
  NotePlaces get _notePlaces =>
      NotePlaces(_folders, _tree.listed.where((t) => t.isAssignment).toList());

  /// Opens [note], or a new one, on its own page. It saves as it is
  /// written; coming back refreshes the list and syncs.
  Future<void> _openNote(Task? note) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => NotePage(
          note: note,
          repository: _storage,
          syncNow: widget.sync.syncNow,
          syncReports: widget.sync.reports,
          places: _notePlaces,
        ),
      ),
    );
    await _changed();
  }

  Future<void> _pickFiles() async {
    final List<SharedFile> picked;
    try {
      picked = await widget.files.picker.pick();
    } catch (e) {
      // Never fail silently: say what went wrong.
      if (mounted) _toast(['Could not open the file chooser: $e']);
      return;
    }
    if (picked.isEmpty || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ShareScreen(items: picked, files: widget.files, sync: widget.sync),
      ),
    );
  }

  /// Opens the sheet to add a task or assignment, or to edit [task]. An
  /// assignment opens its own sheet, with its steps.
  Future<void> _open([
    Task? task,
    TaskKind kind = TaskKind.task,
    List<(String, bool)> clashes = const [],
  ]) async {
    if (task != null && task.isNote) return _openNote(task);
    if (task != null && task.isAssignment) {
      await AssignmentSheet.show(
        context,
        assignmentId: task.id,
        repository: _storage,
        folders: _folders,
        onChanged: _changed,
        clashes: clashes,
      );
      return;
    }
    final result = await TaskSheet.show(
      context,
      task: task,
      kind: kind,
      folders: _folders,
      clashes: clashes,
    );
    if (result is Task) {
      await _storage.save(result);
    } else if (result == TaskSheet.deleted && task != null) {
      await TaskRemover(_storage).remove(task);
    } else {
      return; // dismissed, nothing changed
    }
    await _changed();
  }

  /// A repeating task's details: its timeline, a pen to edit it and a way
  /// to delete it whole.
  Future<void> _openSeries(
    TaskSeries series, [
    List<(String, bool)> clashes = const [],
  ]) async {
    final action = await SeriesDetailsSheet.show(
      context,
      series,
      clashes: clashes,
      onToggle: (t) async {
        await _storage.save(t.copyWith(done: !t.done));
        await _changed();
        return _series.where((s) => s.root == series.root).firstOrNull;
      },
    );
    if (!mounted) return;
    switch (action) {
      case SeriesAction.edit:
        final fresh = _series.where((s) => s.root == series.root).firstOrNull;
        await _open((fresh ?? series).latest);
      case SeriesAction.delete:
        await TaskRemover(_storage).remove(series.latest);
        await _changed();
      case null:
        break;
    }
  }

  /// After any change: refresh the list and start a sync.
  Future<void> _changed() async {
    await _reload();
    widget.sync.syncNow();
  }

  Future<void> _toggle(Task t) async {
    await _storage.save(t.copyWith(done: !t.done));
    await _reload();
    widget.sync.syncNow();
  }

  /// Opens a settings page, remembering it is open until it is closed.
  Future<void> _showSettingsPage(_SettingsPage page) async {
    _openPage.value = page;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => switch (page) {
          _SettingsPage.connection => PairingScreen(
            store: widget.pairingStore,
            addressStore: widget.addressStore,
            onShowBackgroundHelp: _openGuide,
          ),
          _SettingsPage.files => UploadsScreen(
            files: widget.files,
            sync: widget.sync,
          ),
          _SettingsPage.reminders => ReminderSettingsScreen(
            store: widget.goalStore,
            optionsStore: widget.reminderOptions,
            scheduler: widget.reminders,
            permissions: widget.reminderPermissions,
            onOptionsChanged: widget.onReminderOptionsChanged,
          ),
          _SettingsPage.timetables => FeedsScreen(
            feeds: widget.feeds!,
            sync: widget.sync,
          ),
        },
      ),
    );
    if (!mounted) return;
    _openPage.value = null;
    if (page == _SettingsPage.connection) {
      _refreshPaired();
      widget.sync.syncNow(); // maybe just paired
    }
  }

  Future<void> _openConnection() => _showSettingsPage(_SettingsPage.connection);

  /// The course a task belongs to (DeskPlan's, or its top-level folder).
  String? _courseOf(Task t) => CourseNames(_folders, _tree.listed).of(t);

  /// Everything the list shows (not steps), split by what the icon opened:
  /// tasks, assignments or notes, wherever they sit. Tasks and assignments
  /// come soonest deadline first, those without one last. Notes come newest
  /// edit first.
  List<Task> _itemsOf(_Section section) => switch (section) {
    _Section.tasks => _byDue(
      _tree.listed
          .where((t) => t.kind == TaskKind.task && !_inSeries(t))
          .toList(),
    ),
    _Section.assignments => _byDue(
      _tree.listed.where((t) => t.isAssignment).toList(),
    ),
    _Section.notes =>
      _tree.notes..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    _Section.calendar || _Section.settings => const [],
  };

  bool _inSeries(Task t) => _series.any((s) => s.contains(t.id));

  /// [items] soonest due first, then those without a due date, each keeping
  /// its place among equals (Dart's sort isn't stable on its own).
  static List<Task> _byDue(List<Task> items) {
    final place = {for (var i = 0; i < items.length; i++) items[i]: i};
    return items..sort((a, b) {
      final ae = a.end, be = b.end;
      if (ae != null && be != null) {
        final byDate = ae.compareTo(be);
        if (byDate != 0) return byDate;
      } else if (ae != null) {
        return -1;
      } else if (be != null) {
        return 1;
      }
      return place[a]!.compareTo(place[b]!);
    });
  }

  /// What the pill says while a pull-down sync runs.
  String get _syncLabel => 'Syncing with ${_pcName ?? 'DeskPlan'}…';

  /// Pull down to sync. The list must always be scrollable (even when empty
  /// or short) or the pull gesture does nothing.
  Widget _taskList(_Section section) {
    final items = _itemsOf(section);
    return SyncRefresh(
      onRefresh: () => widget.sync.syncNow(freshFeeds: true),
      label: _syncLabel,
      child: items.isEmpty && (section != _Section.tasks || _series.isEmpty)
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 160),
                Center(
                  child: Text(switch (section) {
                    _Section.tasks => 'No tasks yet. Tap +',
                    _Section.assignments => 'No assignments yet. Tap +',
                    _ => 'No notes yet. Tap +',
                  }, style: TextStyle(color: DeskPlanColors.of(context).muted)),
                ),
              ],
            )
          : section == _Section.notes
          ? ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              // A little air above the first row, and room below the last so
              // the floating buttons never cover it.
              padding: const EdgeInsets.only(top: 10, bottom: 170),
              itemCount: items.length,
              itemBuilder: (_, i) => NoteTile(
                note: items[i],
                place: _notePlaces.placeOf(items[i].parentId),
                onTap: () => _openNote(items[i]),
              ),
            )
          : _withDoneFolded(section, items),
    );
  }

  /// The groups that are folded shut. Done, Submitted and Overdue all start
  /// shut.
  final _folded = <String>{
    'done-tasks',
    'done-assignments',
    'overdue-tasks',
    'overdue-assignments',
  };

  /// A heading that folds the [items] under it open and shut.
  List<Widget> _foldable(
    String key,
    String label,
    List<Task> items, {
    Color? color,
    bool showDay = false,
  }) {
    final open = !_folded.contains(key);
    return [
      SectionHeader(
        label: label,
        count: items.length,
        color: color,
        open: open,
        onToggle: () => setState(() {
          if (!_folded.remove(key)) _folded.add(key);
        }),
      ),
      if (open)
        for (final t in items) _taskTile(t, showDay: showDay),
    ];
  }

  /// Done tasks and submitted assignments fold away at the top, shut by
  /// default, so they are easy to find without scrolling past every open
  /// item; Repeating comes next. Open tasks follow under Overdue (it folds too, also shut)
  /// and a heading per day; open assignments follow as they are. Folded
  /// items are only out of sight: nothing is deleted (deleting would delete
  /// them on the PC too).
  Widget _withDoneFolded(_Section section, List<Task> items) {
    final c = DeskPlanColors.of(context);
    final now = DateTime.now();
    final open = items.where((t) => !t.done).toList();
    final done = items.where((t) => t.done).toList();
    final isTasks = section == _Section.tasks;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 170),
      children: [
        if (done.isNotEmpty)
          ..._foldable(
            'done-${section.name}',
            isTasks ? 'DONE' : 'SUBMITTED',
            done,
            showDay: true,
          ),
        if (isTasks && _series.isNotEmpty) ...[
          // Folds like Done and Overdue, but starts open.
          SectionHeader(
            label: 'REPEATING',
            count: _series.length,
            open: !_folded.contains('repeating'),
            onToggle: () => setState(() {
              if (!_folded.remove('repeating')) _folded.add('repeating');
            }),
          ),
          if (!_folded.contains('repeating'))
            for (final s in _series)
              SeriesCard(
                series: s,
                now: now,
                onTap: () => _openSeries(s),
                onToggleDone: () => _toggle(s.latest),
              ),
        ],
        if (isTasks)
          for (final group in TaskGroups.of(open, now))
            ...switch (group.kind) {
              TaskGroupKind.overdue => _foldable(
                'overdue-tasks',
                'OVERDUE',
                group.tasks,
                color: c.danger,
                showDay: true,
              ),
              TaskGroupKind.day || TaskGroupKind.noDate => [
                SectionHeader(
                  label: group.day == null
                      ? 'NO DATE'
                      : DateText.dayHeading(context, group.day!, now),
                  count: group.tasks.length,
                ),
                for (final t in group.tasks) _taskTile(t),
              ],
            },
        if (open.isEmpty && (!isTasks || _series.isEmpty))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              section == _Section.assignments
                  ? 'Nothing left to submit'
                  : 'Nothing left to do',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted),
            ),
          ),
        if (!isTasks) ..._assignmentGroups(open, now),
      ],
    );
  }

  /// Open assignments: Overdue (red, folds, shut by default), then the rest
  /// under Upcoming, already soonest due first.
  List<Widget> _assignmentGroups(List<Task> open, DateTime now) {
    final overdue = [
      for (final a in open)
        if (a.end?.isBefore(now) ?? false) a,
    ];
    final upcoming = [
      for (final a in open)
        if (!overdue.contains(a)) a,
    ];
    return [
      if (overdue.isNotEmpty)
        ..._foldable(
          'overdue-assignments',
          'OVERDUE',
          overdue,
          color: DeskPlanColors.of(context).danger,
        ),
      if (upcoming.isNotEmpty) ...[
        SectionHeader(label: 'UPCOMING', count: upcoming.length),
        for (final a in upcoming) _taskTile(a),
      ],
    ];
  }

  Widget _taskTile(Task t, {bool showDay = false}) => t.isAssignment
      ? AssignmentCard(
          task: t,
          now: DateTime.now(),
          course: _courseOf(t),
          progress: _tree.progressOf(t.id),
          onTap: () => _open(t),
        )
      : TaskTile(
          task: t,
          now: DateTime.now(),
          course: _courseOf(t),
          showDay: showDay,
          onTap: () => _open(t),
          onToggleDone: () => _toggle(t),
        );

  /// The calendar: the phone's items with an end (steps too), plus
  /// DeskPlan's events while it has calendar feeds.
  Widget _calendar() {
    final courses = CourseNames(_folders, [..._tree.listed, ..._steps]);
    final entries = [
      ...CalendarEntry.ofItems([..._tree.listed, ..._steps], _tree, courses),
      // The occurrences still to come, up to half a year ahead.
      for (final s in _series)
        ...CalendarEntry.ofSeries(
          s,
          courses,
          horizon: DateTime.now().add(const Duration(days: 183)),
        ),
      if (_calendarOn) ..._events.map(CalendarEntry.ofEvent),
    ];
    return CalendarView(
      entries: entries,
      asOf: _calendarOn ? _eventsAsOf : null,
      onRefresh: () => widget.sync.syncNow(freshFeeds: true),
      syncLabel: _syncLabel,
      onOpenTask: _openFromCalendar,
    );
  }

  /// Every step of every assignment.
  List<Task> get _steps => [
    for (final a in _tree.listed.where((t) => t.isAssignment))
      ..._tree.stepsOf(a.id),
  ];

  /// A step opens its assignment, with its steps, as in the lists; an
  /// occurrence of a repeating task opens its series.
  /// [clashes] say how it sits against the day's other blocks.
  Future<void> _openFromCalendar(
    Task t, [
    List<(String, bool)> clashes = const [],
  ]) async {
    final series = _series.where((s) => s.contains(t.id)).firstOrNull;
    if (series != null) return _openSeries(series, clashes);
    if (_tree.isStep(t)) {
      final holder = _tree.listed.where((a) => a.id == t.parentId);
      if (holder.isNotEmpty) {
        return _open(holder.first, TaskKind.task, clashes);
      }
    }
    return _open(t, TaskKind.task, clashes);
  }

  /// Notes while DeskPlan does not sync them: say why there are none.
  Widget _notesOff() {
    final c = DeskPlanColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sticky_note_2_outlined, size: 40, color: c.faint),
            const SizedBox(height: 12),
            Text(
              'Notes sync once your DeskPlan shares them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'Update DeskPlan on your PC, then pull down to sync.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: c.faint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settings() => SettingsTab(
    light: _light,
    pcName: _pcName,
    waiting: _waiting,
    lastSynced: _reached ? _lastSynced : null,
    onConnection: _openConnection,
    onFiles: () => _showSettingsPage(_SettingsPage.files),
    onReminders: () => _showSettingsPage(_SettingsPage.reminders),
    onTimetables: widget.feeds == null
        ? null
        : () => _showSettingsPage(_SettingsPage.timetables),
  );

  Widget _page(_Section section) => switch (section) {
    _Section.calendar => _calendar(),
    _Section.settings => _settings(),
    _Section.notes when !_notesOn => SyncRefresh(
      onRefresh: () => widget.sync.syncNow(freshFeeds: true),
      label: _syncLabel,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: box.maxHeight, child: _notesOff()),
        ),
      ),
    ),
    _ => _taskList(section),
  };

  /// "+" shows where something can be added: not in Settings, and not in
  /// Notes while DeskPlan does not sync them.
  bool get _canAdd =>
      _section != _Section.settings &&
      !(_section == _Section.notes && !_notesOn);

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final section = _section;
    return PopScope(
      // Back from another tab goes to the calendar, then out of the app.
      canPop: section == _Section.calendar,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _section = _Section.calendar);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(section.label),
          actions: [
            ConnectionIconButton(light: _light, onPressed: _openConnection),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            if (_blockedReason != null)
              ConnectionBanner(
                cause: _blockedCause ?? UnreachableCause.other,
                message: _blockedReason!,
                waiting: _waiting,
                onPair: _openConnection,
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: KeyedSubtree(
                  key: ValueKey(section),
                  child: _page(section),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _canAdd
            ? FloatingActionButton(
                heroTag: 'add',
                tooltip: 'Add',
                elevation: 4,
                onPressed: _add,
                child: const Icon(Icons.add),
              )
            : null,
        // Icons only: the page title says where you are.
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: NavigationBar(
            height: 62,
            backgroundColor: c.frame,
            surfaceTintColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            indicatorShape: const CircleBorder(),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            selectedIndex: section.index,
            onDestinationSelected: (i) =>
                setState(() => _section = _Section.values[i]),
            destinations: [
              for (final s in _Section.values)
                NavigationDestination(
                  icon: Icon(s.icon, color: c.muted),
                  selectedIcon: Icon(s.icon, color: c.accent),
                  label: s.label,
                  tooltip: s.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
