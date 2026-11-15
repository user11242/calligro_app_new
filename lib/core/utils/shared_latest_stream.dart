import 'dart:async';

/// One subscription to [source], shared by any number of listeners; each new
/// listener first gets the latest value (like a fresh Firestore listen would).
/// Call [dispose] when the owner goes away.
class SharedLatestStream<T> {
  SharedLatestStream(Stream<T> source) {
    _sub = source.listen((v) {
      _latest = v;
      _hasValue = true;
      _out.add(v);
    }, onError: _out.addError);
  }

  final _out = StreamController<T>.broadcast(sync: true);
  late final StreamSubscription<T> _sub;
  T? _latest;
  bool _hasValue = false;

  Stream<T> get stream => Stream<T>.multi((c) {
        if (_hasValue) c.add(_latest as T);
        final s = _out.stream.listen(c.add, onError: c.addError);
        c.onCancel = s.cancel;
      });

  Future<void> dispose() async {
    await _sub.cancel();
    await _out.close();
  }
}
