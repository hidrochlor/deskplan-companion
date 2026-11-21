import 'package:flutter/material.dart';

import '../features/feeds/feed_fetcher.dart';
import '../features/feeds/feed_mappers.dart';
import '../features/feeds/feed_service.dart';
import '../features/feeds/phone_feed.dart';
import '../features/queue/sync_service.dart';
import 'sync_dots.dart';
import 'theme/deskplan_colors.dart';

/// Settings › Timetables and courses: the calendar feeds (the FH timetable,
/// Moodle, any iCal link) and which of their courses show. The same list as
/// on the PC (Settings › Data › Calendar feeds): a change here reaches
/// DeskPlan at the next sync, and the phone downloads the feeds itself, so
/// the timetable updates away from the PC too.
class FeedsScreen extends StatefulWidget {
  final FeedService feeds;
  final SyncService sync;

  const FeedsScreen({super.key, required this.feeds, required this.sync});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  List<PhoneFeed> _list = const [];
  final _courses = <String, List<FeedCourse>>{};
  final _busy = <String>{};

  /// The feed whose course list is open.
  String? _open;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.feeds.store.active();
    final courses = <String, List<FeedCourse>>{};
    for (final f in list) {
      courses[f.id] = await widget.feeds.courses(f.id);
    }
    if (!mounted) return;
    setState(() {
      _list = list;
      _courses
        ..clear()
        ..addAll(courses);
      _loaded = true;
    });
  }

  /// Saves and sends: the change reaches DeskPlan as soon as it is reachable.
  Future<void> _changed() async {
    await _load();
    widget.sync.syncNow();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _AddFeedDialog(),
    );
    if (url == null || url.trim().isEmpty || !mounted) return;
    setState(() => _busy.add('new'));
    try {
      final feed = await widget.feeds.add(url);
      _toast('${feed.name} added: ${feed.count} events');
      if ((await widget.feeds.courses(feed.id)).isNotEmpty) _open = feed.id;
      await _changed();
    } on FeedFetchError catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove('new'));
    }
  }

  Future<void> _refresh(PhoneFeed f) async {
    setState(() => _busy.add(f.id));
    final problem = await widget.feeds.refresh(f.id);
    if (!mounted) return;
    setState(() => _busy.remove(f.id));
    if (problem != null) _toast(problem);
    await _load();
  }

  Future<void> _rename(PhoneFeed f) async {
    // The dialog owns its controller: disposing it here, while the dialog
    // is still animating out, is what turned Cancel into a red screen.
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: f.name),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await widget.feeds.rename(f.id, name);
    await _changed();
  }

  Future<void> _remove(PhoneFeed f) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${f.name}?'),
        content: const Text(
          'Its lectures and exams leave the calendar, here and on your PC. '
          'Assignments it brought stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await widget.feeds.remove(f.id);
    await _changed();
  }

  Future<void> _setHidden(
    String feedId,
    Iterable<String> keys,
    bool hidden,
  ) async {
    await widget.feeds.setHidden(feedId, keys, hidden);
    await _changed();
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Timetables and courses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy.contains('new') ? null : _add,
        icon: _busy.contains('new')
            ? SyncDots(color: c.onAccent, size: 6)
            : const Icon(Icons.add_link),
        label: const Text('Add iCal link'),
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'Your FH timetable, Moodle or any iCal link. The same list '
                    'as on your PC: changes here reach DeskPlan at the next '
                    'sync. This phone downloads them itself, so the timetable '
                    'stays up to date away from your PC.',
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ),
                if (_list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No calendars yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted),
                    ),
                  ),
                for (final f in _list) ...[
                  _FeedCard(
                    feed: f,
                    courses: _courses[f.id] ?? const [],
                    busy: _busy.contains(f.id),
                    open: _open == f.id,
                    onToggleOpen: () =>
                        setState(() => _open = _open == f.id ? null : f.id),
                    onRefresh: () => _refresh(f),
                    onRename: () => _rename(f),
                    onRemove: () => _remove(f),
                    onHidden: (keys, hidden) => _setHidden(f.id, keys, hidden),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final PhoneFeed feed;
  final List<FeedCourse> courses;
  final bool busy;
  final bool open;
  final VoidCallback onToggleOpen;
  final VoidCallback onRefresh;
  final VoidCallback onRename;
  final VoidCallback onRemove;
  final void Function(Iterable<String> keys, bool hidden) onHidden;

  const _FeedCard({
    required this.feed,
    required this.courses,
    required this.busy,
    required this.open,
    required this.onToggleOpen,
    required this.onRefresh,
    required this.onRename,
    required this.onRemove,
    required this.onHidden,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final loc = MaterialLocalizations.of(context);
    final last = feed.lastFetched?.toLocal();
    final status =
        feed.lastError ??
        (last == null
            ? 'Not downloaded yet'
            : 'Updated ${loc.formatShortMonthDay(last)}, '
                  '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(last), alwaysUse24HourFormat: true)}');
    final shown = courses.where((x) => !x.hidden).length;
    final icon = switch (feed.kind) {
      FeedKind.timetable => Icons.calendar_view_week_outlined,
      FeedKind.moodle => Icons.school_outlined,
      FeedKind.calendar => Icons.event_outlined,
    };
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feed.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${feed.host} · $status',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: feed.lastError != null ? c.danger : c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SyncDots(color: c.accent, size: 6),
                  )
                else
                  IconButton(
                    tooltip: 'Download again',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) => v == 'rename' ? onRename() : onRemove(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ],
            ),
            if (courses.isNotEmpty)
              TextButton.icon(
                onPressed: onToggleOpen,
                icon: Icon(open ? Icons.expand_less : Icons.expand_more),
                label: Text('Courses: $shown of ${courses.length} shown'),
              ),
            if (open && courses.isNotEmpty) ...[
              Row(
                children: [
                  TextButton(
                    onPressed: () => onHidden(courses.map((x) => x.key), false),
                    child: const Text('Show all'),
                  ),
                  TextButton(
                    onPressed: () => onHidden(courses.map((x) => x.key), true),
                    child: const Text('Hide all'),
                  ),
                ],
              ),
              for (final course in courses)
                CheckboxListTile(
                  contentPadding: const EdgeInsets.only(right: 8),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  value: !course.hidden,
                  title: Text(course.name),
                  subtitle: Text(_counts(course)),
                  onChanged: (v) => onHidden([course.key], v == false),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "12 lectures · 1 exam to come".
String _counts(FeedCourse course) {
  final parts = [
    '${course.lectures} ${course.lectures == 1 ? 'lecture' : 'lectures'}',
    if (course.exams > 0)
      '${course.exams} ${course.exams == 1 ? 'exam' : 'exams'}',
  ];
  return '${parts.join(' · ')} to come';
}

/// Asks for an iCal address: pasted, or typed.
class _RenameDialog extends StatefulWidget {
  final String initial;

  const _RenameDialog({required this.initial});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename'),
    content: TextField(
      controller: _name,
      autofocus: true,
      maxLength: 200,
      decoration: const InputDecoration(counterText: ''),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _name.text),
        child: const Text('Save'),
      ),
    ],
  );
}

class _AddFeedDialog extends StatefulWidget {
  const _AddFeedDialog();

  @override
  State<_AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<_AddFeedDialog> {
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a calendar'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paste the iCal (webcal or https) link of a timetable or Moodle '
          'calendar. For a course in another timetable group (a language '
          'course, say), use that group\'s own link.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _url,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Calendar address',
            hintText: 'webcal://…',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _url.text),
        child: const Text('Add'),
      ),
    ],
  );
}
