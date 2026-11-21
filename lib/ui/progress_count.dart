import 'package:flutter/material.dart';

import '../core/progress.dart';
import 'theme/deskplan_colors.dart';

/// A checklist icon and "1/3" (with an optional word after it: "1/3 steps
/// done"), turning `ok` green once everything is finished. Every list shows
/// progress with it, so the rule lives in one place.
class ProgressCount extends StatelessWidget {
  final Progress progress;

  /// Words after the count ("steps done"), if any.
  final String? suffix;

  /// The colour while not complete; `faint` when null.
  final Color? color;
  final double fontSize;

  const ProgressCount({
    super.key,
    required this.progress,
    this.suffix,
    this.color,
    this.fontSize = 11.5,
  });

  /// `ok` once [progress] is complete, [otherwise] until then. For screens
  /// that show progress in their own words ("3 of 3 steps done").
  static Color colorOf(DeskPlanColors c, Progress progress, Color otherwise) =>
      progress.isComplete ? c.ok : otherwise;

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final tone = colorOf(c, progress, color ?? c.faint);
    final text = suffix == null ? '$progress' : '$progress $suffix';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.checklist, size: fontSize + 2.5, color: tone),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              color: tone,
              fontWeight: progress.isComplete ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}
