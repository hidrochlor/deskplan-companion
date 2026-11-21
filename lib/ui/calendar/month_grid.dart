import 'package:flutter/material.dart';

import '../theme/deskplan_colors.dart';

/// One month as a grid of days, weeks starting on the phone's first day of
/// the week. Each day shows up to three dots in the colours of what is on
/// it. Today is ringed in the accent; the selected day is filled with it.
class MonthGrid extends StatelessWidget {
  /// Any day in the month to show.
  final DateTime month;
  final DateTime selected;
  final DateTime today;

  /// The dot colours for a local day (at most three are drawn).
  final List<Color> Function(DateTime day) dotsOf;
  final ValueChanged<DateTime> onSelect;

  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.dotsOf,
    required this.onSelect,
  });

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final loc = MaterialLocalizations.of(context);
    final first = DateTime(month.year, month.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    // DateTime.weekday is 1 (Monday) to 7 (Sunday); firstDayOfWeekIndex is
    // 0 (Sunday) to 6.
    final lead = (first.weekday % 7 - loc.firstDayOfWeekIndex + 7) % 7;
    final cells = ((lead + days) / 7).ceil() * 7;
    final names = [
      for (var i = 0; i < 7; i++)
        loc.narrowWeekdays[(loc.firstDayOfWeekIndex + i) % 7],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final n in names)
                Expanded(
                  child: Center(
                    child: Text(
                      n,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.faint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < cells ~/ 7; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _cell(context, c, row * 7 + col - lead, days),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, DeskPlanColors c, int index, int days) {
    if (index < 0 || index >= days) return const SizedBox(height: 46);
    final day = DateTime(month.year, month.month, index + 1);
    final isSelected = sameDay(day, selected);
    final isToday = sameDay(day, today);
    final dots = dotsOf(day);
    return Semantics(
      selected: isSelected,
      button: true,
      label: MaterialLocalizations.of(context).formatFullDate(day),
      child: InkWell(
        key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelect(day),
        child: SizedBox(
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? c.accent : null,
                  border: isToday && !isSelected
                      ? Border.all(color: c.accent, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isSelected
                        ? c.onAccent
                        : isToday
                        ? c.accent
                        : c.text,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in dots.take(3))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
