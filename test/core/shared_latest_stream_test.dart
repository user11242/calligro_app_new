import 'dart:async';

import 'package:calligro_app/core/utils/shared_latest_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('many listeners, one source subscription, late listeners get the latest value', () async {
    var listens = 0;
    final source = StreamController<int>(onListen: () => listens++);
    final shared = SharedLatestStream(source.stream);
    final a = <int>[], b = <int>[];
    shared.stream.listen(a.add);
    source.add(1);
    await Future<void>.delayed(Duration.zero);
    shared.stream.listen(b.add);
    await Future<void>.delayed(Duration.zero);
    source.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(a, [1, 2]);
    expect(b, [1, 2]);
    expect(listens, 1);
    await shared.dispose();
    expect(source.hasListener, isFalse);
  });
}
