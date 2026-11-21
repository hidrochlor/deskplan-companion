# DeskPlan <-> Companion: the contract

The rules both projects follow: **DeskPlan** (the PC, which runs the server) and **DeskPlan Companion** (the Android phone app, the client).
Three files, copied unchanged into the phone project: **`protocol.md`** (this file: the rules), **`CHANGES.md`** (what changed and what each side must do next) and **`DESIGN.md`** (the look).

This file holds only rules that stay true. Nothing here is a to-do: when wire behaviour changes, change it here and say what each side must do in `CHANGES.md`. It describes what the PC **actually does**, checked against its code and tests.

No cloud, no accounts. Everything stays on the user's own devices. Only the local network works, by design: away from it the phone queues and sends when it is back.

## 1. Pairing (once per phone)

On the PC: Settings › Phones › Show code. DeskPlan shows a QR code that holds this JSON (one line, UTF-8):

```json
{ "v": 1, "name": "DESKTOP-ABC", "port": 47800, "token": "<base64>", "fp": "<64 hex>", "hint": "192.168.1.23" }
```

| Field | Meaning |
|---|---|
| `v` | Protocol version. Always `1`. Refuse a QR with any other value. |
| `name` | The PC's name, to show ("Paired with DESKTOP-ABC"). |
| `port` | The port to use. **Usually 47800, but can be 47801 to 47809 if 47800 was busy.** Always use this value. |
| `token` | The shared secret: 32 random bytes, base64. Treat it as a password. Store it in secure storage. |
| `fp` | SHA-256 fingerprint of the PC's certificate: 64 hex characters, **lowercase, no colons**. |
| `hint` | The PC's last known IPv4 address on the home network, or `null`. Only a first guess; addresses change. |

- Reject a QR that is not JSON, has a different `v`, or has a `token` / `fp` / `port` of the wrong shape. Store nothing in that case.
- Scanning needs no network. But the phone's **first request must reach the PC within 10 minutes** of the code being made, or the code expires (`401`; ask the user to show a new code). The on-screen code also disappears after 2 minutes.
- **After the first request the user must approve the phone on the PC** (a pop-up there, also in the top-bar phone icon and Settings › Phones). Until then every request gets `403 awaiting-approval`. Show "Waiting for approval on your PC" and keep retrying gently (every 5 to 10 seconds while the screen is open, then back off). Approval is once per phone; individual transfers are never approved.
- Once approved, the pairing has no expiry. The PC can **revoke** a phone at any time; its token then gets `401`. Show "This phone is no longer paired" and offer to pair again.

## 2. Transport and security

- **HTTPS only.** The PC uses a self-signed certificate it makes on first run (RSA 2048, SHA-256, valid 10 years, common name `DeskPlan (<PC name>)`). It has **no hostname or address in it**, so normal hostname checking can never pass.
- **Certificate pinning is required.** The phone must accept a server only if SHA-256 of the server's certificate (the raw DER bytes) equals `fp`, and no other certificate. In Dart, for example:

  ```dart
  final client = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
        sha256.convert(cert.der).toString() == fp;   // package:crypto; hex is lowercase, no colons
  ```
- If the PC's certificate is ever replaced (its files were deleted), the fingerprint changes and every phone must pair again. A pinning failure is shown as "The PC's identity changed. Pair again", never silently ignored.
- Every request carries `Authorization: Bearer <token>`.
- `X-Device-Name: <URL-encoded text>` on every request names the phone ("Galaxy S24"; in Dart `Uri.encodeComponent(name)`). Optional, but without it the phone shows as "Unnamed phone". The PC keeps the first name it hears (up to 80 characters), unless the user renamed the phone on the PC.

## 3. Finding the PC

1. **mDNS:** service type `_deskplan._tcp` (instance `DeskPlan (<PC name>)`) on the port in use, TXT `id=<first 8 characters of fp>`. Match `id` against the stored `fp`. Announced only while receiving is switched on.
2. If not found: try `hint` from the QR.
3. If that fails: try an address the user typed by hand.

Multicast is often blocked on shared Wi-Fi, so steps 2 and 3 are required fallbacks. Whatever address is used, the certificate must still match `fp`. The phone must be on the same network as the PC (same Wi-Fi, or the phone's own hotspot with the PC joined to it). Mobile data cannot reach the PC. When the PC cannot be reached, keep everything queued and show "Waiting for DeskPlan"; do not try to get around network blocks.

## 4. Items: tasks, assignments and notes

`task`, `assignment` and `note` items sync. Folders and files (and the old `course`, `project`, `job`, `reading`) stay on the PC. Notes sync only with a DeskPlan that lists `notes` in `features` (ping, section 5), and are pulled only by a phone that asks for them (`kinds`, section 5), so a phone that does not know notes never sees one.

### Fields

| Phone field | Direction | Notes |
|---|---|---|
| `id` | both | 1 to 64 characters from `A-Z a-z 0-9 . _ -` (a UUID v4 is ideal). Same id on both sides = same item. |
| `title` | both | At most 500 characters (may be empty). |
| `end` | both | UTC time or `null`. The due time; for a time block, when it ends. A note has none (a due time given to a note on the PC stays on the PC: it is never sent, and a phone edit keeps it). |
| `start` | both | UTC time or `null`. See "Shapes". **Leaving it out is the same as `null`: it clears the start** (refused on a task that has one: a task keeps its start). A note has none. |
| `done` | both | A real boolean. `true` = status `done`; `false` = `todo`, unless the PC item is `doing` (it stays `doing`); a done item goes back to `todo`. For an assignment, `true` means **submitted**. A note is always `false` (leaving it out is the same). |
| `updatedAt` | both | When the item was last edited. Required on `PUT`. The PC sets it on every edit **and every move** (for a note, on every change to its text, as it saves while the user types). |
| `kind` | both, optional | `"task"`, `"assignment"` or `"note"`. Left out = keep the PC's; a new item is a `task`. **The type is fixed when an item is made:** naming a different kind on an existing item is `422`. |
| `parentId` | both, optional | The id of the folder or assignment it sits in, or `null` for the top level of Home. It is the item's own id, **without** the `folder:` prefix that `destinations` uses. Left out = keep the PC's; a new item is at the top level. |
| `description` | both, optional | For a task or assignment: its **Details**, text, at most 16,000 characters, line breaks `\n`. An empty text clears it. Left out = keep the PC's; a new item has none. **For a note it is a plain-text copy of `doc` that the PC makes** (for previews and search): the PC sends it, the phone never needs to, and the PC ignores it on a note. |
| `doc` | both, optional, notes only | The note's formatted text (see "Note text"). Left out = keep the PC's; a new note without it is empty. Ignored on a task or assignment. |
| `createdAt` | PC to phone only | When the item was made (for items made on the phone: the `updatedAt` of its first `PUT`). Never changes. Ignored if the phone sends it. Can be `null` for very old items. |
| `course` | PC to phone only | The name of the course the item belongs to, or `null` (see "Assignments, steps and courses"). Ignored if the phone sends it. Missing from a DeskPlan older than the calendar: then use the top-level folder. |
| `source` | PC to phone only | `{ "label": "Moodle" }` when the item was imported from a calendar feed, otherwise `null` (see "Imported assignments"). Ignored if the phone sends it. |
| `repeat` | both, optional | How a task or assignment repeats, or `null` (see "Repeating items"). Left out = keep the PC's; a new item does not repeat. Always `null` for a note. Missing from a DeskPlan without the `repeat` feature: the phone then keeps its own and does not send one. |

The PC never reads or changes anything else (`file`, `completedAt`, colour..., and `doc` on a task or assignment). **Any other field in a body is ignored**, and a phone edit can never wipe what the PC owns.

### Shapes (decided only by the fields; there is no field for it)
- **Deadline:** no `start`. Due at `end` ("Oct 6, 23:59").
- **Time block:** a `task` with a `start` and an `end`. It runs from start to end ("15:00 to 19:00"). **A new task must have both** (`422` otherwise), and once it has a start it keeps one. Tasks made before this rule may have only an `end`; they stay valid and can be given a start.
- **Assignment:** a deadline only. It always has an `end` and **never** a `start`.
- **Note:** no times and no tick. Only `title`, `parentId` and `doc` mean anything.
- Rules (a break is `422 invalid-request`): a `start` needs an `end`; `start` must be earlier than `end` (equal is refused); an `assignment` needs an `end` and must not have a `start`; only a task can have a `start`; a `note` has no `start`, no `end` and is never `done: true`.
- Every time is UTC text ending in `Z` (or an offset such as `+02:00`); a time with no zone (`2026-11-01T09:00:00`) is refused. In Dart: `DateTime.toUtc().toIso8601String()`. The PC stores and returns times normalised (`2026-11-01T09:00:00.000Z`). Show local time on screen.

### Where things may live
Refused with `422 invalid-request`, and nothing changes:
- an **assignment** needs a `parentId` that is a **folder**. Never at the top level of Home, and never inside a task, another assignment or a note;
- a **task** may be at the top level of Home, in a folder, or in an assignment (a task inside an assignment is a **step**); never inside another task or a note. A task holds nothing: only folders and assignments hold things;
- a **note** may be at the top level of Home, in a folder, or in an assignment; never inside a task or another note. A note holds nothing;
- the parent must exist, and an item can not go inside itself or something inside it.

DeskPlan's own screens follow the same rules, so the PC and the phone cannot disagree.

### Note text (`doc`)
`doc` is the note exactly as DeskPlan's editor saves it: Tiptap / ProseMirror JSON, `{ "type": "doc", "content": [ ... ] }`. The PC's `renderer/modules/workspace/editor/NoteFormat.js` is the reference for reading and writing it.

```json
{ "type": "doc", "content": [
  { "type": "heading", "attrs": { "level": 1 }, "content": [ { "type": "text", "text": "Week 3" } ] },
  { "type": "paragraph", "content": [ { "type": "text", "text": "Read ", "marks": [ { "type": "bold" } ] }, { "type": "text", "text": "chapter 3" } ] },
  { "type": "taskList", "content": [
    { "type": "taskItem", "attrs": { "checked": true }, "content": [ { "type": "paragraph", "content": [ { "type": "text", "text": "Slides" } ] } ] } ] } ] }
```

- **What the PC editor edits:** `paragraph`; `heading` (`attrs.level` 1 or 2; a higher level is shown as 2); `bulletList` of `listItem`; `taskList` of `taskItem` (`attrs.checked` true or false); a list inside a list item for indenting (at most 6 levels); and inside those, `text` (marks `bold`, `italic`, `strike`, and `link` with `attrs.href`) and `hardBreak` (a line break inside a line). `orderedList` and `blockquote` are valid; the PC editor turns them into bullets and plain lines when it edits the note.
- **Anything else is valid and must be kept** (for example a table made by a later editor). A phone that cannot edit a part shows it read-only and sends it back unchanged, in the same place. Never drop or rewrite what you do not understand.
- **Checked by the PC** (a break is `422 invalid-request`): `doc` is an object with `"type": "doc"` and a `content` list; every node is an object with a text `type`; a node's `content`, if there, is a list; `text`, if there, is text; `marks`, if there, is a list of objects with a text `type`; nesting is at most 50 deep. Nothing else is checked.
- **The PC always sends `doc` for a note.** A note saved before the rich editor (plain text only) is sent as the `doc` built from its text, so the phone only ever reads one format.
- The whole request, `doc` included, is at most 1 MB (section 8). The PC sets `description` from `doc` on every applied change.

### Assignments, steps and courses
- An assignment holds **steps**. Its progress is **finished steps / all steps** (only tasks directly inside it count, not notes or files). An assignment has no tick: **submitted** (`done: true`) is its own action, and finishing every step does not submit it.
- **Course** = the **top-level folder** of the path to an item ("CSC101" in "CSC101 › Week 1 › Homework 2"), **except** when that folder is a semester: a name of the form `WS 2026` or `SS 2027` (`WS` or `SS`, an optional space, four digits, any letter case) with a folder inside it. Then the course is the folder inside it ("Climate Change and Dynamics" in "WS 2026 › Climate Change and Dynamics › Assignment"). An item sitting directly in a semester folder has the semester as its course. The PC sends the result as `course` on every item; the phone shows that and does not work it out itself.
- Old assignments that had no folder were moved once into a top-level folder called **Unsorted** (it shows "Needs a course" on the PC until the user moves it). It is an ordinary folder and appears in `destinations`.

### Imported assignments
DeskPlan can subscribe to calendar feeds (Settings › Data › Calendar feeds). Due dates from a Moodle feed become ordinary `assignment` items, sent and pulled like any other, filed in `<semester> › <course>` folders. Such an item has `source` set.
- **Its `end` belongs to the feed.** A `PUT` with a different `end` is **not** refused: the rest of the change is applied and `end` keeps the PC's value (the reply shows it). When the feed moves the due date, the item's `end` and `updatedAt` change, and the next pull brings it.
- `title`, `description`, `done`, `parentId` and its steps behave as for any assignment. A title or description changed on either device is kept, even when the feed changes its own later.
- **Deleting it is allowed** and is reported like any deletion. The PC does not import it again; only the PC can bring it back (Settings › Data, while the feed still lists it). A restored item has a **new** `id`.
- An item never gets or loses `source` after it is made.

### Repeating items
`repeat` is `{ "every": "day" | "week" | "month", "interval": 1-12, "until": UTC time | null }`; `interval` left out is 1. Anything else is `422`. Only a task or assignment that has an `end` repeats; a rule sent for an imported assignment is ignored (Moodle owns its dates), like its `end`.

**When an item with a rule changes from not done to done, its next copy is made** (on whichever device it was ticked; the PC also makes it when a phone's `PUT` ticks it):
- **Its id is worked out, not random:** `<id>.r1` for the first copy, then `.r2`, `.r3`... (`X.rN` becomes `X.r(N+1)`). If that would be longer than 64 characters, the root is cut to its first 52 characters. Both devices make the same id, so when both make the copy the usual last-edit-wins merges it into one item.
- **Its times:** `end` (and `start`, if any) moved on by the rule in **local time** (a 9:00 class stays at 9:00 across a clock change; a monthly 31st falls on the last day of a shorter month), by the fewest steps that put `end` in the future, so missed ones are skipped. No copy when that `end` is after `until`.
- **The rest:** same `title`, `kind`, `parentId`, `description` and `repeat`; not done. Steps inside an assignment are not copied.
- Nothing is made when the copy's id already exists, or when the item was already done.
- **Unticking takes the copy back** when the item's `end` is still in the future and its copy is the series' latest (no copy of its own) and not done: the device where it was unticked deletes the copy and reports the delete as usual, so the item is the next one again. Otherwise (its time has passed, or the copy is done or has a copy) unticking removes nothing. Both devices apply this; a delete for a copy already gone is answered `deleted: true`.

**When an item with a rule is still not done after its `end` has passed, its next copy is made all the same** (auto-advance), with the same id and times as above. Each device checks on its own (at start, before a sync, and every minute while open); both make the same copy, so it is merged like any other. The past item stays not done: it was missed, and ticking it later makes nothing new, because its next copy's id exists.

**A series** is the item and its copies (the ids that are equal once `.rN` is removed). Apps show it once, as its latest copy, with the others as its history. Deleting from a series deletes every copy in it: if only the latest went, the one before it would make it again. Each deletion is reported as usual.

Only tasks are offered a rule. An assignment that has one (set by an older version) keeps working as above and can have it removed.

### Same item edited on both devices
Whole-item, last-edit-wins:
1. **The newer `updatedAt` wins. If the times are equal, the PC wins.** A move on the PC counts as an edit.
2. Only `title`, `start`, `end`, `done`, `kind`, `parentId`, `description`, `repeat` and (for a note) `doc` are ever replaced.
3. If the phone's `updatedAt` is **more than 5 minutes in the future** of the PC's clock, the PC uses its own clock, so a wrong phone clock cannot win every conflict.
4. When the phone's version loses, the reply says `kept-newer` and carries the PC's version. **Nothing is checked or changed then.** The rules above are checked only when the phone's version is applied; for an existing item, where it lives is only checked when the request contains `kind` or `parentId`.
5. **A note's text is never thrown away.** When the reply to a note's `PUT` is `kept-newer` and the reply's `doc` differs from the `doc` the phone sent, the phone keeps its own text as a **new note**: a new id, the same `parentId`, the title `<title> (phone copy)` (the original title shortened so the whole stays within 500 characters), the phone's `doc`. It queues a `PUT` for that note and takes the PC's version for the original. The user merges the two by hand. A pull never needs this: it skips any item the phone has an unsent change for (section 5).
   - "Differs" means as JSON values: compare the parsed objects, never the text. The same object can be written with keys in another order or other spacing, and a text comparison would make a copy on every harmless retry.
   - The PC does the same the other way. If a phone change reaches a note that is open on the PC with typing not saved yet, the phone's version is applied and shown in a "changed on your phone" message. Until the user reloads, what they type on the PC goes into a new note `<title> (PC copy)` in the same place, which the next pull sends to the phone like any other note.

Limit: if both devices change the same task or assignment while offline, one change is lost. For one person with two devices that is the right trade-off. For notes, rule 5 keeps both.

## 5. Endpoints

All responses are JSON. Every **error** is `{ "error": "<code>" }` (codes in section 7). Checks run in this order, and the first that fails decides the answer: receiving switched on, token valid, device approved, then the request itself.

### `GET /v1/ping`
Authenticated. `200` → `{ "name": "DESKTOP-ABC", "version": "0.1.0", "receiving": true, "destinations": [ ... ], "allowedExtensions": [ ... ], "features": [ "notes", "calendar", "repeat", "feeds" ] }`

`features` lists what this DeskPlan syncs beyond tasks and assignments: `"notes"` (section 4), `"calendar"` (`GET /v1/calendar` below), `"repeat"` (section 4 "Repeating items") and `"feeds"` (`/v1/feed-settings` below). Missing or empty = none (an older DeskPlan). A phone uses `GET /v1/calendar` only while the last ping listed `calendar`. The phone stores the last list it saw, offers creating and editing notes only while it holds `notes`, and asks for notes in the pull only then. If a later ping no longer lists `notes`, the phone keeps its notes but stops sending and pulling them.

`destinations` is where files can be sent. It always starts with `{ "id": "received-files", "label": "Received files" }` (the Received files page; older DeskPlan versions listed it as `inbox`, so a phone should treat `inbox` the same way), followed by **every folder in DeskPlan**, A to Z by path:

```json
[ { "id": "received-files", "label": "Received files" },
  { "id": "folder:7c1e...", "label": "CSC101", "name": "CSC101", "depth": 0 },
  { "id": "folder:2b9a...", "label": "CSC101 › Week 1", "name": "Week 1", "depth": 1 } ]
```
- `label` is the full path, `name` the folder's own name, `depth` how deep it is (0 = top level).
- Folders can be renamed, moved or deleted at any time: **fetch the list again each time the user opens the picker**.
- If DeskPlan's window does not answer within about 1.5 seconds, the list is just Received files. Treat that as "folders unavailable right now", not "all folders were deleted".
- When receiving is off the answer is `403 receiving-off`, not `receiving: false`.

`allowedExtensions` lists the accepted file types, lowercase without dots. Use it to refuse an unsupported file before queueing it. It can grow, so read it again from time to time instead of hard-coding it.

### `PUT /v1/received-files/{uploadId}` (send a file)

The old path `PUT /v1/inbox/{uploadId}` is still accepted, for phones on an older Companion; it behaves the same.

- `uploadId`: a UUID made on the phone when the file is queued. Body: the raw file bytes.
- Headers (all required except `X-Dest-Id`): `Content-Length` (exact; no chunked uploads), `X-File-Name` (URL-encoded), `X-File-Sha256` (hex), `X-Dest-Id` (default `received-files`; an `id` from `destinations`: `received-files` or `folder:<id>`; the old `inbox` is still accepted and treated as `received-files`; anything else, or a folder that no longer exists, is `422 unknown-destination` and nothing is stored).
- `201` → `{ "received": true, "sha256": "<hex>", "storedAs": "<final file name>", "destination": "<the X-Dest-Id used>" }`. The PC checks the SHA-256 **before** answering `201`.
- **Same `uploadId` again** (a retry): `200` with the **same body**, no second file (the PC remembers about the last 5000 uploads). A new file needs a **new** `uploadId`. This check comes before the folder check, so a retry of a finished upload gets `200` even if the folder has since been deleted.
- **File types and links** are in section 8. The type is judged from the name as the PC would store it, before any of the file is read; a link file is also read after it arrives.
- `storedAs` can differ from the name sent: the PC cleans names (section 8) and numbers a taken name (`a (1).pdf`).
- **Files sent to a folder:** the PC stores the file, answers `201`, then files it inside that folder as a normal file. The phone's job ends at the `201`. If the folder was deleted in between, the file is kept in Received files, so nothing is lost. While DeskPlan is starting or busy, a folder upload gets `503 app-not-ready`: retry with backoff.

### `PUT /v1/items/{id}` (create or change an item)
Body: JSON, at most 1 MB, the fields of section 4. The path `id` must equal the body's `id`.

```json
{ "id": "<same as the path>", "title": "Read chapter 3", "start": null, "end": "2026-11-01T09:00:00Z", "done": false,
  "updatedAt": "2026-10-29T10:00:00Z", "kind": "task", "parentId": "7c1e...", "description": "Pages 3 to 9" }
```

A note:

```json
{ "id": "<same as the path>", "title": "Week 3", "start": null, "end": null, "done": false,
  "updatedAt": "2026-10-29T10:00:00Z", "kind": "note", "parentId": "7c1e...", "doc": { "type": "doc", "content": [ ... ] } }
```

Reply `201` (new) or `200` (existing): the item **as the PC now stores it**, plus `result`:

```json
{ "id": "...", "title": "...", "start": null, "end": "...", "done": false, "updatedAt": "...", "kind": "task", "parentId": null,
  "createdAt": "2026-10-29T10:00:00.000Z", "description": "", "result": "created" }
```
`result` is `created` (a new item), `updated` (the phone's version won and was applied) or `kept-newer` (the PC's version is newer or equal: nothing changed, **the phone must replace its own copy with the fields in this reply**).

The reply to a note carries its `doc` and the `description` the PC made from it.

Errors: `413 too-large` (body over 1 MB), `422 invalid-request` (shape, or a rule of section 4), `422 not-syncable` (the id is a folder or file on the PC), `503 app-not-ready` (DeskPlan is starting or busy: retry shortly).

### `DELETE /v1/items/{id}`
Answers `200` whether or not the item still exists, so retries are safe:
- Removed or already gone: `{ "id": "...", "deleted": true }`.
- It has things inside it (an assignment with steps, notes or files), so the PC keeps it: `{ "id": "...", "deleted": false, "result": "kept-has-contents" }`. Drop the queued delete; delete what is inside first.
- `422 not-syncable` for a folder or file; `422 invalid-request` for a malformed id.

### `GET /v1/items?since=<time>` (pull: what changed on the PC)
A DeskPlan from before this feature answers `404 not-found`: treat it as "too old to pull", skip quietly, and keep working as a push-only phone.

- `since` is UTC text ending in `Z` (an offset or other text is `422`; a `+` in a URL must be `%2B`, so simplest is to send the `serverTime` the PC gave you, unchanged, URL-encoded). Left out = "send me everything" (the first sync after pairing).
- `kinds` (optional): which kinds to return, comma-separated, from `task`, `assignment` and `note` (`?since=...&kinds=task,assignment,note`). Left out = `task,assignment`, so a phone that does not know notes never gets one. An unknown or empty kind is `422 invalid-request`. Ask for `note` only when the ping lists `notes`.
- **Adding a kind:** earlier pulls left that kind out, so the first pull that adds `note` to `kinds` leaves out `since` (a full resync).

Reply `200`:

```json
{
  "items": [
    { "id": "c0a8...", "title": "Read chapter 3", "start": null, "end": "2026-11-01T09:00:00.000Z", "done": false, "updatedAt": "2026-10-30T08:15:00.000Z",
      "kind": "task", "parentId": "9d2f...", "createdAt": "2026-10-28T19:40:00.000Z", "description": "Pages 3 to 9" },
    { "id": "7be1...", "deleted": true }
  ],
  "serverTime": "2026-11-02T10:00:00.000Z",
  "fullResync": false,
  "fields": ["course", "createdAt", "description", "done", "end", "id", "kind", "parentId", "source", "start", "title", "updatedAt"]
}
```
- A normal entry has exactly the fields of the `PUT` reply, without `result` (`done` is `true` only for status `done`; a note also carries `doc`). `{ "id", "deleted": true }` means "remove this item from the phone": it was deleted on the PC. Deletions are **not** filtered by `kinds`: a phone can get one for an id it never had, such as a note it did not ask for, and ignores it.
- `parentId` is a folder or an assignment, or `null`. **Folders are not in this list**; their names and paths come from `destinations`. The PC only reports a parent the phone may use: old data can hold a task inside a task, and the PC then reports the nearest folder or assignment above it (or `null`).
- `serverTime` is the PC's clock when the reply was built. Save it and send it as the next `since`; the phone's own clock is never used.
- `fields` lists every field an item can have in this reply, A to Z (`doc` is there when notes were asked for). The PC builds it from the items themselves, so a new field shows up here on its own. The phone keeps the fields it **reads** that were in the reply when it last read everything; when a reply has one it reads that was not there (the PC gained it, or a phone update learned to read it), it asks for everything once (no `since`), so items that did not change learn it too. An older PC sends no `fields`; the phone then just carries on.
- `fullResync` is `true` when the list is the complete set of the kinds asked for, instead of changes; the phone then removes any local item **of those kinds** that is not in it, except items with a change it has not sent yet. Items of a kind it did not ask for are left alone (a phone that stops asking for notes keeps its notes).
- **Which items:** everything created, edited or deleted at or after `since` (inclusive, on purpose: applying an item twice is harmless, missing one is not), by the **PC's own edit time**. Items the phone pushed come back in later pulls with normalised times.
- **Deletions** are remembered for **at least 90 days**. A `since` older than that, or missing, gets `fullResync: true`. A deleted id that comes back (the phone sends it again) is returned as a normal item. An item the phone deleted is reported once as deleted: expected and harmless.
- **Moves and parents:** moving an item on the PC sets its `updatedAt`, so it returns with its new `parentId`. **Deleting a folder or an assignment deletes everything inside it**, and each child comes back as `{ "id", "deleted": true }`. A parent's type never changes, so that never needs reporting. Renaming or moving a parent changes nothing for its children.
- No paging yet: the reply holds everything that changed.

**What the phone does with the reply:**
1. Send queued changes first, then pull: on pull-to-refresh, when the app opens, and after each push.
2. **Applying an item:** if the phone has an unsent change for that id, skip the pulled item (the phone's change is sent and section 4's conflict rules decide). Otherwise the PC's version replaces the phone's copy if its `updatedAt` is newer **or equal**. An item the phone does not have is added.
3. **Applying a deletion:** remove the item, unless the phone has an unsent save for it (that save then creates it again on the PC).
4. Pulled changes never create new queued actions, so nothing bounces back to the PC.

### `GET /v1/calendar?from=<time>&to=<time>` (read-only calendar events)
Lectures, exams and other events from the calendar feeds DeskPlan subscribes to (the FH timetable, Moodle events that have a length). **Read-only:** they have no `PUT` or `DELETE`, are never `done`, and are not items. Moodle due dates are **not** here: they are assignments (section 4 "Imported assignments").

- `from`, `to`: optional, UTC text ending in `Z` (an offset is `422`). Left out: from 14 days before the PC's clock, to 180 days after. `to` must be later than `from`, and the window at most 400 days (`422 invalid-request` otherwise).
- Same checks and errors as `/v1/items` (switch, token, approval). A DeskPlan without the `calendar` feature answers `404 not-found`. `503 app-not-ready` when DeskPlan's window does not answer.

Reply `200`:

```json
{
  "events": [
    { "id": "feed:3f2a…|MET2026_1042925", "kind": "lecture", "title": "Storage and Power-to-X Technologies",
      "context": "VO · Online · Sumereder Christof", "course": "Storage and Power-to-X Technologies", "start": "2026-10-05T08:45:00.000Z", "end": "2026-10-05T11:15:00.000Z" },
    { "id": "feed:3f2a…|MET2026_1071313", "kind": "exam", "title": "Exam: Climate Change and Dynamics",
      "context": "WS46a.02.212 · Awan", "course": "Climate Change and Dynamics", "start": "2026-12-02T09:00:00.000Z", "end": "2026-12-02T10:30:00.000Z" }
  ],
  "from": "2026-10-16T12:00:00.000Z", "to": "2027-04-28T12:00:00.000Z", "serverTime": "2026-10-30T12:00:00.000Z"
}
```
- `events`: every event that touches the window (starts before `to` and ends at or after `from`), soonest first.
  - `kind`: `lecture`, `exam` or `event` (anything else from a feed). Treat an unknown kind as `event`.
  - `id`: text, stable for the same event between replies. It only names an event: it is not an item id and has no length or character rules.
  - `title`: never empty. `context`: may be empty; what DeskPlan shows after the kind, e.g. type, room and lecturer.
  - `course`: the course a lecture or exam belongs to, or `null`. A course's lectures and its exams carry the same name (an exam's `title` is "Exam: <course>"), so the phone can list every session of one course. Missing from an older DeskPlan: then use `title`.
  - `start`, `end`: normalised UTC. `end` equals `start` for an event that is a single moment.
- `from`, `to`: the window actually used. `serverTime`: the PC's clock.
- **The reply is the complete set for that window**, not changes: events missing from it no longer exist. Courses the user unticked on the PC (Settings › Data › Calendar feeds › Courses) are never in it.
- **On the PC:** a lecture or other event never has a reminder and never shows as "next". An exam is reminded 1 day and 1 hour before its `start`. Once its `end` is past, an event counts as done.

### `GET` / `PUT /v1/feed-settings` (the calendar feed list, shared)
The calendar feeds (the FH timetable, Moodle, any iCal address) and which of their courses are hidden are **the same list on both devices**: adding, renaming or removing a feed, or ticking a course, on either one reaches the other. Each device **downloads the feeds itself** from their servers; only this list travels. So the phone keeps its timetable up to date away from the PC (on mobile data too), and its changes wait until the PC can be reached. Only while the last ping listed `feeds`; otherwise `404`. Same checks and errors as `/v1/items`.

Both answer `200`:

```json
{
  "feeds": [
    { "id": "3f2a…", "url": "https://almaty.fh-joanneum.at/stundenplan/search.php?q=Met26", "name": "Met26",
      "kind": "timetable", "removed": false, "updatedAt": "2026-10-01T09:00:00.000Z" },
    { "id": "77c1…", "url": null, "name": "Old Moodle", "kind": "moodle", "removed": true, "updatedAt": "2026-10-20T08:00:00.000Z" }
  ],
  "courses": [
    { "feedId": "3f2a…", "key": "mobility infrastructure", "hidden": true, "updatedAt": "2026-10-02T10:00:00.000Z" }
  ],
  "serverTime": "2026-11-02T12:00:00.000Z"
}
```
- `feeds`: every feed, and the ones removed in the last 90 days (`removed: true`, `url` null) so the phone removes them too.
  - `url`: the address, normalised (`webcal://` becomes `https://`; only https). **It is a secret** (a Moodle address holds a token): the phone keeps it in secure storage and shows only its host. It only ever travels inside the pinned connection (section 2).
  - `kind`: `timetable`, `moodle` or `calendar`, from the program that made the feed (its `PRODID`). It decides how events are read; a feed not downloaded yet on the PC says `calendar`.
- `courses`: each course the user hid, and each one shown again after being hidden. `key` is the course name in lowercase with runs of spaces made one (the course name is what `course` says in `GET /v1/calendar`: an exam carries its course's name). A course not listed is shown.
- `updatedAt`: when that feed (its address, name or removal) or that course choice last changed.

`PUT` sends the phone's changes in the same shape (only what changed; both lists optional) and gets the merged list back:
- **Each feed and each course choice is decided on its own: the newer `updatedAt` wins**, equal keeps the PC's. A time more than a minute in the PC's future counts as the PC's now.
- A feed with an id the PC does not know is added (the PC downloads it next). **One whose `url` the PC already has under another id is not added: the answer lists the PC's id, and the phone takes that one** (drops its own id and keeps the feed under the PC's).
- A malformed list (a feed without a valid id, `updatedAt` or https `url`) is `422` and changes nothing.
- **The answer is the whole list: the phone replaces its own with it** (feeds it does not list are gone) and downloads every feed that is new or has a new address.

How a feed's events are read is the same on both devices, so a course is named the same everywhere and a hidden course is hidden everywhere: an event's id is `feed:<feed id>|<UID>` (a repeating event's occurrences: `<UID>|<original start>`), and lectures, exams and other events are told apart as DeskPlan does (FH timetable summaries, `Prüfungstermin:` exams). A changed occurrence (`RECURRENCE-ID`) replaces the one it moves; a cancelled one is left out. Moodle due dates are not calendar events on the phone either: the PC turns them into assignments, which sync as items.

While the last ping listed `feeds`, the phone does not use `GET /v1/calendar` (it has the events from the feeds themselves) and forgets the events it got from it.

## 6. Queue and retry rules for the phone

- **Queue actions, not lists:** "save this item", "delete this item", "upload this file". Without a queued delete, a deleted item would come back at the next sync.
- Remove an action only after a success answer, `200` or `201` (for a file, also check that the returned `sha256` matches).
- Copy a shared file into the app's own storage immediately: the original link may expire.
- Retry with backoff on network errors and `503`. Retries are safe: the same `uploadId`, the same item body.
- Do **not** keep retrying `422` or `413`: show the problem to the user.

## 7. Error codes

| Status | `error` | Meaning | What the phone should do |
|---|---|---|---|
| 401 | `bad-token` | Unknown, revoked or expired token | Stop. "No longer paired": ask to pair again |
| 403 | `receiving-off` | Receiving is switched off on the PC | Keep queued. Show "Receiving is off on your PC" |
| 403 | `awaiting-approval` | Paired, but not approved yet on the PC | Keep queued. Show "Waiting for approval" |
| 404 | `not-found` | Unknown path (also `GET /v1/items` on a DeskPlan older than the pull, `GET /v1/calendar` on one older than the calendar) | Bug, or the PC is too old for that feature; do not retry |
| 405 | `method` | Wrong HTTP method | Bug; do not retry |
| 413 | `too-large` | File over 100 MB (or item body over 1 MB) | Do not retry. Tell the user |
| 422 | `invalid-request` | Bad id, header, JSON, time, or a rule of section 4 | Do not retry. It is a bug, bad data or a rule break |
| 422 | `unsupported-type` | The file type is not accepted, or a link file that does not point at a web address | Do not retry. Tell the user which types DeskPlan takes |
| 422 | `unknown-destination` | `X-Dest-Id` is not offered, or that folder no longer exists | Do not retry. Refresh the destination list and let the user pick again (or send to Received files) |
| 422 | `checksum-mismatch` | Bytes do not match `X-File-Sha256` | Retry once; then show an error |
| 422 | `not-syncable` | That id is a folder or file on the PC | Do not retry. Tell the user |
| 503 | `busy` | Too many uploads at once | Retry with backoff |
| 503 | `app-not-ready` / `unavailable` | DeskPlan is starting or cannot take item changes right now | Retry with backoff |
| 500 | `server-error` | Unexpected problem on the PC | Retry later |

A refused connection or a timeout usually means DeskPlan is closed, receiving has never been switched on, or the network blocks it. When receiving is switched off the server normally still runs, so expect `403 receiving-off` rather than a refused connection (but not before receiving was ever switched on).

## 8. Limits: what the phone can send

**Files (one file per request):**

| | |
|---|---|
| Types | **Documents, images and links only**, chosen by file extension (any letter case): documents `pdf doc docx odt rtf txt md ppt pptx odp xls xlsx ods csv epub`; images `png jpg jpeg gif webp bmp heic heif avif tif tiff`; links `url`. Programs, scripts, installers (`.exe`, `.apk`, `.msi`, `.bat`...), archives (`.zip`...), web pages (`.html`), macro files (`.docm`...), `.svg` and files with no extension are refused with `422 unsupported-type`. The exact list is `allowedExtensions` in the ping answer. |
| Links | A Windows Internet Shortcut file, `Name.url`, containing exactly `[InternetShortcut]` then `URL=https://...` (at most 16 KB; either line ending works). Every address in it must start with `http://` or `https://`; anything else (a file path, `file:`, `javascript:`...) is refused. A web link shared from a browser should be saved by the phone as such a file. |
| Size | **100 MB per file**, checked from `Content-Length` before the upload starts (`413 too-large`). |
| Upload style | One file per `PUT`, exact `Content-Length`. No chunked or resumable uploads; a failed upload starts again from the beginning. Up to 4 uploads at once; more get `503 busy`. |
| Names | Cleaned by the PC: folder parts and `..` removed, characters Windows rejects (`< > : " | ? *` and control characters) replaced by `_`, reserved names (`CON`, `NUL`...) get a `_` in front, at most 150 characters (the extension is kept). A taken name becomes `name (1).ext`. `storedAs` is the final name. |
| Integrity | SHA-256 of the bytes, checked by the PC. A mismatch is `422 checksum-mismatch` and nothing is kept. |
| Destinations | Received files (`received-files`, formerly `inbox`), or any DeskPlan folder. Not notes, items or single files. |
| Not supported | Sending a *folder* of files in one request; creating or renaming folders on the PC; reaching the PC away from the local network (the phone queues). |

**Items:** ids and fields are in section 4; a request is at most 1 MB (a task's or assignment's `description` is still at most 16,000 characters). The phone pushes with `PUT` and `DELETE` and pulls with `GET /v1/items?since=`; the PC sends nothing by itself.

**Everything:** the phone can only reach the PC while the PC is on, DeskPlan is running, receiving is switched on, the phone is approved, and the phone is on the same network. There is no way to wake the PC.
