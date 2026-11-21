/// How many of something are finished: an assignment's steps, or a note's
/// checklist lines. One type for both, so every screen shows and colours
/// progress the same way (see `ProgressCount`).
class Progress {
  final int done;
  final int total;

  const Progress(this.done, this.total);

  static const none = Progress(0, 0);

  /// Nothing to finish (no steps, no checklist).
  bool get isEmpty => total == 0;

  /// Everything there is, is finished.
  bool get isComplete => total > 0 && done == total;

  /// 0 to 1, for a progress bar.
  double get fraction => isEmpty ? 0 : done / total;

  @override
  bool operator ==(Object other) =>
      other is Progress && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => '$done/$total';
}
