/// Why the phone cannot use DeskPlan right now. The screen picks its message,
/// colour and button from this (docs/protocol.md sections 1, 3, 7).
enum UnreachableCause {
  /// No pairing saved: scan the QR code on the PC.
  notPaired,

  /// Paired, but no address to try.
  noAddress,

  /// Network problem: PC off, other Wi-Fi, DeskPlan closed.
  cannotReach,

  /// The certificate is not the one in the QR code. Pair again.
  identityChanged,

  /// `401 bad-token`: the PC revoked this phone, or the code expired.
  unpaired,

  /// `403 awaiting-approval`: approve this phone on the PC.
  awaitingApproval,

  /// `403 receiving-off`: receiving is switched off on the PC.
  receivingOff,

  /// DeskPlan is busy, starting, or answered something unexpected.
  other;

  /// True when the fix is to scan a new QR code.
  bool get needsPairing =>
      this == notPaired || this == unpaired || this == identityChanged;
}
