import 'package:flutter/material.dart';

import '../features/reminders/goal_reminder.dart';
import '../features/reminders/goal_reminder_store.dart';
import '../features/reminders/reminder_options.dart';
import '../features/reminders/reminder_options_store.dart';
import '../features/reminders/reminder_permissions.dart';
import '../features/reminders/reminder_scheduler.dart';
import 'due_warning_timeline.dart';
import 'theme/deskplan_colors.dart';

/// When tasks and exams remind, the daily goal reminder, and the Android
/// settings that decide whether reminders arrive on time.
class ReminderSettingsScreen extends StatefulWidget {
  final GoalReminderStore store;
  final ReminderOptionsStore optionsStore;
  final ReminderScheduler scheduler;
  final ReminderPermissions permissions;

  /// Sets the task and exam reminders again after [optionsStore] changed.
  final Future<void> Function() onOptionsChanged;

  const ReminderSettingsScreen({
    super.key,
    required this.store,
    required this.optionsStore,
    required this.scheduler,
    required this.permissions,
    required this.onOptionsChanged,
  });

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen>
    with WidgetsBindingObserver {
  GoalReminder _goal = const GoalReminder();
  ReminderOptions _options = const ReminderOptions();
  final _text = TextEditingController();
  bool _loaded = false;
  bool _notifications = false;
  bool _exact = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  /// Back from Android's settings page: look at the permissions again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _load() async {
    final goal = await widget.store.load();
    final options = await widget.optionsStore.load();
    _text.text = goal.text;
    if (!mounted) return;
    setState(() {
      _goal = goal;
      _options = options;
      _loaded = true;
    });
    await _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notifications = await widget.permissions.notificationsAllowed();
    final exact = await widget.permissions.exactAlarmsAllowed();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _exact = exact;
      });
    }
  }

  /// Saves and applies the goal. Turning it on asks for permission first.
  /// The screen shows the change at once; a problem scheduling it is reported
  /// instead of leaving the switch looking stuck.
  Future<void> _update(GoalReminder goal) async {
    setState(() => _goal = goal);
    try {
      if (goal.enabled && !_notifications) {
        _notifications = await widget.permissions.requestNotifications();
      }
      await widget.store.save(goal);
      await widget.scheduler.setDailyGoal(goal);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set the reminder: $e')),
        );
      }
    }
    await _checkPermissions();
  }

  /// Saves the options and puts every task and exam reminder on the clock
  /// again to match them.
  Future<void> _updateOptions(ReminderOptions options) async {
    setState(() => _options = options);
    try {
      await widget.optionsStore.save(options);
      await widget.onOptionsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update the reminders: $e')),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _goal.hour, minute: _goal.minute),
    );
    if (t != null) {
      await _update(_goal.copyWith(hour: t.hour, minute: t.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reminders')),
        body: const SizedBox.shrink(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReminderCard(
            icon: Icons.alarm,
            title: 'Before a task starts or is due',
            subtitle:
                "Tap the times to remind at: before a task's From time, or "
                "an assignment's due time. Start and 'Due' always remind.",
            child: DueWarningTimeline(
              selected: _options.warnings,
              onToggle: (w) => _updateOptions(_options.toggled(w)),
            ),
          ),
          const SizedBox(height: 12),
          _ReminderCard(
            icon: Icons.school_outlined,
            title: 'Exams',
            subtitle: 'A day and an hour before each exam',
            value: _options.exams,
            onChanged: (v) => _updateOptions(_options.copyWith(exams: v)),
          ),
          const SizedBox(height: 12),
          _ReminderCard(
            icon: Icons.flag_outlined,
            title: 'Daily goal',
            subtitle: 'A reminder of your goal every day',
            value: _goal.enabled,
            onChanged: (v) => _update(_goal.copyWith(enabled: v)),
            child: Column(
              children: [
                // The time is always shown, so it is clear it can be set;
                // it is greyed out while the reminder is off.
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: _goal.enabled,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Time'),
                  subtitle: Text(
                    TimeOfDay(
                      hour: _goal.hour,
                      minute: _goal.minute,
                    ).format(context),
                  ),
                  onTap: _goal.enabled ? _pickTime : null,
                ),
                // "What is your goal today?" sits in the field as quiet text
                // and shrinks to a small label above it once it is tapped.
                TextField(
                  controller: _text,
                  enabled: _goal.enabled,
                  maxLength: 200,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: GoalReminder.defaultText,
                    counterText: '',
                  ),
                  onSubmitted: (v) => _update(_goal.copyWith(text: v)),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    if (_text.text != _goal.text) {
                      _update(_goal.copyWith(text: _text.text));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'So reminders arrive on time',
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
          ),
          _PermissionRow(
            title: 'Notifications',
            ok: _notifications,
            okText: 'Allowed',
            problemText: 'Blocked: no reminder can show',
            action: 'Allow',
            onAction: () async {
              await widget.permissions.requestNotifications();
              await _checkPermissions();
            },
          ),
          _PermissionRow(
            title: 'Alarms & reminders',
            ok: _exact,
            okText: 'Allowed: reminders arrive on the minute',
            problemText: 'Off: reminders may be a few minutes late',
            action: 'Open settings',
            onAction: widget.permissions.requestExactAlarms,
          ),
          _PermissionRow(
            title: 'Battery',
            ok: null,
            okText: '',
            problemText:
                'On some phones (Samsung especially) battery saving '
                'delays reminders. Set DeskPlan Companion to Unrestricted.',
            action: 'Open settings',
            onAction: widget.permissions.openBatterySettings,
          ),
        ],
      ),
    );
  }
}

/// One kind of reminder: an icon, a title and, when it can be switched off,
/// a switch in the header. [child] holds its settings underneath.
class _ReminderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final Widget? child;

  const _ReminderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    this.onChanged,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final on = value ?? true;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: on ? c.accentSoft : c.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: on ? c.accent : c.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                  ],
                ),
              ),
              if (value != null) Switch(value: value!, onChanged: onChanged),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.only(right: 4), child: child!),
          ],
        ],
      ),
    );
  }
}

/// One line: a title, a good or bad status, and a button to fix it.
/// [ok] null means "cannot be checked": the problem text is always shown.
class _PermissionRow extends StatelessWidget {
  final String title;
  final bool? ok;
  final String okText;
  final String problemText;
  final String action;
  final VoidCallback onAction;

  const _PermissionRow({
    required this.title,
    required this.ok,
    required this.okText,
    required this.problemText,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final good = ok == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        good ? Icons.check_circle_outline : Icons.warning_amber_rounded,
        color: good ? c.ok : (ok == null ? c.muted : c.warn),
      ),
      title: Text(title),
      subtitle: Text(good ? okText : problemText),
      trailing: good
          ? null
          : TextButton(onPressed: onAction, child: Text(action)),
    );
  }
}
