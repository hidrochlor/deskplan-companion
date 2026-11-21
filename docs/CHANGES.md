# DeskPlan <-> Companion: what to do next

`protocol.md` holds the rules and never lists to-dos. This file is the other half: the **difference** between the contract and what each app does today, as steps. Remove a step when it is done; add one when `protocol.md` changes. Never put a wire rule here: put it in `protocol.md` and link to its section.

## Status

| Part | State |
|---|---|
| PC: pairing, files to Received files or folders, items with `kind` / `parentId` / `description` / time blocks, the pull | Built, tested |
| PC: notes (protocol.md section 4 "Note text", ping `features`, pull `kinds`, the open note page taking a phone change) | Built, tested (`tests/note-sync.test.mjs`) |
| PC: calendar feeds (FH timetable, Moodle). Ping lists `calendar`; `GET /v1/calendar` (section 5); items carry `course` and `source`; imported assignments keep the feed's `end` (section 4 "Imported assignments"); the semester rule for `course` (section 4 "Assignments, steps and courses") | Built, tested (`tests/calendar-feeds.test.mjs`, `tests/phone-calendar.test.mjs`) |
| Phone: `course` and `source` (database version 7; shown from DeskPlan, the top-level folder only when the field is missing), imported assignments (source badge, due date read-only "Set by Moodle", the old `end` always sent, delete warning), the calendar (`GET /v1/calendar` on the pull's triggers while the ping lists `calendar`, the window replaced and kept offline with "Timetable as of", month view and agenda with the phone's items, the PC's colours, read-only events, exam notifications 1 day and 1 hour before, `404` hides the events, `503` retried at the next sync) | Built, tested (`test/course_test.dart`, `imported_assignment_test.dart`, `calendar_sync_test.dart`, `calendar_view_test.dart`) |
| Phone: pairing, the queue, sharing files to Received files or folders, discovery, automatic sync, items (tasks, assignments, steps) with push and pull, metadata | Built, tested |
| Phone: a bar of icons at the bottom, Calendar, Assignments, Tasks, Notes, Settings, each opening its own page (replaces the Home cards and "Due soon"; the Notes page says notes are not synced while the PC does not list `notes`; Settings holds the connection with background sync, files sent and reminders). DESIGN.md "Bottom bar", "Calendar page", "Settings page" | Built, tested |
| Phone: drafts until Save. Editing or moving a task, assignment or step, and the file name and destination in the share screen, change nothing until Save (or Queue); Cancel, Back or dismissing drops the draft | Built, tested (`test/task_sheet_test.dart`) |
| Phone: the time rules (protocol.md section 4 "Shapes"). A new task or step needs From and To, From earlier than To; a task keeps its start; an assignment is offered no start and never sends one; a time block shows as one range | Built, tested (`test/task_sheet_test.dart`) |
| Phone: notes (protocol.md sections 4 and 5, DESIGN.md "Note row" and "Note page"). See "Notes on the phone" below | Built, tested (`test/note_format_test.dart`, `notes_sync_test.dart`, `note_editor_test.dart`, `note_page_test.dart`) |
| Phone: "Received files" (the `received-files` destination, formerly `inbox`, shows the PC's label; "Received files" until the PC has been reached) | Built, tested (`test/ping_test.dart`) |
| Phone: reminder warnings as toggles (30 mins, 1 hr, 3 hrs, 5 hrs, 1 day before, any mix; the old single choice carries over), assignment and task cards countdown first, grouped under headings with Done / Submitted and Overdue folded shut, note cards with their folder path, progress counts (an assignment's steps, a note's checklist, on the cards and in the sheets) green once all are done, submitted or not, through one `Progress` value and `ProgressCount` widget (DESIGN.md "Due dates", "Note row", "Progress counts"), opening straight away (reminders are set again after the first frame) and coming back on the same tab and settings page after Android closed the app in the background | Built, tested (`test/reminders_test.dart`, `assignment_card_test.dart`, `task_groups_test.dart`) |
| PC and phone: repeating tasks and assignments (protocol.md section 4 "Repeating items"; ping lists `repeat`; the editor's Repeat choice; the next copy when ticked, with the id both make) | Built, tested (`tests/repeats.test.mjs`, `test/repeats_test.dart`) |
| PC and phone: the shared calendar feed list (protocol.md section 5 `/v1/feed-settings`; ping lists `feeds`). The PC keeps removal markers 90 days and lists the feeds again when the phone changes them. The phone downloads the feeds itself (its own iCal reader, checked against the PC's on the PC's sample feeds), hides courses in its database query, stops using `GET /v1/calendar` while the PC lists `feeds`, and has Settings › Timetables and courses (database version 10) | Built, tested (`tests/feed-settings-sync.test.mjs`, `test/feed_settings_sync_test.dart`, `test/ics_parser_test.dart`) |
| PC: a moved or cancelled occurrence of a repeating feed event (`RECURRENCE-ID`) | Built, tested (`tests/calendar-feeds.test.mjs`) |
| PC and phone: `course` on calendar events; the course timetable (the phone's "See all sessions"; on the PC, clicking a lecture or exam opens it in the right panel with its course's sessions) | Built, tested (`tests/phone-calendar.test.mjs`, `tests/course-sessions.test.mjs`, `test/course_timetable_test.dart`) |
| Phone: the Reminders page as cards with the timeline; "N changes waiting to sync" | Built, tested (`test/due_warning_timeline_test.dart`) |
| Phone on the real Samsung | **Not checked yet.** The only step left (below) |
| Phone on iOS | **Not started.** Needs a Mac (a cloud Mac) to build and an iPhone to test. The stages are in `IOS_PORT.md` (kept in the phone project only); stage 1 (Dart only, no Mac) can be done any time |

**Notes on the phone, as built.** A note is a third kind of `Task` (`TaskKind.note`) in the same table, with a `doc` column (database version 6), so it uses the same queue, push, pull and delete as tasks. `lib/features/notes/note_format.dart` is the Dart copy of `NoteFormat.js`, tested with the PC's cases. The ping's `features` is stored with the PC's details; notes are offered, sent (`run(syncNotes:)`) and pulled (`kinds=task,assignment,note`) only while it lists `notes`. Until then a note's save waits in the queue. The pull's place is kept together with the kinds it was read with, so the first pull with notes is a full one, and a full resync removes only items of the kinds asked for. On `kept-newer` with a different `doc` (compared as JSON values), the phone's text becomes a "(phone copy)" note (title kept within 500 characters) and is sent at the next sync. A note saves itself as it is written (the exception to drafts): it is written to the database after a 0.4 s pause in typing, a sync starts 2 s after the last change, and leaving the page writes and syncs at once. A new note that is left empty is not kept. Moving a note (Home, a folder, or an assignment the phone has) still waits for Save. The editor has the PC's line types, indent (up to 6, one level below the line above), ticking, bold / italic / strikethrough, links (put on selected words; "Open link" in the bar while the caret is in one), the "- ", "[] ", "[x] ", "# ", "## " shortcuts and the PC's Enter and Backspace rules; parts it cannot edit show read-only and are saved back unchanged. A newer version from the PC is shown after a sync unless something typed is still waiting to be written. A note over 1 MB is refused on the phone with "too big to sync" (nothing is sent) and the note page says so; the note stays on the phone.

## PC (DeskPlan)

Nothing is waiting on the PC side.

## Phone (Companion)

Done and removed from this list (see Status): `X-Device-Name`; refusing unsupported file types and turning shared links into `.url` files; one message per error code; regular sync; the folder picker for files; the look in `DESIGN.md`; the pull; assignments and steps; metadata (`createdAt`, `description`, folder); Home icons (since replaced by the bottom bar); drafts until Save; the time rules; notes; "Received files"; `course` and `source`; imported assignments; the calendar.

1. **Try it on the real Samsung over USB** with the checks under "Test on the real Samsung" below. Everything above is unit- and widget-tested only; checks 9 to 12 (the bottom bar, notes, calendar, reminders and resuming) and the time rules have never run on the phone.

## Phone: how to build it

**Goal.** Press Share in any app, choose DeskPlan Companion, check or edit the file name (the extension is locked), pick a destination (default Received files), tap Save. The queue sends by itself when the PC is reachable. Tasks, assignments and notes are created and edited in the app and sync the same way.

**Rules for the code.**
- OOP: one class per file, small classes, one job each, behind small interfaces (`Uploader`, `QueueRepository`, `Discovery`) so parts can be swapped or deleted. Suggested folders under `lib/`: `core/`, `features/share_intake/`, `features/queue/`, `features/discovery/`, `features/pairing/`, `features/upload/`, `ui/`.
- Add only needed packages, maintained ones. Do not edit unrelated files; small steps, run the tests after each. Explain unfamiliar terms in plain language in comments.

**What was built** (Android only): pairing, the queue, the share target, discovery, the pinned-certificate uploader with backoff, automatic sync with a first-run battery guide, the Files screen (Settings › Files sent to your PC), items (list, add, edit, tick or submit, delete, push, pull) with the time rules and drafts until Save, notes (list, write with formatting, move, delete, push, pull), the calendar (DeskPlan's feeds with the phone's items, kept offline) and reminders (Settings › Reminders: warnings before the due time, exams 1 day and 1 hour before, a daily goal). Each part is defined by the section of `protocol.md` it follows.

**Test on the real Samsung over USB** (not the emulator), plus Flutter unit tests with a fake `Uploader` and `Discovery`:
1. Pair on home Wi-Fi; approve the phone on the PC.
2. Share a PDF and an image while DeskPlan runs: one into Received files, one into a folder, both with the edited names.
3. Wi-Fi off, share a file, Wi-Fi on: it sends without opening the app.
4. Receiving off on the PC: the file stays queued and the phone says why.
5. Share the same file twice: two entries, no duplicate from retries.
6. Share a 90 MB file and an over-limit file.
7. Revoke the phone on the PC: uploads stop with `401` and the phone says it is no longer paired.
8. Create, edit and delete a task, an assignment with steps and a time block, and check each on the PC. Pull a change made on the PC. A new task cannot be saved without From and To; an assignment shows no From; Cancel on an edit leaves the item as it was.
9. The bottom bar shows Calendar, Assignments, Tasks, Notes and Settings. Each opens only its own page; an assignment opens its sheet with its steps. While the PC does not sync notes, the Notes page says so.
10. Notes: make a note on the phone with a heading, bullets, a checklist and bold text, and check it on the PC. Edit it on the PC and pull. Edit it on both while offline, then sync: one note plus a "(phone copy)". A note with a table on the PC keeps the table after a phone edit. With the note open on the PC, edit it on the phone: the PC shows the change and does not write over it (while typing on the PC: a "(PC copy)" note appears and comes to the phone at the next pull).
11. Calendar: with the FH timetable and Moodle added on the PC, the phone's calendar shows this week's lectures, the exams and the Moodle assignments. Untick a course on the PC and pull: its lectures leave the phone. Wi-Fi off: the calendar still shows, with "as of". A Moodle assignment's due date can not be edited; its title can, and the PC shows the new title with the old due date.
12. Reminders: turn on 30 mins and 5 hrs only; an assignment due in 6 hours reminds 5 hours and 30 minutes before, and when due. Open Settings > Reminders, switch to another app, open several heavy apps, come back: the app opens on Reminders at once, not on the calendar after a pause.
13. Repeats: make a weekly task on the phone and tick it: next week's copy appears. Sync: the PC shows the two, not three. Tick a repeating assignment on the PC: the copy comes to the phone at the next pull.
14. Timetables: Wi-Fi off, add a second timetable link on the phone (a language course's group): its lectures appear from mobile data. Wi-Fi on and sync: the PC lists it and shows the lectures. Hide a course on the PC: after a sync it is hidden on the phone, and the other way round. Remove a feed on the phone: it goes on the PC too.
15. Tap a lecture, "See all sessions": the course's weekly slots and every date.

**Networks.** Home Wi-Fi is the main target. School or shared Wi-Fi may not work at all (many networks stop devices seeing each other, and Windows treats unfamiliar networks as Public and blocks incoming connections): do not try to bypass it, keep everything queued and show "Waiting for DeskPlan". The phone's own hotspot works anywhere; the laptop joins it (Windows may need that network set to Private).

## Open questions

- **Feed changes made on the phone with an older DeskPlan** (no `feeds` in the ping) stay "waiting to sync" until DeskPlan is updated; the phone shows them meanwhile. Fine for one person; say if they should be refused instead.

- **Plugins and Flutter's built-in Kotlin.** The build warns that `nsd` and `workmanager` (with `nsd_android`, `workmanager_android`) do not use it yet. As of 2026-10-31 all four are on their latest versions (`flutter pub outdated`), so there is nothing to upgrade; the warning comes from the plugins, not the app. Run `flutter pub outdated` again before each Flutter upgrade and take new versions of both. Before the Flutter version that makes it a build failure: if `nsd` has not moved, replace it with `multicast_dns` behind `ServiceFinder` (`lib/features/discovery/nsd_service_finder.dart` is the only file using it); finding the PC by name is a convenience, the QR hint and a typed address still work.
- **Double reminders.** Both apps remind about an item once it exists on both, exams included (the PC and the phone both remind 1 day and 1 hour before). A per-device "remind me on this device" switch is the suggestion; not decided yet.
- **Created time of an item made offline** is the time of its first `PUT`, not when it was tapped. An optional `createdAt` on creation could fix it; not built.
