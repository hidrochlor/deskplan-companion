import 'package:flutter/material.dart';

import '../../core/task.dart';
import '../../features/calendar/calendar_event.dart';
import '../../features/calendar/exam_dates.dart';
import '../date_text.dart';
import '../sync_refresh.dart';
import '../theme/deskplan_colors.dart';
import 'agenda_filter.dart';
import 'calendar_entry.dart';
import 'calendar_entry_row.dart';
import 'event_details_sheet.dart';
import 'month_grid.dart';
import 'step_group_row.dart';

/// How the calendar is laid out.
enum CalendarMode { month, agenda }

/// The calendar tab: a month view (pick a day to see what is on it) and an
/// agenda (everything from today on, day by day). It combines the phone's
/// own items with DeskPlan's feed events. Tapping an item opens it as
/// elsewhere; tapping an event shows its details, read-only. Pull down to
/// sync.
class CalendarView extends StatefulWidget {
  final List<CalendarEntry> entries;

  /// When DeskPlan built the cached events ("Timetable as of ..."), or null
  /// when none have been fetched yet.
  final DateTime? asOf;

  /// Opens the phone's item, with what it overlaps that day to show at the
  /// top of its sheet.
  final void Function(Task task, List<String> clashes) onOpenTask;
  final Future<void> Function() onRefresh;

  /// What the pill says while a pull-down sync runs.
  final String syncLabel;

  /// The exam dates and which one is registered for, for an exam's sheet.
  final ExamDates exams;

  /// Marks an exam date as the one registered for (or not).
  final Future<void> Function(CalendarEvent event, bool registered)? onRegister;

  /// For tests: the moment taken as now.
  final DateTime Function() now;

  const CalendarView({
    super.key,
    required this.entries,
    required this.asOf,
    required this.onOpenTask,
    required this.onRefresh,
    this.syncLabel = 'Syncing with DeskPlan…',
    this.exams = ExamDates.none,
    this.onRegister,
    this.now = DateTime.now,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  CalendarMode _mode = CalendarMode.month;
  late DateTime _month;
  late DateTime _selected;

  /// Unfolded step groups, by day and assignment id. Folded by default.
  final _open = <String>{};

  /// What the agenda is narrowed to; empty shows everything.
  final _filters = <AgendaFilter>{};

  @override
  void initState() {
    super.initState();
    final today = _today;
    _month = DateTime(today.year, today.month);
    _selected = today;
  }

  DateTime get _today {
    final n = widget.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Everything on [day], steps included (for clashes).
  List<CalendarEntry> _on(DateTime day) =>
      widget.entries.where((e) => e.isOn(day)).toList()
        ..sort(CalendarEntry.compare);

  /// Every assignment's steps, by assignment id, soonest first. A step
  /// lives inside its assignment's row (an assignment always has a due
  /// date, so it is always on the calendar): it gets no row or dot of its
  /// own.
  Map<String, List<CalendarEntry>> get _stepsOf {
    final out = <String, List<CalendarEntry>>{};
    for (final e in widget.entries) {
      if (e.parentId case final id?) (out[id] ??= []).add(e);
    }
    for (final steps in out.values) {
      steps.sort(CalendarEntry.compare);
    }
    return out;
  }

  /// True when [e] gets a row (and a dot) of its own: anything but a step.
  static bool _listed(CalendarEntry e) => e.parentId == null;

  void _openEntry(CalendarEntry e, List<String> clashes) {
    final event = e.event;
    if (event != null) {
      EventDetailsSheet.show(
        context,
        event,
        clashes: clashes,
        all: [
          for (final x in widget.entries)
            if (x.event != null) x.event!,
        ],
        exams: widget.exams,
        onRegister: widget.onRegister,
      );
    } else {
      // A step opens its assignment: say which step each line is about.
      widget.onOpenTask(e.task!, [
        for (final text in clashes)
          e.parentId == null ? text : '${e.title}: $text',
      ]);
    }
  }

  void _shiftMonth(int by) => setState(() {
    _month = DateTime(_month.year, _month.month + by);
    // Keep a day of the shown month selected.
    _selected = MonthGrid.sameDay(_month, DateTime(_today.year, _today.month))
        ? _today
        : _month;
  });

  void _goToday() => setState(() {
    _month = DateTime(_today.year, _today.month);
    _selected = _today;
  });

  /// "Today", "Tomorrow", or "Mon, Nov 3".
  String _dayTitle(DateTime day) {
    final loc = MaterialLocalizations.of(context);
    final diff = DateUtils.dateOnly(day).difference(_today).inDays;
    final text = loc.formatMediumDate(day);
    if (diff == 0) return 'Today · $text';
    if (diff == 1) return 'Tomorrow · $text';
    if (diff == -1) return 'Yesterday · $text';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    // The pull handler wraps the whole page, so its pill comes down from
    // the top edge over Month / Agenda, as on the other pages. Only the
    // list below scrolls, so only it starts a pull.
    return SyncRefresh(
      onRefresh: widget.onRefresh,
      label: widget.syncLabel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<CalendarMode>(
                segments: const [
                  ButtonSegment(
                    value: CalendarMode.month,
                    icon: Icon(Icons.calendar_view_month_outlined, size: 18),
                    label: Text('Month'),
                  ),
                  ButtonSegment(
                    value: CalendarMode.agenda,
                    icon: Icon(Icons.view_agenda_outlined, size: 18),
                    label: Text('Agenda'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
          ),
          Expanded(
            child: _mode == CalendarMode.month ? _monthView() : _agenda(),
          ),
        ],
      ),
    );
  }

  Widget _asOfLine() {
    final asOf = widget.asOf;
    if (asOf == null) return const SizedBox.shrink();
    final c = DeskPlanColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 13, color: c.faint),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Timetable as of ${DateText.when(context, asOf)}',
              style: TextStyle(fontSize: 11.5, color: c.faint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final c = DeskPlanColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: c.muted,
        ),
      ),
    );
  }

  Widget _empty(String text) {
    final c = DeskPlanColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(text, style: TextStyle(fontSize: 13, color: c.faint)),
    );
  }

  /// The day's rows. An assignment's steps live inside its row, all of
  /// them, whatever day they are on (unfold it to see them). Clashes are
  /// worked out against [all] of the day's entries (when only some are
  /// shown, a task still says it overlaps a hidden lecture), and for a step
  /// against its own day.
  List<Widget> _rows(
    DateTime day,
    List<CalendarEntry> entries, {
    List<CalendarEntry>? all,
  }) {
    final now = widget.now();
    final everything = all ?? entries;
    final stepsOf = _stepsOf;

    /// What [e] overlaps on its own day (a step may be on another).
    List<String> relationsOf(CalendarEntry e) => e.relationsIn(
      e.isOn(day) ? everything : _on(DateUtils.dateOnly(e.start.toLocal())),
      now,
    );

    Widget row(CalendarEntry e, {bool nested = false}) {
      final relations = relationsOf(e);
      return CalendarEntryRow(
        entry: e,
        day: day,
        now: now,
        nested: nested,
        relations: relations,
        onTap: () => _openEntry(e, relations),
      );
    }

    final out = <Widget>[];
    for (final e in entries) {
      final steps = e.event == null && e.task!.isAssignment
          ? stepsOf[e.task!.id]
          : null;
      if (steps == null) {
        out.add(row(e));
        continue;
      }
      final key = '${day.toIso8601String()}|${e.task!.id}';
      final isOpen = _open.contains(key);
      out.add(
        StepGroupRow(
          assignment: e,
          steps: steps,
          now: now,
          open: isOpen,
          clashes: steps.any((s) => relationsOf(s).isNotEmpty),
          onToggle: () =>
              setState(() => isOpen ? _open.remove(key) : _open.add(key)),
          onOpen: () => _openEntry(e, const []),
        ),
      );
      if (isOpen) out.addAll(steps.map((s) => row(s, nested: true)));
    }
    return out;
  }

  Widget _monthHeader() {
    final c = DeskPlanColors.of(context);
    final loc = MaterialLocalizations.of(context);
    final isThisMonth = MonthGrid.sameDay(
      _month,
      DateTime(_today.year, _today.month),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loc.formatMonthYear(_month),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
          if (!isThisMonth)
            TextButton(onPressed: _goToday, child: const Text('Today')),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: () => _shiftMonth(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            onPressed: () => _shiftMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _monthView() {
    final c = DeskPlanColors.of(context);
    final dayAll = _on(_selected);
    final dayEntries = dayAll.where(_listed).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _monthHeader(),
        // Swipe sideways to change the month.
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() < 200) return;
            _shiftMonth(v < 0 ? 1 : -1);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: MonthGrid(
              month: _month,
              selected: _selected,
              today: _today,
              dotsOf: (day) => [
                for (final e in _on(day))
                  if (_listed(e)) e.color,
              ],
              onSelect: (day) => setState(() => _selected = day),
            ),
          ),
        ),
        _sectionLabel(_dayTitle(_selected)),
        if (dayEntries.isEmpty)
          _empty('Nothing on this day')
        else
          ..._rows(_selected, dayEntries, all: dayAll),
        _asOfLine(),
      ],
    );
  }

  /// From today on, every day that has something, up to the last entry.
  Widget _agenda() {
    final today = _today;
    final days = <DateTime, List<CalendarEntry>>{};
    for (final e in widget.entries) {
      final end = e.end.toLocal();
      if (end.isBefore(today)) continue;
      var day = DateUtils.dateOnly(e.start.toLocal());
      if (day.isBefore(today)) day = today;
      final last = DateUtils.dateOnly(end);
      // A long entry is listed on each of its days (but not for ever).
      for (var i = 0; i < 62 && !day.isAfter(last); i++) {
        if (e.isOn(day)) (days[day] ??= []).add(e);
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }
    // Days with nothing left once filtered drop out.
    final shown = <DateTime, List<CalendarEntry>>{
      for (final MapEntry(key: day, value: list) in days.entries)
        if (list
                .where((e) => _listed(e) && AgendaFilter.shows(_filters, e))
                .toList()
            case final kept when kept.isNotEmpty)
          day: kept..sort(CalendarEntry.compare),
    };
    final ordered = shown.keys.toList()..sort();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _filterChips(),
        if (ordered.isEmpty) ...[
          _sectionLabel(_dayTitle(today)),
          _empty('Nothing coming up'),
        ],
        for (final day in ordered) ...[
          _sectionLabel(_dayTitle(day)),
          ..._rows(day, shown[day]!, all: days[day]!),
        ],
        _asOfLine(),
      ],
    );
  }

  /// Tasks, Assignments, Exams: tick any to see only those. None ticked
  /// shows everything.
  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          for (final f in AgendaFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.label),
                selected: _filters.contains(f),
                onSelected: (on) =>
                    setState(() => on ? _filters.add(f) : _filters.remove(f)),
              ),
            ),
        ],
      ),
    );
  }
}
