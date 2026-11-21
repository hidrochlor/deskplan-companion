import 'package:flutter/material.dart';

import '../../core/task.dart';
import '../date_text.dart';
import '../sync_refresh.dart';
import '../theme/deskplan_colors.dart';
import 'calendar_entry.dart';
import 'calendar_entry_row.dart';
import 'event_details_sheet.dart';
import 'month_grid.dart';

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
  final ValueChanged<Task> onOpenTask;
  final Future<void> Function() onRefresh;

  /// What the pill says while a pull-down sync runs.
  final String syncLabel;

  /// For tests: the moment taken as now.
  final DateTime Function() now;

  const CalendarView({
    super.key,
    required this.entries,
    required this.asOf,
    required this.onOpenTask,
    required this.onRefresh,
    this.syncLabel = 'Syncing with DeskPlan…',
    this.now = DateTime.now,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  CalendarMode _mode = CalendarMode.month;
  late DateTime _month;
  late DateTime _selected;

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

  List<CalendarEntry> _on(DateTime day) =>
      widget.entries.where((e) => e.isOn(day)).toList()
        ..sort(CalendarEntry.compare);

  void _open(CalendarEntry e) {
    final event = e.event;
    if (event != null) {
      EventDetailsSheet.show(
        context,
        event,
        all: [
          for (final x in widget.entries)
            if (x.event != null) x.event!,
        ],
      );
    } else {
      widget.onOpenTask(e.task!);
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
    return Column(
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
          child: SyncRefresh(
            onRefresh: widget.onRefresh,
            label: widget.syncLabel,
            child: _mode == CalendarMode.month ? _monthView() : _agenda(),
          ),
        ),
      ],
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

  List<Widget> _rows(DateTime day, List<CalendarEntry> entries) {
    final now = widget.now();
    return [
      for (final e in entries)
        CalendarEntryRow(entry: e, day: day, now: now, onTap: () => _open(e)),
    ];
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
    final dayEntries = _on(_selected);
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
              dotsOf: (day) => _on(day).map((e) => e.color).toList(),
              onSelect: (day) => setState(() => _selected = day),
            ),
          ),
        ),
        _sectionLabel(_dayTitle(_selected)),
        if (dayEntries.isEmpty)
          _empty('Nothing on this day')
        else
          ..._rows(_selected, dayEntries),
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
    final ordered = days.keys.toList()..sort();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (ordered.isEmpty) ...[
          _sectionLabel(_dayTitle(today)),
          _empty('Nothing coming up'),
        ],
        for (final day in ordered) ...[
          _sectionLabel(_dayTitle(day)),
          ..._rows(day, days[day]!..sort(CalendarEntry.compare)),
        ],
        _asOfLine(),
      ],
    );
  }
}
