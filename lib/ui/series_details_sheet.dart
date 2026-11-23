import 'package:flutter/material.dart';

import 'clash_notice.dart';

import '../core/repeats.dart';
import '../core/task.dart';
import 'date_text.dart';
import 'theme/deskplan_colors.dart';

/// What the details sheet of a repeating task was closed with.
enum SeriesAction { edit, delete }

/// A repeating task as a whole, like a lecture's details: how it repeats,
/// its next occurrence, the ones coming after it and the earlier ones, each
/// done or missed (tick one here). The pen edits the series (its latest
/// copy, which the next ones are made from).
class SeriesDetailsSheet extends StatefulWidget {
  final TaskSeries series;

  /// Ticks an occurrence on or off, then answers the series as it is now
  /// (null when it is gone).
  final Future<TaskSeries?> Function(Task occurrence) onToggle;

  /// How it sits against the day's other blocks, when opened from the
  /// calendar.
  final List<String> clashes;

  const SeriesDetailsSheet({
    super.key,
    required this.series,
    required this.onToggle,
    this.clashes = const [],
  });

  /// Answers [SeriesAction.edit] or [SeriesAction.delete] when the sheet was
  /// closed to do that, null otherwise.
  static Future<SeriesAction?> show(
    BuildContext context,
    TaskSeries series, {
    required Future<TaskSeries?> Function(Task occurrence) onToggle,
    List<String> clashes = const [],
  }) => showModalBottomSheet<SeriesAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SeriesDetailsSheet(
      series: series,
      onToggle: onToggle,
      clashes: clashes,
    ),
  );

  @override
  State<SeriesDetailsSheet> createState() => _SeriesDetailsSheetState();
}

class _SeriesDetailsSheetState extends State<SeriesDetailsSheet> {
  late TaskSeries _series = widget.series;

  Future<void> _toggle(Task t) async {
    final fresh = await widget.onToggle(t);
    if (!mounted) return;
    if (fresh == null) {
      Navigator.pop(context);
    } else {
      setState(() => _series = fresh);
    }
  }

  Future<void> _confirmDelete() async {
    final count = _series.members.length;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${_series.latest.title}"?'),
        content: Text(
          count == 1
              ? 'It stops repeating and is deleted on DeskPlan too.'
              : 'It stops repeating, and all $count occurrences are deleted, '
                    'on DeskPlan too.',
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
    if (sure == true && mounted) Navigator.pop(context, SeriesAction.delete);
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final now = DateTime.now();
    final latest = _series.latest;
    final ended = _series.ended(now);
    final rule = latest.repeat;
    final next = ended || latest.done ? null : latest;
    final coming = ended ? const [] : _series.upcoming(max: 6);
    final earlier = [if (next == null) latest, ..._series.past];

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: c.muted,
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 20),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat_rounded, size: 12, color: c.accent),
                      const SizedBox(width: 4),
                      Text(
                        ended ? 'Ended' : 'Repeating',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () => Navigator.pop(context, SeriesAction.edit),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                latest.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
            ClashNotice(lines: widget.clashes),
            if (rule != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.event_repeat_outlined, size: 18, color: c.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateText.rule(context, rule),
                        style: TextStyle(fontSize: 14, color: c.text),
                      ),
                    ),
                  ],
                ),
              ),
            if (latest.details.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Text(
                  latest.details.trim(),
                  style: TextStyle(fontSize: 14, color: c.muted),
                ),
              ),
            if (next != null) ...[
              heading('NEXT'),
              _Occurrence(
                text: DateText.slot(context, next.start, next.end!),
                state: _State.next,
                onToggle: () => _toggle(next),
              ),
            ],
            if (coming.isNotEmpty) ...[
              heading('COMING UP'),
              for (final t in coming)
                _Occurrence(
                  text: DateText.slot(context, t.start, t.end),
                  state: _State.planned,
                ),
            ],
            if (earlier.isNotEmpty) ...[
              heading('EARLIER'),
              for (final t in earlier)
                if (t.end != null)
                  _Occurrence(
                    text: DateText.slot(context, t.start, t.end!),
                    // Missed once its time passed; to do while still ahead
                    // (unticked after a later one was done).
                    state: t.done
                        ? _State.done
                        : t.end!.isAfter(now)
                        ? _State.todo
                        : _State.missed,
                    onToggle: () => _toggle(t),
                  ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: c.danger),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete series'),
                onPressed: _confirmDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _State { next, planned, todo, done, missed }

/// One line of the timeline: a tick (or a dot for one not made yet), the
/// day and time, and Done or Missed for an earlier one.
class _Occurrence extends StatelessWidget {
  final String text;
  final _State state;
  final VoidCallback? onToggle;

  const _Occurrence({required this.text, required this.state, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final done = state == _State.done;
    final status = switch (state) {
      _State.done => 'Done',
      _State.missed => 'Missed',
      _State.todo => 'To do',
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 8),
      decoration: state == _State.next
          ? BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 40,
            child: onToggle == null
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.faint, width: 1.4),
                      ),
                    ),
                  )
                : Checkbox(
                    value: done,
                    shape: const CircleBorder(),
                    side: BorderSide(color: c.check, width: 1.6),
                    onChanged: (_) => onToggle!(),
                  ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: state == _State.next
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: switch (state) {
                  _State.next => c.text,
                  _State.planned => c.muted,
                  _ => done ? c.muted : c.text,
                },
              ),
            ),
          ),
          if (status != null)
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: done ? c.ok : c.faint,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
