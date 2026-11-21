import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sync_pill.dart';
import 'theme/deskplan_colors.dart';

/// Pull down to sync, with the dots pill at the top in place of Material's
/// round spinner: "Pull to sync" while pulling, "Release to sync" once far
/// enough, then [label] with the dots moving until [onRefresh] is done.
///
/// Material's RefreshIndicator fires after a short pull (about a sixth of
/// the screen) and that distance can't be changed, so this follows the drag
/// itself and asks for a longer, deliberate pull: [pullFraction] of the
/// list's height, and never less than [minPull].
///
/// [child] must always be scrollable (even when short), or the pull does
/// nothing.
class SyncRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  /// What it says while syncing: "Syncing with Office-PC…".
  final String label;

  /// How far to pull, as a share of the list's height.
  final double pullFraction;

  /// The shortest pull that syncs, in logical pixels.
  final double minPull;

  const SyncRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.label = 'Syncing with DeskPlan…',
    this.pullFraction = 0.35,
    this.minPull = 200,
  });

  @override
  State<SyncRefresh> createState() => _SyncRefreshState();
}

class _SyncRefreshState extends State<SyncRefresh> {
  /// How far the current pull has gone, or null when there is none.
  double? _pulled;

  /// The pull needed to sync, for the list's current height.
  double _needed = 200;
  bool _busy = false;

  bool get _armed => (_pulled ?? 0) >= _needed;

  Future<void> _run() async {
    setState(() {
      _pulled = null;
      _busy = true;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _stop() {
    if (_pulled != null) setState(() => _pulled = null);
  }

  void _pull(double by, ScrollMetrics m) {
    final pulled = (_pulled ?? 0) + by;
    if (pulled < 0) return _stop(); // Scrolling into the list instead.
    _needed = math.max(
      widget.minPull,
      m.viewportDimension * widget.pullFraction,
    );
    setState(() => _pulled = pulled);
  }

  void _release() => _armed ? _run() : _stop();

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollStartNotification) {
      // Only a finger drag that starts at the very top.
      if (!_busy && n.dragDetails != null && n.metrics.extentBefore == 0) {
        setState(() => _pulled = 0);
      }
    } else if (_pulled == null) {
      return false;
    } else if (n is OverscrollNotification) {
      // Android's list stays put at the top; the pull arrives as overscroll.
      if (n.dragDetails == null) return false;
      _pull(-n.overscroll, n.metrics);
    } else if (n is ScrollUpdateNotification) {
      if (n.dragDetails == null) {
        _release(); // Let go while the list bounces back (iOS-style lists).
      } else {
        _pull(-(n.scrollDelta ?? 0), n.metrics);
      }
    } else if (n is ScrollEndNotification) {
      _release();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final pulled = _pulled ?? 0;
    // Hidden for the first few pixels, so an ordinary scroll at the top
    // does not flash it.
    final pulling = pulled > 12;
    final shown = _busy || pulling;
    final progress = (pulled / _needed).clamp(0.0, 1.0);
    final label = _busy
        ? widget.label
        : _armed
        ? 'Release to sync'
        : 'Pull to sync';
    return Stack(
      children: [
        NotificationListener<OverscrollIndicatorNotification>(
          // No stretch or glow while the pull is for syncing.
          onNotification: (n) {
            if (n.leading && _pulled != null) n.disallowIndicator();
            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
        Positioned(
          top: 10,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Center(
              child: AnimatedSlide(
                offset: shown ? Offset.zero : const Offset(0, -0.6),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  // Fills in as the pull nears the point where it syncs.
                  opacity: _busy || _armed
                      ? 1
                      : shown
                      ? 0.35 + 0.4 * progress
                      : 0,
                  duration: const Duration(milliseconds: 120),
                  child: SyncPill(
                    label: label,
                    color: c.accent,
                    animate: _busy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
