import 'package:flutter/material.dart';

import '../features/connection/unreachable_cause.dart';
import 'theme/deskplan_colors.dart';

/// A small pill in the app bar, between the page's name and the link icon,
/// saying why DeskPlan cannot be reached and how many changes wait
/// ("Can't reach DeskPlan at 192.168.1.184 / 7 waiting"). Tap it for the
/// connection (to pair again when that is the fix). The colour says how
/// serious it is: amber means wait or check the PC, red means act here.
class ConnectionBanner extends StatelessWidget {
  final UnreachableCause cause;
  final String message;

  /// How many changes are still waiting to reach DeskPlan.
  final int waiting;

  /// Opens the connection (pairing) screen.
  final VoidCallback onTap;

  const ConnectionBanner({
    super.key,
    required this.cause,
    required this.message,
    required this.waiting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final color = cause.needsPairing ? c.danger : c.warn;
    final icon = switch (cause) {
      UnreachableCause.awaitingApproval => Icons.hourglass_empty,
      UnreachableCause.receivingOff => Icons.pause_circle_outline,
      UnreachableCause.cannotReach ||
      UnreachableCause.noAddress => Icons.wifi_off,
      _ => Icons.link_off,
    };
    final second = [
      if (cause.needsPairing)
        cause == UnreachableCause.notPaired
            ? 'Tap to pair'
            : 'Tap to pair again',
      if (waiting > 0) '$waiting waiting to sync',
    ].join(' · ');
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 14, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: c.text,
                      ),
                    ),
                    if (second.isNotEmpty)
                      Text(
                        second,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          color: c.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
