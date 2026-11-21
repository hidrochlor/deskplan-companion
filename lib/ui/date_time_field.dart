import 'package:flutter/material.dart';

import 'theme/deskplan_colors.dart';

/// A tappable row that picks a date, then a time. Shows local time.
/// `value` and `onChanged` use any DateTime; null means "not set".
class DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  /// False when a time is required (an assignment always has a due time).
  final bool canClear;

  /// A small boxed tile (label, date, time on their own lines) that fits
  /// half a row, for From and To side by side.
  final bool compact;

  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.canClear = true,
    this.compact = false,
  });

  Future<void> _pick(BuildContext context) async {
    final current = value?.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = value?.toLocal();
    final loc = MaterialLocalizations.of(context);
    if (compact) return _compact(context, local, loc);
    final text = local == null
        ? 'Not set'
        : '${loc.formatMediumDate(local)}  '
              '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(text),
      onTap: () => _pick(context),
      trailing: (local == null || !canClear)
          ? null
          : IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () => onChanged(null),
            ),
    );
  }

  Widget _compact(
    BuildContext context,
    DateTime? local,
    MaterialLocalizations loc,
  ) {
    final c = DeskPlanColors.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pick(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.borderSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
                    const SizedBox(height: 2),
                    Text(
                      local == null ? 'Not set' : loc.formatMediumDate(local),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (local != null)
                      Text(
                        loc.formatTimeOfDay(
                          TimeOfDay.fromDateTime(local),
                          alwaysUse24HourFormat: true,
                        ),
                        style: TextStyle(fontSize: 14, color: c.muted),
                      ),
                  ],
                ),
              ),
              if (local != null && canClear)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Clear',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onChanged(null),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
