# Porting DeskPlan Companion to iOS

## Why and when

What it takes to run the Companion on an iPhone. Written for the setup as of October 2026: **no Mac** (a cloud Mac would be used) and **no iPhone yet**. iOS apps can only be built on macOS, and the most important features (sharing from other apps, background sync, finding the PC on Wi-Fi, the camera) can only really be tested on a physical iPhone. So the port has three stages. Stage 1 is all Dart, done and tested on Windows. Stages 2 and 3 wait until there is an iPhone to test on.

About 85% of the app is plain Dart and already works on iOS unchanged: the database, the queue, sync, pull, notes, the calendar, the pinned-certificate HTTPS, all screens, the reminder planning. The work is in eight places that call Android directly.

## What is Android-only today

| Part | File(s) | iOS answer | Effort |
|---|---|---|---|
| Share sheet (receive files from other apps) | `android/.../MainActivity.kt`, `lib/features/share_intake/android_share_intake.dart` | A **Share Extension**: a second small app inside the app, written in Swift. It copies files into a folder shared with the main app (an App Group) and opens the app. | **Large**, the main job |
| File picker (+ → Files & photos) | `MainActivity.kt` `pickFiles`, `lib/features/files/system_file_picker.dart` | `UIDocumentPickerViewController` via a small Swift channel, or the `file_picker` package | Small |
| Background sync | `lib/features/background/workmanager_background_sync.dart`, `background_sync_entry.dart` | `workmanager` supports iOS through `BGTaskScheduler`, but iOS decides when it runs (maybe a few times a day, never on a schedule). Change the wording: "syncs when you open the app, and sometimes in the background". | Medium (setup, plus expectations) |
| Reminder permissions | `lib/features/reminders/reminder_permissions.dart` | iOS has notification permission only. No exact-alarm setting and no battery setting: hide those two rows. | Small |
| Exact vs inexact scheduling | `local_notification_scheduler.dart`, `lib/features/calendar/local_exam_reminders.dart` | Add `DarwinNotificationDetails` / `DarwinInitializationSettings`. **iOS keeps at most 64 pending notifications**, so the planner must keep only the soonest 64 across tasks, warnings, exams and the goal. | Medium |
| Device name | `lib/features/upload/android_device_name_provider.dart` | `DeviceInfoPlugin().iosInfo.name`. Since iOS 16 this returns "iPhone" unless the app gets a special entitlement, so fall back to the model name. | Small |
| Opening links in notes | `lib/ui/notes/note_editor.dart` (`android_intent_plus`) | `url_launcher`, which works on both | Small |
| Finding the PC (mDNS) | `nsd` package | `nsd` supports iOS. Needs `NSLocalNetworkUsageDescription` and `NSBonjourServices` in `Info.plist`; iOS asks the user "allow local network" the first time. | Small, config |

Other config: camera permission text for the QR scanner (`mobile_scanner`), the app icon set, the bundle id, and `flutter create --platforms=ios .` to add the `ios/` folder.

## Stage 1: make the Dart side platform-neutral (now, on Windows)

The app already has the right interfaces (`ShareIntake`, `FilePickerService`, `BackgroundSync`, `DeviceNameProvider`). This stage finishes the job so stage 2 only adds iOS classes and touches no existing logic.

1. **Platform choice in one place.** `AppServices.create` (`lib/app_services.dart`) picks the implementation per platform (`Platform.isIOS`), as it already does for `inBackground`. No screen checks the platform itself.
2. **Reminder permissions as an interface.** Split `ReminderPermissions` into an abstract class with `AndroidReminderPermissions` (today's code) and a later iOS one. Add `bool get hasExactAlarms` / `hasBatterySetting`, so `reminder_settings_screen.dart` shows only the rows that exist on that phone.
3. **Notification limit.** Add a cap to `ReminderPlanner` (`lib/features/reminders/reminder_planner.dart`): `rescheduleAll` keeps only the soonest N reminders. Android gets a high N, iOS 64 minus the exam and goal reminders. Unit-test it like the existing planner tests in `test/reminders_test.dart`.
4. **Shared notification details.** One place builds `NotificationDetails` with both `android:` and `iOS:` parts. `LocalNotificationScheduler` and `LocalExamReminders` stop asking for Android exact-alarm modes directly.
5. **Links via `url_launcher`** in `note_editor.dart`, replacing `android_intent_plus` there. The battery-settings intent stays Android-only.
6. **Device name:** add an `IosDeviceNameProvider` beside `AndroidDeviceNameProvider` (both behind the existing `DeviceNameProvider`), with the iOS fallback written and unit-tested now.

Everything in stage 1 runs with `flutter analyze` and `flutter test` on Windows, and the Android app behaves exactly as before.

## Stage 2: iOS project and native parts (needs a cloud Mac)

1. `flutter create --platforms=ios .`, bundle id, `Info.plist` texts (camera, local network, Bonjour service type from `protocol.md` section 3), background modes (fetch/processing) and the `BGTaskScheduler` id for `workmanager`.
2. `IosShareIntake` + a Swift **Share Extension**: accepts files, images, URLs and text; copies them into the App Group container; opens the app with a `deskplan://share` link. The Dart side reads the same `{type, path, name}` list that `AndroidShareIntake.parse` already reads, so it reuses that parser.
3. Native file picker (or `file_picker`) behind `FilePickerService`.
4. Codemagic (free tier: 500 macOS minutes a month) building from the GitHub repo: `flutter test`, then an iOS build. Without a paid Apple account it can only produce a Simulator build, not one that installs on a phone.

## Stage 3: on a real iPhone (needs an iPhone, ideally the $99/year account)

TestFlight install, then the same check list as "Test on the real Samsung" in `docs/CHANGES.md`, plus: the share extension from Files and Photos, the local-network prompt, reminders with more than 64 items, and background sync after a few hours closed.

## Files stage 1 changes

- `lib/app_services.dart`: platform choice
- `lib/features/reminders/reminder_permissions.dart`: becomes the interface, plus `android_reminder_permissions.dart`
- `lib/ui/reminder_settings_screen.dart`: shows only the rows that exist
- `lib/features/reminders/reminder_planner.dart`, `local_notification_scheduler.dart`, `lib/features/calendar/local_exam_reminders.dart`: the cap and shared details
- `lib/ui/notes/note_editor.dart`, `pubspec.yaml` (`url_launcher`)
- `lib/features/upload/`: device name per platform
- `docs/CHANGES.md`: the "Phone on iOS" row in Status says stage 1 is done, and stages 2 and 3 become steps under "Phone (Companion)"

## Verification

- Stage 1: `flutter analyze`, `flutter test`, including new tests for the 64 cap and the per-platform permission rows. Then `flutter run` on the Samsung: reminders, links in notes and settings work as before.
- Stage 2: Codemagic builds green and runs the tests on macOS.
- Stage 3: the check list above on an iPhone.

## Summary

- **Stage 1:** a few focused sessions, no cost, makes the code cleaner either way.
- **Stage 2:** mostly the Share Extension (Swift plus App Groups), slow to iterate without a Mac.
- **Stage 3:** can't be done without an iPhone. Background sync and sharing will feel different from Android because iOS limits them; that is iOS, not a bug.
