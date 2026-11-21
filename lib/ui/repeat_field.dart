import 'package:flutter/material.dart';

import '../core/repeat_rule.dart';
import 'theme/deskplan_colors.dart';

/// "Repeat": Never, Daily, Weekly, Every 2 weeks or Monthly, and an optional
/// last day. A rule made elsewhere (every 3 days on the PC, say) is offered
/// as its own choice, so opening the sheet never loses it.
class RepeatField extends StatelessWidget {
  final RepeatRule? value;
  final ValueChanged<RepeatRule?> onChanged;

  /// False without a due time: there is nothing to repeat from.
  final bool enabled;

  const RepeatField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  static final _presets = <RepeatRule>[
    RepeatRule(RepeatEvery.day),
    RepeatRule(RepeatEvery.week),
    RepeatRule(RepeatEvery.week, interval: 2),
    RepeatRule(RepeatEvery.month),
  ];

  static const double _menuWidth = 240;

  static bool _same(RepeatRule a, RepeatRule b) =>
      a.every == b.every && a.interval == b.interval;

  Future<void> _pickUntil(BuildContext context, RepeatRule rule) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: rule.until?.toLocal() ?? now.add(const Duration(days: 90)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      helpText: 'Repeat until',
    );
    if (picked == null) return;
    // The whole day counts: a copy due that evening is still made.
    onChanged(
      rule.withUntil(DateTime(picked.year, picked.month, picked.day, 23, 59)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final current = value;
    final options = <RepeatRule?>[
      null,
      ..._presets,
      if (current != null && !_presets.any((p) => _same(p, current)))
        RepeatRule(current.every, interval: current.interval),
    ];
    int selected = 0;
    if (current != null) {
      selected = options.indexWhere((o) => o != null && _same(o, current));
    }
    final loc = MaterialLocalizations.of(context);
    final until = current?.until;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A small menu that opens under the field's right edge, not a
        // full-width list. No initialValue: Flutter would wash the current
        // item in its highlight colour; _RepeatOption marks it instead.
        LayoutBuilder(
          builder: (context, box) => PopupMenuButton<int>(
            enabled: enabled,
            position: PopupMenuPosition.under,
            offset: Offset(box.maxWidth - _menuWidth, 6),
            constraints: const BoxConstraints.tightFor(width: _menuWidth),
            color: c.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: c.borderSoft),
            ),
            menuPadding: const EdgeInsets.symmetric(vertical: 6),
            tooltip: '',
            onSelected: (i) {
              final o = options[i];
              onChanged(
                o == null
                    ? null
                    : RepeatRule(
                        o.every,
                        interval: o.interval,
                        until: current?.until,
                      ),
              );
            },
            itemBuilder: (_) => [
              for (var i = 0; i < options.length; i++)
                PopupMenuItem(
                  value: i,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _RepeatOption(
                    icon: _iconFor(options[i]),
                    label: options[i]?.label ?? 'Never',
                    selected: i == selected,
                  ),
                ),
            ],
            child: InputDecorator(
              isEmpty: false,
              decoration: InputDecoration(
                labelText: 'Repeat',
                enabled: enabled,
                prefixIcon: const Icon(Icons.repeat),
                suffixIcon: const Icon(Icons.unfold_more_rounded),
                helperText: !enabled
                    ? 'Set a due time first'
                    : current != null
                    ? 'When you tick it off, the next one is added'
                    : null,
              ),
              child: Text(
                options[selected]?.label ?? 'Never',
                style: enabled ? null : TextStyle(color: c.muted),
              ),
            ),
          ),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.event_busy_outlined, size: 18, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    until == null
                        ? 'No end date'
                        : 'Until ${loc.formatMediumDate(until.toLocal())}',
                    style: TextStyle(color: c.muted),
                  ),
                ),
                if (until != null)
                  TextButton(
                    onPressed: () => onChanged(current.withUntil(null)),
                    child: const Text('Clear'),
                  ),
                TextButton(
                  onPressed: () => _pickUntil(context, current),
                  child: Text(until == null ? 'Set end' : 'Change'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(RepeatRule? r) {
    if (r == null) return Icons.block_rounded;
    if (!_presets.any((p) => _same(p, r))) return Icons.tune_rounded;
    return switch (r.every) {
      RepeatEvery.day => Icons.today_rounded,
      RepeatEvery.week =>
        r.interval == 1 ? Icons.view_week_rounded : Icons.date_range_rounded,
      RepeatEvery.month => Icons.calendar_month_rounded,
    };
  }
}

/// One line of the repeat menu: a tinted icon, the label and a check on
/// the current choice.
class _RepeatOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _RepeatOption({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? c.accentSoft : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? c.accent : c.surface2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: selected ? c.onAccent : c.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? c.accent : c.text,
              ),
            ),
          ),
          if (selected) Icon(Icons.check_rounded, size: 18, color: c.accent),
        ],
      ),
    );
  }
}
