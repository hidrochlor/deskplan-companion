import 'package:flutter/material.dart';

import '../features/reminders/reminder_options.dart';
import 'theme/deskplan_colors.dart';

/// The warnings before a due time, drawn as stops on a line that runs from
/// "1 day" (left) to "Due" (right). Tapping a stop turns it on or off; "Due"
/// is always on and cannot be tapped.
class DueWarningTimeline extends StatelessWidget {
  final Set<DueWarning> selected;
  final ValueChanged<DueWarning> onToggle;

  const DueWarningTimeline({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  /// "Reminds 1 day and 1 hour before, and when it is due."
  static String summary(Set<DueWarning> on) {
    final names = [
      for (final w in DueWarning.values.reversed)
        if (on.contains(w)) _spoken(w),
    ];
    if (names.isEmpty) return 'Reminds only when it is due.';
    final list = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return 'Reminds $list before, and when it is due.';
  }

  static String _spoken(DueWarning w) => switch (w) {
    DueWarning.minutes30 => '30 minutes',
    DueWarning.hour1 => '1 hour',
    DueWarning.hours3 => '3 hours',
    DueWarning.hours5 => '5 hours',
    DueWarning.day1 => '1 day',
  };

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    // Longest first, so time runs left to right towards the due time.
    final stops = DueWarning.values.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
          child: Stack(
            children: [
              // The line, through the middle of the dots.
              Positioned(
                left: 24,
                right: 24,
                top: 23,
                child: Container(height: 2, color: c.border),
              ),
              Row(
                children: [
                  for (final w in stops)
                    Expanded(
                      child: _Stop(
                        label: w.label,
                        on: selected.contains(w),
                        onTap: () => onToggle(w),
                        semantics: '${_spoken(w)} before',
                      ),
                    ),
                  const Expanded(
                    child: _Stop(
                      label: 'Due',
                      on: true,
                      onTap: null,
                      semantics: 'When it is due, always on',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(summary(selected), style: TextStyle(fontSize: 13, color: c.muted)),
      ],
    );
  }
}

/// One stop: a dot on the line with its label underneath. [onTap] null is
/// the fixed "Due" stop.
class _Stop extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final String semantics;

  const _Stop({
    required this.label,
    required this.on,
    required this.onTap,
    required this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final fixed = onTap == null;
    final size = fixed ? 18.0 : 16.0;
    return Semantics(
      label: semantics,
      toggled: fixed ? null : on,
      button: !fixed,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          height: 72,
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? c.accent : c.bg,
                      border: Border.all(
                        color: on ? c.accent : c.borderHover,
                        width: 2,
                      ),
                      boxShadow: fixed
                          ? [BoxShadow(color: c.accentSoft, spreadRadius: 4)]
                          : null,
                    ),
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  color: on ? c.text : c.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
