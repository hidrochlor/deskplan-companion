import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three dots that swell and brighten in turn, left to right: the app's
/// "working on it" mark, in place of a spinner. Still and dim when
/// [animate] is false.
class SyncDots extends StatefulWidget {
  final Color color;
  final bool animate;

  /// The size of a dot at its biggest.
  final double size;

  const SyncDots({
    super.key,
    required this.color,
    this.animate = true,
    this.size = 7,
  });

  @override
  State<SyncDots> createState() => _SyncDotsState();
}

class _SyncDotsState extends State<SyncDots>
    with SingleTickerProviderStateMixin {
  late final _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _wave.repeat();
  }

  @override
  void didUpdateWidget(SyncDots old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_wave.isAnimating) _wave.repeat();
    if (!widget.animate && _wave.isAnimating) _wave.stop();
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  /// 0 to 1 for dot [i]: a bump that passes over each dot a third of a turn
  /// after the one before.
  double _lift(int i) {
    if (!widget.animate) return 0;
    final t = (_wave.value - i / 3) % 1;
    return t < 0.5 ? math.sin(t * 2 * math.pi) : 0;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _wave,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              SizedBox.square(
                dimension: s + 3,
                child: Center(
                  child: Container(
                    width: s * (0.72 + 0.28 * _lift(i)),
                    height: s * (0.72 + 0.28 * _lift(i)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(
                        alpha: 0.4 + 0.6 * _lift(i),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
