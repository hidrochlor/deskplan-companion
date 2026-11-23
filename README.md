# DeskPlan Companion

Android app (Flutter) that queues tasks and shared files and syncs them to DeskPlan on the PC. Tasks, assignments with steps and notes can be read and changed on the phone, and DeskPlan's calendar is shown (read-only); reminders come from the phone.

## Screen

- Bottom: a bar of five icons, Calendar, Assignments, Tasks, Notes and Settings, each opening its own page. Back from
  any page goes to Calendar, then out of the app.
- Top: the page's name, and at the right the link icon with a dot: **green** connected, **blue** paired but the PC not
  reached, **amber** needs attention (for example waiting for approval on the PC), **red** pair again, **grey** not paired.
  Tap it for the connection. When the PC can't be reached, a small pill between the page's name and the icon says why
  and how many changes are waiting (tap it for the connection).
- **Calendar:** Month or Agenda. Month shows a grid with coloured dots on the days that have something (the chosen day
  filled) and that day's list below; Agenda lists every day from today on. Agenda can be narrowed to Tasks, Assignments and/or
  Exams (a step counts as its assignment). An assignment's steps live inside its row on the day it is due, never on their own
  days (tap the row to open it, the chevron to see every step, with its date when it is on another day). Your tasks and assignments sit next to
  DeskPlan's timetable (lectures, exams, events). Each entry has a coloured bar, the time, and what it is
  (`Lecture · VO · WS46a 02.212 · <lecturer>`, `Assignment · Digital Signal Processing`). Timetable entries are
  read-only (a small lock). Anything whose time has passed is dimmed; an item of yours that ended without being done
  says `Missed` in red (`Task · WS 2026 · Missed`). A grey circled "!" marks a clash; the sheet says by how much
  (`Starts 15m before Lecture ends`, `Ends 15m after Lab starts`).
  The timetable lists every sitting of an exam (it is the group's feed, so it can't say which one you registered for):
  each is numbered (`Exam · Date 2 of 3 · …`), and an exam's sheet has **Registered for this date**. Once one is
  marked (kept on this phone only) it says `Registered` in green, and the other dates are dimmed, with no clash and no
  reminder.
- **Assignments:** cards under SUBMITTED (latest first), OVERDUE and UPCOMING (the first two folded shut). Each card: the countdown
  (`Due in 5h 7m`, amber within a day, red when overdue), the due day and time, the title, the course, the steps done
  (`No steps yet`, `1/3`) and a `Moodle` pill for imported ones. Tap one for its sheet: steps (tick, edit, add) and Submit.
- **Tasks:** cards under DONE (latest first) and OVERDUE (folded shut), then each day (`THU, NOV 5`), then NO DATE. Each card: a circle
  to tick it, the title, the time (`10:59–11:59 PM`), the course, and how long until it needs you (`In 5d`).
- **Notes:** cards with the folder they sit in (`python basics › Learn Basics`), the title, two lines of text, when it was
  last edited and, with a checklist, how many are ticked (`4/4`). Tap one to write in it; it saves as you type. While the
  PC doesn't sync notes, the page says so.
- **Settings:** the PC card (`DESKTOP-… · Connected to DeskPlan · synced just now`; tap for pairing and background sync),
  **Files sent to your PC** (waiting, sent or refused, with Retry) and **Reminders** (warnings before due times, exams,
  a daily goal).
- **+** (every page but Settings; on Notes only while the PC syncs notes): add a Task, an Assignment, a Note, or
  Files & photos to send to the PC.
- Pull down on a page to sync now. Editing a task or assignment changes nothing until Save.

**From another app:** Share › DeskPlan Companion opens a small screen to check each file's name and pick where it goes
(Received files, or one of your folders on the PC), then Queue. It is sent when the PC can be reached.

The look (colours, sizes, cards) is in `docs/DESIGN.md`.

## Docs

In `docs/`:
- `protocol.md`: the contract with DeskPlan (pairing, endpoints, errors, item and note sync, the calendar). The same file DeskPlan on the PC keeps.
- `DESIGN.md`: the look (colours, shapes, icons, cards, the phone's pages, Flutter theme). Shared with the PC as well.
- `CHANGES.md`: what each app does today against the contract, what is left to do, and the checks to run on a real phone.
- `DIFFERENCES.md`: where the phone and the PC behave or look differently (exam marks, clash warnings, the order of done
  items...), and what bringing each in line would take. The same file DeskPlan on the PC keeps.
- `IOS_PORT.md`: what porting to iOS takes, in three stages. Not started.

Run: `flutter pub get` then `flutter run` (Android device; iOS is not set up, see `IOS_PORT.md`).
Check: `flutter analyze` and `flutter test`.
