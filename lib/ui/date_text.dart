import 'package:flutter/material.dart';

import '../core/repeat_rule.dart';

/// Short, readable dates for the screens: "Oct 29, 5:00 AM" this year, and
/// "Oct 29, 2027, 5:00 AM" for another year. Always in the phone's local time.
class DateText {
  static String when(BuildContext context, DateTime time) {
    final loc = MaterialLocalizations.of(context);
    final local = time.toLocal();
    final sameYear = local.year == DateTime.now().year;
    final day = sameYear
        ? loc.formatShortMonthDay(local)
        : loc.formatShortDate(local);
    return '$day, ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
  }

  /// A time block as one range: "Oct 29, 3:00 PM to 7:00 PM" on one day,
  /// "Oct 29, 3:00 PM to Oct 30, 9:00 AM" across days.
  static String range(BuildContext context, DateTime start, DateTime end) {
    final loc = MaterialLocalizations.of(context);
    final from = start.toLocal();
    final to = end.toLocal();
    final sameDay =
        from.year == to.year && from.month == to.month && from.day == to.day;
    final toText = sameDay
        ? loc.formatTimeOfDay(
            TimeOfDay.fromDateTime(to),
            alwaysUse24HourFormat: true,
          )
        : when(context, end);
    return '${when(context, start)} to $toText';
  }

  /// A day and time with the weekday: "Sat, Oct 31 · 2:14 AM", and the year
  /// added when it is not this year.
  static String dayAndTime(BuildContext context, DateTime time) {
    final loc = MaterialLocalizations.of(context);
    final local = time.toLocal();
    final year = local.year == DateTime.now().year ? '' : ' ${local.year}';
    final clock = loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: true,
    );
    return '${loc.formatMediumDate(local)}$year · $clock';
  }

  /// Two times of one day, the shared AM / PM written once: "2:10–2:30 AM".
  static String timeRange(BuildContext context, DateTime start, DateTime end) {
    final loc = MaterialLocalizations.of(context);
    var from = loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(start.toLocal()),
      alwaysUse24HourFormat: true,
    );
    final to = loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(end.toLocal()),
      alwaysUse24HourFormat: true,
    );
    final period = RegExp(r'\D+$').firstMatch(from)?.group(0) ?? '';
    if (period.trim().isNotEmpty && to.endsWith(period)) {
      from = from.substring(0, from.length - period.length);
    }
    return '$from–$to';
  }

  /// One occurrence of a repeating task: "Mon, Nov 9 · 4:00–5:30 PM", or
  /// "Mon, Nov 9 · 4:00 PM" for a due time. The year only when not this one.
  static String slot(BuildContext context, DateTime? start, DateTime end) {
    final sameDay =
        start != null && DateUtils.isSameDay(start.toLocal(), end.toLocal());
    if (start != null && !sameDay) return range(context, start, end);
    final loc = MaterialLocalizations.of(context);
    final local = (start ?? end).toLocal();
    final year = local.year == DateTime.now().year ? '' : ' ${local.year}';
    final clock = start == null
        ? loc.formatTimeOfDay(
            TimeOfDay.fromDateTime(local),
            alwaysUse24HourFormat: true,
          )
        : timeRange(context, start, end);
    return '${loc.formatMediumDate(local)}$year · $clock';
  }

  /// "Weekly", "Every 2 weeks until Feb 1".
  static String rule(BuildContext context, RepeatRule rule) {
    final until = rule.until;
    if (until == null) return rule.label;
    final loc = MaterialLocalizations.of(context);
    final local = until.toLocal();
    final day = local.year == DateTime.now().year
        ? loc.formatShortMonthDay(local)
        : loc.formatShortDate(local);
    return '${rule.label} until $day';
  }

  /// The heading of a day in the Tasks list: "TODAY", "TOMORROW · SUN, NOV
  /// 1", or "THU, NOV 5". [day] is local midnight.
  static String dayHeading(BuildContext context, DateTime day, DateTime now) {
    final loc = MaterialLocalizations.of(context);
    final today = DateTime(now.year, now.month, now.day);
    final year = day.year == now.year ? '' : ' ${day.year}';
    final date = '${loc.formatMediumDate(day)}$year'.toUpperCase();
    if (day == today) return 'TODAY';
    if (day == DateTime(today.year, today.month, today.day + 1)) {
      return 'TOMORROW · $date';
    }
    return date;
  }

  /// When a note was last edited: "today 9:38 AM", or the day ("Oct 29").
  static String edited(BuildContext context, DateTime time, DateTime now) {
    final loc = MaterialLocalizations.of(context);
    final local = time.toLocal();
    if (DateUtils.isSameDay(local, now)) {
      return 'today ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
    }
    return local.year == now.year
        ? loc.formatShortMonthDay(local)
        : loc.formatShortDate(local);
  }
}
