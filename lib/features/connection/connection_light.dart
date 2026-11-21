import 'unreachable_cause.dart';

/// The state shown by the dot on the connection icon. It follows the phone
/// icon on DeskPlan's own top bar, so both sides read the same way.
enum ConnectionLight {
  /// Not paired with any PC yet.
  off,

  /// Paired, but DeskPlan was not reached the last time (PC off, other
  /// Wi-Fi). Nothing to fix; it connects when the PC is there.
  idle,

  /// DeskPlan answered the last time.
  connected,

  /// Something needs a look on the PC: approve this phone, switch receiving
  /// on, or DeskPlan is busy.
  attention,

  /// This phone must be paired again (revoked, or the PC's identity changed).
  problem;

  /// [cause] is why the last sync failed, or null if it did not fail.
  /// [reached] is true when DeskPlan answered the last time.
  static ConnectionLight from({
    required UnreachableCause? cause,
    required bool reached,
  }) {
    if (cause == null) return reached ? connected : idle;
    return switch (cause) {
      UnreachableCause.notPaired => off,
      UnreachableCause.noAddress || UnreachableCause.cannotReach => idle,
      UnreachableCause.awaitingApproval ||
      UnreachableCause.receivingOff ||
      UnreachableCause.other => attention,
      UnreachableCause.unpaired || UnreachableCause.identityChanged => problem,
    };
  }

  /// What the icon's tooltip says.
  String get description => switch (this) {
    off => 'Not paired with DeskPlan',
    idle => 'Paired. DeskPlan is not reachable right now',
    connected => 'Connected to DeskPlan',
    attention => 'DeskPlan needs attention on your PC',
    problem => 'Pair this phone with DeskPlan again',
  };
}
