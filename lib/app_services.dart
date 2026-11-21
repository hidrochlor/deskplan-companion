import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/app_database.dart';
import 'core/repeat_advancer.dart';
import 'core/repeating_task_repository.dart';
import 'core/task_repository.dart';
import 'core/task_storage.dart';
import 'features/background/background_guide_store.dart';
import 'features/background/background_sync.dart';
import 'features/background/workmanager_background_sync.dart';
import 'features/calendar/calendar_fetcher.dart';
import 'features/calendar/calendar_service.dart';
import 'features/calendar/calendar_store.dart';
import 'features/calendar/exam_reminders.dart';
import 'features/calendar/local_exam_reminders.dart';
import 'features/calendar/sqlite_calendar_store.dart';
import 'features/connection/connection_checker.dart';
import 'features/connection/deskplan_client.dart';
import 'features/connection/ping_service.dart';
import 'features/connection/prefs_pc_info_store.dart';
import 'features/discovery/composite_discovery.dart';
import 'features/discovery/hint_discovery.dart';
import 'features/discovery/mdns_discovery.dart';
import 'features/discovery/nsd_service_finder.dart';
import 'features/discovery/prefs_typed_address_store.dart';
import 'features/discovery/typed_address_discovery.dart';
import 'features/discovery/typed_address_store.dart';
import 'features/feeds/feed_fetcher.dart';
import 'features/feeds/feed_service.dart';
import 'features/feeds/feed_settings_sync.dart';
import 'features/feeds/feed_store.dart';
import 'features/files/app_local_file_store.dart';
import 'features/files/file_queuer.dart';
import 'features/files/file_services.dart';
import 'features/files/https_file_uploader.dart';
import 'features/files/sqlite_upload_queue.dart';
import 'features/files/system_file_picker.dart';
import 'features/files/upload_processor.dart';
import 'features/pairing/pairing_store.dart';
import 'features/pairing/secure_pairing_store.dart';
import 'features/pull/pull_applier.dart';
import 'features/pull/pull_service.dart';
import 'features/pull/prefs_pull_cursor_store.dart';
import 'features/pull/server_change_puller.dart';
import 'features/queue/queue_processor.dart';
import 'features/queue/queued_task_repository.dart';
import 'features/queue/sqlite_action_queue.dart';
import 'features/queue/sync_service.dart';
import 'features/reminders/goal_reminder_store.dart';
import 'features/reminders/local_notification_scheduler.dart';
import 'features/reminders/notification_action_entry.dart';
import 'features/reminders/notification_taps.dart';
import 'features/reminders/push_action.dart';
import 'features/reminders/reminder_options_store.dart';
import 'features/reminders/reminder_permissions.dart';
import 'features/reminders/reminding_task_repository.dart';
import 'features/share_intake/android_share_intake.dart';
import 'features/upload/android_device_name_provider.dart';
import 'features/upload/https_task_uploader.dart';

/// Builds every part of the app and wires them together, in one place. The
/// app builds it once at start; the background worker builds its own copy
/// (it runs in a separate isolate, with nothing shared) so both sync exactly
/// the same way.
class AppServices {
  final TaskRepository repository;
  final SqliteActionQueue queue;
  final SyncService sync;
  final PairingStore pairingStore;
  final TypedAddressStore addressStore;
  final FileServices files;
  final GoalReminderStore goalStore;
  final ReminderOptionsStore reminderOptions;
  final LocalNotificationScheduler reminders;
  final ReminderPermissions reminderPermissions;
  final BackgroundGuideStore guideStore;
  final BackgroundSync background;

  /// DeskPlan's calendar events kept on the phone (to show them offline).
  final CalendarStore calendar;

  /// The calendar feeds, shared with DeskPlan and downloaded by the phone.
  final FeedService feeds;

  /// Tapped notifications, for the screen to open what each is about.
  final NotificationTaps notificationTaps;

  final TaskStorage _tasks;
  final ExamReminders _examReminders;

  AppServices._({
    required this.repository,
    required this.queue,
    required this.sync,
    required this.pairingStore,
    required this.addressStore,
    required this.files,
    required this.goalStore,
    required this.reminderOptions,
    required this.reminders,
    required this.reminderPermissions,
    required this.guideStore,
    required this.background,
    required this.calendar,
    required this.feeds,
    required this.notificationTaps,
    required this._tasks,
    required this._examReminders,
  });

  /// [inBackground] is true inside the background worker: it must not
  /// schedule more background work from there.
  static Future<AppServices> create({bool inBackground = false}) async {
    final database = AppDatabase();
    final tasks = TaskStorage(database);
    final queue = SqliteActionQueue(database);
    final pairingStore = SecurePairingStore();
    final goalStore = GoalReminderStore();
    final reminderOptions = ReminderOptionsStore();

    final notifications = FlutterLocalNotificationsPlugin();
    final reminders = LocalNotificationScheduler(
      notifications,
      reminderOptions,
    );
    final notificationTaps = NotificationTaps();
    final examReminders = LocalExamReminders(notifications, reminderOptions);
    final calendar = SqliteCalendarStore(database);
    try {
      await reminders.init(
        taps: notificationTaps,
        onAction: notificationActionInBackground,
      );
    } catch (_) {
      // Reminders are a bonus: never stop the app from starting without them.
    }

    // Finding the PC (protocol.md section 3): mDNS, then the QR hint, then an
    // address typed by hand.
    final addressStore = PrefsTypedAddressStore();
    final client = DeskPlanClient(
      pairingStore,
      CompositeDiscovery([
        MdnsDiscovery(NsdServiceFinder()),
        HintDiscovery(),
        TypedAddressDiscovery(addressStore),
      ]),
      deviceName: AndroidDeviceNameProvider(),
    );
    final pcInfoStore = PrefsPcInfoStore();
    final checker = ConnectionChecker(PingService(client), pcInfoStore);
    final uploadQueue = SqliteUploadQueue(database);
    final fileStore = AppLocalFileStore();
    final BackgroundSync background = inBackground
        ? const NoBackgroundSync()
        : WorkmanagerBackgroundSync();

    // The sync works on the plain storage, so applying DeskPlan's version of
    // a task does not queue another save. It still gets the reminder wrapper,
    // so a task DeskPlan changed has its reminders fixed too.
    final plainWithReminders = RemindingTaskRepository(tasks, reminders);
    final feeds = FeedService(
      FeedStore(database, SecureFeedUrlStore()),
      calendar,
      HttpFeedFetcher(),
      reminders: examReminders,
    );
    // Screens get the repository that queues changes for DeskPlan, sets
    // reminders, and adds the next copy of a repeating item when it is
    // ticked off. The sync moves unticked repeating items on through it.
    final repository = RepeatingTaskRepository(
      RemindingTaskRepository(
        QueuedTaskRepository(database, tasks, queue),
        reminders,
      ),
    );
    final sync = SyncService(
      checker,
      QueueProcessor(
        queue: queue,
        repository: plainWithReminders,
        uploader: HttpsTaskUploader(client),
      ),
      UploadProcessor(
        queue: uploadQueue,
        uploader: HttpsFileUploader(client),
        files: fileStore,
      ),
      ServerChangePuller(
        PullService(client),
        PullApplier(plainWithReminders, queue),
        PrefsPullCursorStore(),
      ),
      background: background,
      calendar: ServerCalendarFetcher(
        CalendarService(client),
        calendar,
        examReminders,
      ),
      feeds: feeds,
      feedSync: FeedSettingsSync(client, feeds),
      advancer: RepeatAdvancer(repository),
    );

    return AppServices._(
      repository: repository,
      queue: queue,
      sync: sync,
      pairingStore: pairingStore,
      addressStore: addressStore,
      files: FileServices(
        queuer: FileQueuer(uploadQueue, fileStore),
        queue: uploadQueue,
        store: fileStore,
        pcInfoStore: pcInfoStore,
        checker: checker,
        intake: AndroidShareIntake(),
        picker: SystemFilePicker(),
      ),
      goalStore: goalStore,
      reminderOptions: reminderOptions,
      reminders: reminders,
      reminderPermissions: ReminderPermissions(notifications),
      guideStore: BackgroundGuideStore(),
      background: background,
      calendar: calendar,
      feeds: feeds,
      notificationTaps: notificationTaps,
      tasks: tasks,
      examReminders: examReminders,
    );
  }

  /// A reminder's button: pushes the item [id] back, through the screens'
  /// repository (so it is queued for DeskPlan and its reminders are set
  /// again). False when there is nothing to push (gone, done, repeating).
  Future<bool> pushItem(String id, PushAction action) async {
    final task = await repository.get(id);
    if (task == null || !PushAction.offeredFor(task)) return false;
    await repository.save(action.applyTo(task, DateTime.now()));
    return true;
  }

  /// Things to do each time the app opens, not in the background worker.
  Future<void> start() async {
    // Put every reminder back on the phone's clock. This covers a phone that
    // restarted, and a change of time zone.
    // Android 13+ shows no notification at all until the user allows it, and
    // nothing asked unless they opened Reminders. Ask once at start; Android
    // itself stops asking after the user says no twice.
    try {
      if (!await reminderPermissions.notificationsAllowed()) {
        await reminderPermissions.requestNotifications();
      }
    } catch (_) {}
    try {
      await applyReminderOptions();
      await reminders.setDailyGoal(await goalStore.load());
    } catch (_) {
      // Reminders are a bonus: never stop the app from opening because of them.
    }
    try {
      await background.start();
    } catch (_) {
      // Without background sync the app still syncs whenever it is open.
    }
  }

  /// Sets every task and exam reminder again from the saved options: at
  /// start, and after the options change in Reminders.
  Future<void> applyReminderOptions() async {
    await reminders.rescheduleAll(await _tasks.all());
    final events = await calendar.events();
    await _examReminders.replace(events, events);
  }
}
