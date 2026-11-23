# DeskPlan <-> Companion: where the two apps differ

The phone and the PC are meant to behave alike. This file lists the places where they do not, on purpose or not yet,
so neither side drifts without anyone noticing. `protocol.md` holds the wire rules and `CHANGES.md` the steps still to
do; this file is only about **behaviour and look that differ** while both sides follow the contract.

**Keep it up to date.** Add a row when one app gets something the other does not. When the two are brought in line,
move the row to "Settled" with the date. Keep this file the same in both projects (`docs/DIFFERENCES.md` here and in
the other project), like the other docs.

Last checked: 2026-11-23, PC at commit `b4106e1`, phone on branch `calendar-clashes-and-notes` (not committed yet).

## Kinds

- **Data**: the two apps hold different information, so what you see depends on the device. Fixing it needs
  `protocol.md` and work on both sides.
- **Look**: same data, shown differently. Either side can change on its own.
- **Phone only / PC only**: fits one device and is not meant to be copied.

## Open

| # | Area | Phone | PC | Kind | To bring in line |
|---|---|---|---|---|---|
| 1 | Exam dates: "Registered" and numbering | An exam's sheet has **Registered for this date**. The mark is kept on the phone only (per course). The course's other dates are dimmed, cause no clash and get no reminder. Each date says which it is (`Exam · Date 2 of 3`). | Neither: every date is shown the same and each one reminds 1 day and 1 hour before. | **Data** | Add the marks to `protocol.md` (for example in `/v1/feed-settings`, next to the hidden courses), store and show them on the PC, skip reminders for the other dates. Numbering alone is look only. |
| 2 | Done / Submitted order | Latest **due date** first (Nov 20 before Nov 5); no due date last. | Most recently **finished** first (`completedAt`). | **Data** | The phone never receives `completedAt` (protocol.md section 4: the PC owns it). Send it to the phone, then sort by it there. Or the PC sorts by due date. |
| 3 | Clash warnings | A grey circled "!" on a calendar row that overlaps another; its sheet says by how much, using only A's end and B's start: "Starts 15m before EPE ends" on B, "Ends 15m after HS1 starts" on A. Past and finished entries, and exam dates passed over, never clash. | None. | Look | Add the same rule and text to the PC calendar, or decide it stays phone only. |
| 4 | Past and missed items in the calendar | Everything whose time has passed is dimmed. An item of yours that ended undone says `· Missed` in red after its label (`Task · WS 2026 · Missed`); a folded assignment says `· Missed`, or `· 2 missed` for its steps. | A missed item is **not** dimmed: its time turns red (`.late`). Done items and past feed events are dimmed. No "Missed" text. | Look | Pick one. |
| 5 | Steps in the calendar | A step never has a row or a dot of its own. All of an assignment's steps live inside its row on the due day, whatever day they are on: `Due 13:00`, the title, `Assignment · WS 2026`, and `3/4` over the chevron. Tap the row to open the assignment, the chevron to list the steps (no "Step" label repeated; the date shown for a step on another day). | Steps fold under the assignment only on its due day (`Assignment · 4 steps · 3 done`). On other days two or more steps get their own row ("3 steps · 1 done") and a lone step shows on its own. | Look | Pick one. |
| 6 | Agenda filter | Chips Tasks, Assignments, Exams; none ticked shows everything. Forgotten when the app restarts. | Chips All, Tasks, Assignments, Exams. Remembered on that PC. | Look | Add "All" and remembering on the phone, or drop "All" on the PC. Steps count as their assignment on both. |
| 7 | Course after moving an item | Moving an item to another folder forgets DeskPlan's `course` and shows the new top-level folder (nothing for Home) until DeskPlan sends the new one. | Works the course out from the folder, so it is always current. | Phone only | Nothing: the phone shows the PC's answer once it syncs. Only the offline display differs. |
| 8 | Capitals in notes | Capitalizes the start of a line or sentence and a lone "i" as you type, whatever the keyboard does. | No. | Phone only | Nothing (a desktop keyboard does not need it). |
| 9 | Why the PC can't be reached | A small pill in the top bar between the page name and the link icon ("Can't reach DeskPlan at …", "7 waiting to sync"); tap for the connection. | Not applicable. | Phone only | Nothing. |

## Settled

Rows that were brought in line, with the date. None yet.
