/// Where a queued file is in its life.
enum UploadStatus {
  /// Waiting to be sent (or to be tried again).
  waiting,

  /// DeskPlan refused it, or it ran out of tries. Shown with the reason; the
  /// user can retry or delete it.
  failed,

  /// DeskPlan has it. Kept as a short history.
  sent,
}
