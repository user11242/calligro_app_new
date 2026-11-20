import 'dart:async';

import 'package:calligro_app/features/courses/application/join_lock.dart';
import 'package:calligro_app/features/courses/data/firestore_app_features.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(JoinLock.reset);

  const locked = JoinCheck(JoinStatus.opensLater);
  const open = JoinCheck(JoinStatus.open);

  test('missing or anything but an explicit false = ON (the normal lock)', () {
    expect(JoinLock.enabledFrom(null), isTrue);
    expect(JoinLock.enabledFrom(const {}), isTrue);
    expect(JoinLock.enabledFrom(const {'joinLock': true}), isTrue);
    expect(JoinLock.enabledFrom(const {'joinLock': 'no'}), isTrue);
    expect(JoinLock.enabledFrom(const {'joinLock': false}), isFalse);
  });

  test('ON: the class-time lock applies; OFF: never locked (course page and home)', () {
    expect(JoinLock.apply(locked).canJoin, isFalse);
    expect(JoinLock.homeButtonEnabled(locked), isFalse);
    expect(JoinLock.homeButtonEnabled(open), isTrue);

    JoinLock.enabled.value = false;
    expect(JoinLock.apply(locked).canJoin, isTrue);
    expect(JoinLock.homeButtonEnabled(locked), isTrue);
    expect(JoinLock.homeButtonEnabled(const JoinCheck(JoinStatus.ended)), isTrue);
  });

  test('follows the admin switch LIVE; an error keeps the last value', () async {
    final source = StreamController<Map<String, dynamic>?>();
    JoinLock.start(source.stream);
    source.add({'joinLock': false});
    await pumpEventQueue();
    expect(JoinLock.enabled.value, isFalse);
    source.addError(Exception('offline'));
    await pumpEventQueue();
    expect(JoinLock.enabled.value, isFalse);
    source.add({'joinLock': true});
    await pumpEventQueue();
    expect(JoinLock.enabled.value, isTrue);
    await source.close();
  });

  test('end to end with the database: the admin turns it off, every app follows', () async {
    final db = FakeFirebaseFirestore();
    final features = FirestoreAppFeatures(firestore: db);
    JoinLock.start(features.watch());
    await pumpEventQueue();
    expect(JoinLock.enabled.value, isTrue, reason: 'no document yet → normal lock');
    await features.setJoinLock(false);
    await pumpEventQueue();
    expect(JoinLock.enabled.value, isFalse);
    expect((await db.doc('app_config/features').get()).data()!['joinLock'], isFalse);
    await features.setJoinLock(true);
    await pumpEventQueue();
    expect(JoinLock.enabled.value, isTrue);
  });
}
