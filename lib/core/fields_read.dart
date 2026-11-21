import 'dart:collection';

/// The keys [parse] looks at (reads or checks for) when it reads [samples].
///
/// Used to know which of DeskPlan's fields the phone reads without keeping a
/// list by hand: [Task.syncFields] watches Task.fromSyncJson read a few
/// sample items, so a field read there is known here the moment it is added.
Set<String> fieldsRead(
  void Function(Map<String, Object?> json) parse,
  List<Map<String, Object?>> samples,
) {
  final asked = <String>{};
  for (final sample in samples) {
    final json = _Recording(sample, asked);
    parse(json);
  }
  return Set.unmodifiable(asked);
}

/// A map that notes every key asked about, present or not.
class _Recording extends MapBase<String, Object?> {
  final Map<String, Object?> _inner;
  final Set<String> _asked;
  _Recording(this._inner, this._asked);

  @override
  Object? operator [](Object? key) {
    if (key is String) _asked.add(key);
    return _inner[key];
  }

  @override
  bool containsKey(Object? key) {
    if (key is String) _asked.add(key);
    return _inner.containsKey(key);
  }

  @override
  void operator []=(String key, Object? value) => _inner[key] = value;
  @override
  void clear() => _inner.clear();
  @override
  Iterable<String> get keys => _inner.keys;
  @override
  Object? remove(Object? key) => _inner.remove(key);
}
