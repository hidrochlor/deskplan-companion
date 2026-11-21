/// How long to wait before the next try: 30 s, 1 min, 2 min, 4 min ...
/// never more than 1 hour. Waiting longer after each failure avoids
/// hammering a PC that is off or a network that is down.
class Backoff {
  static const _first = Duration(seconds: 30);
  static const _max = Duration(hours: 1);

  /// [attempts] is how many tries have failed so far (1 for the first failure).
  static Duration delayFor(int attempts) {
    if (attempts < 1) return Duration.zero;
    if (attempts > 7) return _max; // 30 s * 2^7 is already over an hour
    final delay = _first * (1 << (attempts - 1));
    return delay > _max ? _max : delay;
  }
}
