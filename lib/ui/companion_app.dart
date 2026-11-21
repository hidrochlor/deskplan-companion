import 'package:flutter/material.dart';

import '../app_services.dart';
import 'share_host.dart';
import 'task_list_screen.dart';
import 'theme/app_theme.dart';

/// The root widget. Light or dark follows the phone's system setting.
class CompanionApp extends StatelessWidget {
  final AppServices services;

  const CompanionApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeskPlan Companion',
      debugShowCheckedModeBanner: false, // removes the red "debug" badge
      // Android may close the app while it is in the background. This lets
      // it come back on the same tab and page instead of the first one.
      restorationScopeId: 'app',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // Times everywhere on the 24-hour clock ("17:30"), whatever the
      // phone's setting: the cards, the sheets and the time pickers.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      home: ShareHost(
        files: services.files,
        sync: services.sync,
        child: TaskListScreen(
          repository: services.repository,
          queue: services.queue,
          sync: services.sync,
          pairingStore: services.pairingStore,
          addressStore: services.addressStore,
          files: services.files,
          goalStore: services.goalStore,
          reminderOptions: services.reminderOptions,
          onReminderOptionsChanged: services.applyReminderOptions,
          reminders: services.reminders,
          reminderPermissions: services.reminderPermissions,
          guideStore: services.guideStore,
          calendar: services.calendar,
          notificationTaps: services.notificationTaps,
          feeds: services.feeds,
        ),
      ),
    );
  }
}
