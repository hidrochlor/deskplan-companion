import 'package:flutter/material.dart';

import 'theme/deskplan_colors.dart';

/// Explains how to stop the phone from putting the app to sleep, so that
/// tasks and files keep syncing when the app is closed. Shown once on first
/// use, and again from the connection screen.
class BackgroundGuideScreen extends StatelessWidget {
  /// Opens Android's battery settings for this app.
  final Future<void> Function() onOpenSettings;

  const BackgroundGuideScreen({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Keep syncing')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Sync when the app is closed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'DeskPlan Companion sends your tasks and files to your PC by '
            'itself when you are on Wi-Fi at home. To do that while the app '
            'is closed, the phone must not put it to sleep.',
            style: TextStyle(color: c.muted),
          ),
          const SizedBox(height: 20),
          _Step(
            number: 1,
            text:
                'Tap "Open battery settings" below and set DeskPlan '
                'Companion to Unrestricted (or "Don\'t optimise").',
          ),
          const _Step(
            number: 2,
            text:
                'On Samsung phones also add it to the never-sleeping list: '
                'Settings > Battery > Background usage limits > Never '
                'sleeping apps > Add DeskPlan Companion.',
          ),
          const SizedBox(height: 8),
          Text(
            'Without this, syncing still works whenever the app is open. '
            'Your reminders do not depend on it.',
            style: TextStyle(fontSize: 12.5, color: c.faint),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.battery_charging_full),
            label: const Text('Open battery settings'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// One numbered instruction.
class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: c.accentSoft,
            child: Text(
              '$number',
              style: TextStyle(fontSize: 12, color: c.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
