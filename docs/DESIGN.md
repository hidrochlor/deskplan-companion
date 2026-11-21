# DeskPlan design scheme (for the Companion app)

The Companion app should look like the same product as DeskPlan. This file is the single place for that. The PC's `renderer/styles.css` (the `:root` and `:root[data-theme="light"]` blocks) is the source of the colours; if the PC's look changes, update this file. The phone's copy of the tokens is `lib/ui/theme/deskplan_colors.dart`, mapped onto Material in `lib/ui/theme/app_theme.dart`.

## Rules of the look

- **Dark is the default theme. Support both dark and light** (the user can switch on the PC; follow the phone's system setting by default, like the PC's "Match Windows").
- **Calm, flat, low contrast surfaces.** Layers are told apart by a slightly lighter background, not by shadows. Thin 1 px borders. Shadows only on things that float (pop-ups, toasts, the add button).
- **One accent colour** for interactive things (buttons, selection, today, links, the switch). Status colours are separate (below).
- **Corners:** rows and cards 10 px, inputs and buttons 8 px, floating panels 12 to 16 px, pills fully round.
- **Text size:** body 14 px, secondary 12.5 to 13 px, small labels 11 to 11.5 px, page titles 20 px semi-bold. Titles and labels use weight 600, never bold-heavy.
- **Icons:** thin line icons, never filled.

## Colours: dark theme (default)

| Token | Hex | Use |
|---|---|---|
| `frame` | `#0c0d12` | top bar, icon bar, outermost background |
| `bg` | `#121319` | main page background |
| `bg-side` | `#15161d` | side strips |
| `card` | `#181920` | floating cards, panels, dialogs |
| `surface` | `#1a1c25` | rows, inputs, tiles |
| `surface-2` | `#232532` | raised: buttons, chips, hover |
| `border` | `#272a37` | 1 px borders |
| `border-soft` | white at 6% | dividers inside cards |
| `text` | `#e6e8ef` | main text |
| `muted` | `#8b90a3` | secondary text, hints |
| `faint` | `#5d6277` | disabled text, counts |
| `border-hover` | `#343849` | border when hovered or focused |
| `check` | `#4a4f63` | empty checkbox ring |
| `accent` | `#7c8cff` (indigo) | see "Accent" |
| `accent-soft` | accent at 16% opacity | selected row, highlights |
| `on-accent` | `#0d0f1a` | text on an accent button |
| `danger` | `#ff6b6b` | overdue, delete, errors |
| `warn` | `#f5b84b` | due within 24 h, warnings |
| `ok` | `#4cc9a4` | done, connected |
| `shadow` | black at 40% | floating things |

## Colours: light theme

Soft warm off-whites (never pure white), dark text, and deeper status colours so text stays readable.

| Token | Hex |
|---|---|
| `frame` | `#e8e6e0` |
| `bg` | `#f2f1ec` |
| `bg-side` | `#ebe9e3` |
| `card` | `#fbfaf8` |
| `surface` | `#faf9f6` |
| `surface-2` | `#e9e7e0` |
| `border` | `#d9d6cd` |
| `border-hover` | `#c2bdb1` |
| `text` | `#1f1d1a` |
| `muted` | `#57534c` |
| `faint` | `#8a857b` |
| `check` | `#9f9a8f` |
| `accent-soft` | accent at 13% opacity |
| `on-accent` | `#ffffff` |
| `danger` | `#c93c3c` |
| `warn` | `#a8660b` |
| `ok` | `#23866a` |

## Accent

The user picks one of 8 accents on the PC (Settings › Appearance). Default is **Indigo**. If the phone offers a choice, use the same list:

| Name | Hex (dark theme) |
|---|---|
| Indigo (default) | `#7c8cff` |
| Blue | `#4c9aff` |
| Teal | `#33c3b0` |
| Green | `#5cc96b` |
| Amber | `#f5b84b` |
| Clay | `#d97757` |
| Pink | `#f472b6` |
| Violet | `#b57cff` |

**In the light theme the accent is darkened:** mix it 22% toward black (each channel times 0.78). For example Indigo `#7c8cff` becomes `#616dc7`.

## Item kind colours

Used for the small dot or chip that says what something is.

| Kind | Hex |
|---|---|
| Task | `#7c8cff` |
| Assignment | `#ff7a8a` |
| Folder | `#f5b84b` |
| Note | `#e6c86e` |
| File | `#8b90a3` |

The phone shows tasks, assignments and notes, so it needs the first, second and fourth (a task is the default).

## Due dates

The same urgency colours as the PC:
- overdue: `danger`
- due within 24 hours: `warn`
- due within a week: normal `text`
- later: `muted`

**Assignment card (phone).** Countdown first: "Due in 5hrs 49m" / "Overdue 7hrs" / "Submitted" in the urgency colour (`ok` when submitted), the due day and time on the right in `faint` ("Sat, Oct 31 · 02:14"), then the title (15, semibold; struck through when submitted), the course, and the steps done with the source pill ("Moodle", rounded, `bg` fill, `border` outline) at the end. Overdue and due-within-24-hours cards have a 3 px left edge in `danger` / `warn`. Assignments are listed under SUBMITTED, OVERDUE (label and count in `danger`) and UPCOMING headings.

**Times (phone).** Always the 24-hour clock ("17:30"), whatever the phone's setting, in the cards, the sheets and the time pickers.

**Syncing (phone).** Pulling a list down shows a pill at the top instead of a spinner: three dots that swell in turn and a line in `accent` ("Pull to sync", "Release to sync", then "Syncing with <PC name>…" while it runs), on a faint `accent` fill with a thin `accent` edge. Busy buttons show the same three dots.

**Reminder buttons (phone).** A one-off task's or assignment's reminder has two buttons: "Start 30 min later" / "Start 1 hr later" on the start reminder (start and end move together), "Extend 30 min" / "Extend 1 hr" on the due reminders (the end moves; an end already past is extended from now). They work with the app closed and sync like any edit. Repeating items, imported assignments and notes get none.

**Bottom bar icons (phone).** Filled icons, `muted`, the open one in `accent`, with no pill around it.

**Task card (phone).** A round tick, the title (14.5, semibold), its time on one line on the 24-hour clock ("14:10–14:30"; with the day in front under Overdue and Done), the course, and at the right how long until it needs you, in bold: "Starts in 3hrs" to the start of a time block, then "Due in 1hr" to its end (an item with only a due time says "Due in" from the first), "Overdue 10hrs" past its end. Red (`danger`) when overdue or within the hour, amber (`warn`) within 24 hours, `muted` later; red and amber cards get the 3 px left edge. The list is grouped under small headings with a count at the right: REPEATING (folds, starts open), DONE, OVERDUE (`danger`), TODAY, TOMORROW · SUN, NOV 1, then each later day ("THU, NOV 5"), then NO DATE.

**Progress counts.** Anything counted as done of a total (an assignment's steps, a note's checklist) is shown the same way everywhere: a checklist icon and "1/3", turning `ok` and semibold once every one is done, whether or not the assignment is submitted. In code: the `Progress` value and the `ProgressCount` widget (`ProgressCount.colorOf` where a screen words it itself, "3 of 3 steps done").

**Folding headings.** DONE, SUBMITTED and both OVERDUE headings fold with a chevron at the right, and all start shut. A folded group is only out of sight: nothing is deleted.

## Calendar colours

The PC's (`renderer/modules/feeds/FeedCalendarSource.js`), the same in both themes. On the phone: the constants in `lib/ui/calendar/calendar_entry.dart`.

| Entry | Hex |
|---|---|
| Lecture | `#5c9ce6` |
| Exam | `#ff5c7a` |
| Other event (and any unknown `kind`) | `#8b90a3` |
| Assignment | `#ff7a8a` (the kind colour) |
| Task, time block, step | `#7c8cff` (the kind colour) |

## Typography

- The PC's fonts (Segoe UI and other Windows or Office fonts) do not exist on Android. The phone uses Flutter's default (Roboto). If a font is ever bundled, it goes in both apps so they match.
- Sizes and weights as in "Rules of the look".

## Icons

DeskPlan draws thin line icons (24 x 24 grid, 1.8 px stroke, round caps and joins, no fill). The phone uses Material's **outlined** icons (`Icons.folder_outlined`, `Icons.assignment_outlined`, ...) as the closest match and never the filled variants. No SVG assets are bundled.

## Logo

A desk lamp switched on over a desk: the lamp in `text` (`#e6e8ef`), its light (a soft cone and the lit stretch of desk) in indigo `#7c8cff`, and a mint bulb `#4cc9a4`, on `#121319`. It keeps these brand colours whatever accent the user picks. In the light theme the lamp is `#2a2733`, the light `#616dc7` and the bulb `#23866a`. It is the one filled drawing in the product; the UI icons stay thin line icons.

- **Source:** `build/icon.svg` on the PC (rounded tile), `assets/icon/icon.svg` on the phone (square). The PC draws it in the top bar from `logo()` in `renderer/core/icons.js`, at the far left above the icon bar.
- **PC:** `build/icon.ico` (16 to 256 px) is the window and taskbar icon.
- **Phone:** `assets/icon/app_icon.png`, `icon_foreground.png` (the lamp at 78% so it stays inside Android's circular crop) and `icon_monochrome.png` (themed icons), turned into launcher icons with `dart run flutter_launcher_icons`.

## Components to match

- **List row:** `surface` background, 10 px corners, 9 to 12 px padding, no border until pressed or selected; selected = `accent-soft` background plus a 1 px accent border.
- **Check circle:** 20 px circle with a 1.5 px `check` ring; when done it fills `ok` with a white tick, and the title turns `muted` with a line through it.
- **Buttons:** 8 px corners, `surface-2` background and 1 px `border`. The primary button is solid `accent` with `on-accent` text and weight 600. Destructive is text in `danger` with no fill.
- **Switch:** 40 x 22 px track (`surface-2` off, `accent` on), 18 px white knob.
- **Pop-ups and toasts:** `card` background, 1 px `border-soft`, 12 to 14 px corners, a soft shadow; toasts have a 3 px accent bar on the left and an optional text-button row.
- **Status dot:** an 8 px dot. The PC's phone icon uses grey off, blue (accent) on but quiet, green `ok` connected, amber `warn` needs attention, plus a separate amber "!" badge for warnings. The phone uses the same meaning for its connection icon (below).
- **Bottom bar (phone):** the main screen is a bar of five icons at the bottom, Calendar, Assignments, Tasks, Notes, Settings (outlined icons, no labels: the page title says where you are), each opening its own page. `frame` background, a 1 px `border` line on top, 62 px high; the current icon is `accent` on an `accent-soft` pill, the others `muted`. The add button floats above it on the pages that can add. The Notes page stays in the bar while the PC does not sync notes (protocol.md, ping `features`) and says why there are none. The phone does not show folders. (This replaced the earlier Home cards and "Due soon" list.)
- **Connection icon (phone):** a link icon in the app bar with an 11 px dot at its top right, ringed 2 px in `frame` so it stays readable: `faint` not paired, `accent` paired but the PC not reached, `ok` connected, `warn` needs attention, `danger` pair again. Tapping it opens the connection screen.
- **Connection banner (phone):** when DeskPlan cannot be reached, a strip under the app bar: 10 px corners, the colour at 12% as the fill and 40% as a 1 px border, an icon in the colour (hourglass waiting for approval, pause when receiving is off, no Wi-Fi when the PC cannot be reached, broken link otherwise), the reason in `text` 13 px and how many changes wait in `muted` 12 px. `warn` means wait or check the PC; `danger` means act on the phone, with a "Pair again" button.
- **Settings page (phone):** a card for the connection (a 34 px tile with a computer icon in the connection colour at 16%, the PC's name or "Pair with DeskPlan" at 15 px weight 600, the sync state in `muted` 12.5 px), then one card of rows: "Files sent to your PC", "Reminders" and "Timetables and courses". The sync state ends with "N changes waiting to sync" ("1 change") while some wait. Rows have a `muted` icon, a 14 px title, a `muted` 12.5 px line and a `faint` chevron, with `border-soft` dividers between them. Background sync is explained on the connection screen. The app's version sits at the bottom in `faint` 12 px.
- **Add menu (phone):** the "+" button opens a sheet of rows, each a kind-coloured icon on a tile of itself at 16%, a title and one short line: Task (`accent`), Assignment (only once the phone has seen the PC's folders), Note (only while the PC syncs notes), Files & photos (`muted`, "Sent to DeskPlan on your PC").
- **Calendar page (phone):** a Month / Agenda switch at the top. Month: the month name (17 px, weight 600) with Today and previous / next buttons, then the grid on a `surface` card with 12 px corners; each day a 28 px circle, today ringed 1.5 px in `accent`, the selected day filled `accent` with `on-accent` text, and up to three 5 px dots in the colours of what is on it (see "Calendar colours"); the chosen day's entries below. Agenda: every day from today that has something, under "Today · …", "Tomorrow · …" labels. An entry is a list row with a 4 px bar in its colour on the left, the time in a 74 px column (`muted`, 11.5 px; "Due" for a deadline, "All day" for one that spans the day), the title (14 px) and the kind label and context below in `muted` 12.5 px ("Lecture · VO · Online · …", "Assignment · <course>"); feed events have a small `faint` lock. Past events and finished items are at 50% opacity. Under the switch, "Timetable as of <time>" in `faint` 11.5 px with a history icon. Tapping an event opens a read-only sheet (a kind pill, the title at 18 px, "Past" in `faint` when over, and "From your calendar feeds on DeskPlan. Read-only here."). A lecture or exam with a course has a full-width outlined button "See all N sessions" that opens the course timetable. Empty: "Nothing on this day" / "Nothing coming up".
- **Course timetable (phone):** the course name as the page title; a `surface` card with "12 lectures · 1 exam · 5 still to come" in `muted` 13 px and the weekly slots it meets in as chips (lecture colour at 14%, "Tue 09:00–12:15  ×4", 13 px weight 600, tabular figures), "+ N at other times" in `muted` when some lectures fit no weekly slot, or "No weekly pattern" when none repeat. Then every session under month headings (`muted` 13 px weight 600): a list row with the 4 px kind bar, a 56 px date column (the day at 18 px weight 600, the weekday in `muted` 11.5 px), the time (14 px; an exam reads "Exam · 9:00–10:30" in the exam colour) and the room and lecturer in `muted` 12.5 px. Past sessions at 50% opacity; the next one on `surface-2` with a "Next" pill (`accent-soft`, `accent` 11 px weight 600). Tapping a session opens its read-only sheet.
- **Course timetable (PC):** clicking a lecture, exam or other feed event on the calendar opens it in the right panel (title in the kind's colour): the title at 17 px weight 600, the time and the room / lecturer with `muted` icons, "From your calendar feeds. Read-only." Under it, for a lecture or exam, "<course>: all sessions": the same summary and weekly slots as the phone's (on a `bg` box with a `border-soft` line), then every session under month headings as a row with a 3 px left bar in its kind colour, the date (15 px weight 600) over the weekday, the time (an exam reads "Exam · …" in its colour) with a "Next" pill, and the context. Past rows at 50% opacity, the next on `surface-2`, the one shown above outlined in `accent`. Clicking a row opens that session.
- **Reminders page (phone):** three cards (`surface`, 12 px corners, 1 px `border-soft`), each with a 36 px icon tile (`accent-soft` with an `accent` icon while on, `surface-2` with a `muted` icon while off), a 15 px weight 600 title, a `muted` 13 px line and, where it can be off, a switch. "Before a task is due" holds the timeline: a 2 px `border` line with a stop for 1 day, 5 hrs, 3 hrs, 1 hr, 30 mins and Due, left to right towards the due time. A stop on is a filled `accent` dot, off a hollow `border-hover` ring; "Due" is always on, ringed in `accent-soft`, and can not be tapped. Labels under the stops at 12 px (`text` weight 600 when on, `muted` when off), 48 px tap targets, and one line underneath reading the choice back ("Reminds 1 day and 1 hour before, and when it is due."). "Exams" and "Daily goal" (with its time and text) follow.
- **Repeat (both):** a "Repeat" choice under the due time (Never, Daily, Weekly, Every 2 weeks, Monthly; a rule made elsewhere shows as its own choice) and, once set, "Until <date>" with Set end / Change / Clear. Repeating items show a small repeat icon: on the PC after the title (hover: "Weekly"), on the phone after the due line of a task and as a line "Weekly" on an assignment card.
- **Timetables and courses (phone):** the same list as the PC's Settings › Data › Calendar feeds. A short `muted` explanation, then a `surface` card per feed: a kind icon in `accent`, the name (15 px weight 600), "<host> · Updated <date, time>" in `muted` (the error in `danger` when the last download failed), a refresh button (a spinner while downloading) and a menu with Rename and Remove (asks first). "Courses: 9 of 11 shown" opens the courses: Show all / Hide all, then a checkbox row per course with "12 lectures · 1 exam to come". An "Add iCal link" button floats at the bottom; it asks for the address and says a course in another timetable group (a language course) has its own link.
- **Note row:** a card with where it sits on top (a small `noteKind` dot, then the folder path in `faint` with the last part in `muted`, semibold; nothing at the top level of Home), the title (weight 600; "Untitled" in `faint` when empty), up to 2 lines of preview from the note's text in `muted` at 12.5 px, and a bottom line: "Edited today 09:38" (or "Edited Oct 29") in `faint` and, if the note has a checklist, a checklist icon and "2/5" at the right, `faint`, turning `ok` once every item is ticked.
- **Note page** (as the PC's `.note-pane` and `.rich` in `styles.css`): the title as a borderless input, 22 px, weight 600, placeholder "Untitled". Body 14.5 px, line height 1.65, the caret in `accent`. Heading 1 is 22 px and heading 2 is 17 px, both weight 600 (Flutter has no 650), with a little space above. Lists are indented 24 px per level with a 26 px gutter for the marker: a 6 px `muted` dot at level 0, a ring at odd levels, a small square at even levels. Checklist lines have a 15 px box with 4 px corners and a 1.6 px `muted` border; when ticked it is filled `accent` with an `on-accent` tick, and the line turns `muted` and struck through. Parts the phone cannot edit (a table, say) show as read-only boxes: `surface-2`, 8 px corners, 13 px `muted` text. When the note is empty, show the hint "Start writing…" in `faint`. Formatting tools (line type, indent, bold, italic, strikethrough) go in a thin bar above the keyboard, with `surface-2` buttons; an active tool is `accent-soft` with `accent` text.
- **Empty states:** centred, `muted` text, one short sentence and, if useful, one small button.

## Flutter

`DeskPlanColors` is a `ThemeExtension` holding every token above (read it with `DeskPlanColors.of(context)`). `AppTheme` maps the tokens onto the `ColorScheme`: `surface` to `bg`, `surfaceContainer` to `card`, `surfaceContainerHigh` to `surface`, `surfaceContainerHighest` to `surface2`, `outline` to `border`, `onSurface` to `text`, `onSurfaceVariant` to `muted`, `primary` to `accent`, `onPrimary` to `onAccent`, `error` to `danger`. `warn`, `ok` and the other tokens Material has no slot for stay in the extension.
