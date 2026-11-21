import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/connection/connection_light.dart';
import 'theme/deskplan_colors.dart';

/// The Settings tab: the connection to DeskPlan, files sent to the PC,
/// reminders, and timetables, each opening its own screen. Background sync is explained on
/// the connection screen.
class SettingsTab extends StatelessWidget {
  final ConnectionLight light;

  /// The PC's name, once it has been reached.
  final String? pcName;

  /// How many changes wait to be sent.
  final int waiting;

  /// When DeskPlan last answered, while it is connected.
  final DateTime? lastSynced;
  final VoidCallback onConnection;
  final VoidCallback onFiles;
  final VoidCallback onReminders;

  /// Opens Timetables and courses. Null hides the row.
  final VoidCallback? onTimetables;

  const SettingsTab({
    super.key,
    required this.light,
    required this.pcName,
    required this.waiting,
    this.lastSynced,
    required this.onConnection,
    required this.onFiles,
    required this.onReminders,
    this.onTimetables,
  });

  /// "synced just now", "synced 5 min ago", "synced 2 h ago".
  static String syncedText(DateTime at, DateTime now) {
    final minutes = now.difference(at).inMinutes;
    if (minutes < 1) return 'synced just now';
    if (minutes < 60) return 'synced $minutes min ago';
    return 'synced ${minutes ~/ 60} h ago';
  }

  Color _lightColor(DeskPlanColors c) => switch (light) {
    ConnectionLight.off => c.faint,
    ConnectionLight.idle => c.accent,
    ConnectionLight.connected => c.ok,
    ConnectionLight.attention => c.warn,
    ConnectionLight.problem => c.danger,
  };

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final synced = lastSynced;
    final status = [
      light.description,
      if (synced != null) syncedText(synced, DateTime.now()),
      if (waiting > 0)
        '$waiting ${waiting == 1 ? 'change' : 'changes'} waiting to sync',
    ].join(' · ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        // The connection, as a card of its own: it matters most.
        Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onConnection,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _lightColor(c).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.computer_outlined, color: _lightColor(c)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          light == ConnectionLight.off
                              ? 'Pair with DeskPlan'
                              : (pcName ?? 'DeskPlan'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _lightColor(c),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                status,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.faint),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _group(context, [
          _row(
            context,
            Icons.upload_file_outlined,
            'Files sent to your PC',
            'What is waiting, sent or refused',
            onFiles,
          ),
          _row(
            context,
            Icons.notifications_none,
            'Reminders',
            'Due times, exams and your daily goal',
            onReminders,
          ),
          if (onTimetables case final open?)
            _row(
              context,
              Icons.calendar_view_week_outlined,
              'Timetables and courses',
              'Add iCal links, show or hide courses',
              open,
            ),
        ]),
        const SizedBox(height: 24),
        Center(
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, info) => Text(
              info.hasData
                  ? 'DeskPlan Companion ${info.data!.version}'
                  : 'DeskPlan Companion',
              style: TextStyle(fontSize: 12, color: c.faint),
            ),
          ),
        ),
      ],
    );
  }

  /// Rows on one card, with thin dividers between them.
  Widget _group(BuildContext context, List<Widget> rows) {
    final c = DeskPlanColors.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: c.borderSoft),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final c = DeskPlanColors.of(context);
    return ListTile(
      leading: Icon(icon, color: c.muted),
      title: Text(title, style: TextStyle(fontSize: 14, color: c.text)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12.5, color: c.muted),
      ),
      trailing: Icon(Icons.chevron_right, color: c.faint),
      onTap: onTap,
    );
  }
}
