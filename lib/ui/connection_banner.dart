import 'package:flutter/material.dart';

import '../features/connection/unreachable_cause.dart';
import 'theme/deskplan_colors.dart';

/// A strip under the app bar saying why DeskPlan cannot be reached, with a
/// "Pair again" button when scanning a new code is the fix. The colour says
/// how serious it is: amber means wait or check the PC, red means act here.
class ConnectionBanner extends StatelessWidget {
  final UnreachableCause cause;
  final String message;

  /// How many changes are still waiting to reach DeskPlan.
  final int waiting;

  /// Opens the pairing screen.
  final VoidCallback onPair;

  const ConnectionBanner({
    super.key,
    required this.cause,
    required this.message,
    required this.waiting,
    required this.onPair,
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(fontSize: 13, color: c.text)),
                if (waiting > 0)
                  Text(
                    '$waiting ${waiting == 1 ? 'change' : 'changes'} '
                    'waiting to sync',
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
              ],
            ),
          ),
          if (cause.needsPairing)
            TextButton(
              onPressed: onPair,
              child: Text(
                cause == UnreachableCause.notPaired ? 'Pair' : 'Pair again',
              ),
            ),
        ],
      ),
    );
  }
}
