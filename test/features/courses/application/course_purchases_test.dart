import 'package:calligro_app/features/courses/application/course_purchases.dart';
import 'package:calligro_app/features/courses/domain/course_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/course_fixtures.dart';
import '../fakes/fake_courses.dart';

/// The ONE app-wide purchase flow: buy → server enrols → only then finish.
void main() {
  late FakeStore store;
  late FakeEnrollment server;
  late MemoryIntentStore intents;
  var uid = 's1';

  final a = courseDoc('A'); // tier_100
  final b = courseDoc('B'); // tier_100 too — same product, different course
  final cheap = courseDoc('C', price: 60, iapProductId: 'com.yazan.calligro.tier_60');
  final free = courseDoc('F', price: 0);
  const tier100 = 'com.yazan.calligro.tier_100';

  CoursePurchases make() =>
      CoursePurchases(store: store, enrollment: server, intents: intents, currentUid: () => uid)..start();

  setUp(() {
    store = FakeStore();
    server = FakeEnrollment();
    intents = MemoryIntentStore();
    uid = 's1';
  });

  test('start() asks the store to re-deliver unfinished purchases', () async {
    make();
    await pumpEventQueue();
    expect(store.restores, 1);
  });

  test('buy → the course\'s product; server enrols; THEN the purchase is finished', () async {
    final p = make();
    await p.buy(a);
    expect(store.bought, [tier100]);
    expect(p.statusOf('A').stage, PurchaseStage.buying);
    store.deliver(tier100);
    await pumpEventQueue();
    expect(server.verifications.single, (courseId: 'A', productId: tier100, data: 'receipt', platform: 'ios'));
    expect(store.finished, hasLength(1));
    expect(p.statusOf('A').stage, PurchaseStage.enrolled);
    expect(intents.saved, isEmpty);
  });

  test('server verification fails → NOT finished, kept for retry; retry finishes it', () async {
    final p = make();
    await p.buy(a);
    server.crash = Exception('network down');
    store.deliver(tier100);
    await pumpEventQueue();
    expect(store.finished, isEmpty, reason: 'the student paid — the store must re-deliver it');
    expect(p.statusOf('A').stage, PurchaseStage.failed);
    expect(intents.saved, contains(tier100));

    server.crash = null;
    await p.retry('A');
    await pumpEventQueue();
    expect(store.finished, hasLength(1));
    expect(p.statusOf('A').stage, PurchaseStage.enrolled);
  });

  test('THE REVIEW BUG: cancel A, then buy B (same price) → only B is enrolled', () async {
    final p = make();
    await p.buy(a);
    store.cancel(tier100);
    await pumpEventQueue();
    expect(p.statusOf('A').stage, PurchaseStage.cancelled);
    await p.buy(b);
    store.deliver(tier100);
    await pumpEventQueue();
    expect(server.verifications.map((v) => v.courseId), ['B'], reason: 'one verification, for the right course');
  });

  test('buying B after an abandoned A (no cancel event) still verifies only B', () async {
    final p = make();
    await p.buy(a);
    await p.buy(b); // A's sheet was closed without an event; B replaces the intent
    store.deliver(tier100);
    await pumpEventQueue();
    expect(server.verifications.map((v) => v.courseId), ['B']);
  });

  test('a SECOND service (e.g. a stale screen) never exists: the app shares one instance', () {
    // Guard: CoursePurchases is created once in CourseServices (see courses_guardrails_test).
    expect(make(), isA<CoursePurchases>());
  });

  test('after a crash / restart, a re-delivered purchase is verified for the remembered course', () async {
    final beforeCrash = make();
    await beforeCrash.buy(a); // intent saved, then the app dies before the store answers
    beforeCrash.dispose();
    final afterRestart = make(); // same persistent intent store
    store.deliver(tier100);
    await pumpEventQueue();
    expect(server.verifications.single.courseId, 'A');
    expect(store.finished, hasLength(1));
    expect(afterRestart.statusOf('A').stage, PurchaseStage.enrolled);
  });

  test('a re-delivered purchase with no remembered course is left unfinished (never guessed)', () async {
    make();
    store.deliver(tier100);
    await pumpEventQueue();
    expect(server.verifications, isEmpty);
    expect(store.finished, isEmpty);
  });

  test('a purchase remembered for ANOTHER signed-in user waits for that user', () async {
    final first = make();
    await first.buy(a);
    first.dispose();
    uid = 's2';
    make();
    store.deliver(tier100);
    await pumpEventQueue();
    expect(server.verifications, isEmpty);
    expect(store.finished, isEmpty);
  });

  test('"purchase already used" from the server → finished (it is spent) and reported', () async {
    final p = make();
    await p.buy(a);
    server.refuse = const EnrollmentException('already-exists', 'This purchase was already used.');
    store.deliver(tier100);
    await pumpEventQueue();
    expect(store.finished, hasLength(1));
    expect(p.statusOf('A').stage, PurchaseStage.failed);
    expect(p.statusOf('A').code, 'already-exists');
  });

  test('other refusals (e.g. commission not set) → NOT finished, so it can be retried', () async {
    final p = make();
    await p.buy(a);
    server.refuse = const EnrollmentException('failed-precondition', 'Teacher commission rate is not set.');
    store.deliver(tier100);
    await pumpEventQueue();
    expect(store.finished, isEmpty);
    expect(p.statusOf('A').code, 'failed-precondition');
  });

  test('a store error clears the intent and reports failure', () async {
    final p = make();
    await p.buy(cheap);
    store.fail('com.yazan.calligro.tier_60', 'Payment declined');
    await pumpEventQueue();
    expect(p.statusOf('C').stage, PurchaseStage.failed);
    expect(intents.saved, isEmpty);
  });

  test('refused before reaching the store: guests, owners, enrolled, full, free courses', () async {
    final p = make();
    uid = '';
    expect(await p.buy(a), BuyResult.needsAccount);
    uid = 't1';
    expect(await p.buy(a), BuyResult.notAllowed, reason: 'own course');
    uid = 's1';
    expect(await p.buy(courseDoc('E', enrolled: ['s1'])), BuyResult.notAllowed);
    expect(await p.buy(courseDoc('X', enrolled: ['a', 'b', 'c'])), BuyResult.notAllowed);
    expect(await p.buy(free), BuyResult.notAllowed, reason: 'free courses use enrollFree');
    expect(store.bought, isEmpty);
  });

  test('a second tap while buying is ignored', () async {
    final p = make();
    await p.buy(a);
    expect(await p.buy(a), BuyResult.busy);
    expect(store.bought, hasLength(1));
  });

  test('the store refusing to open → failed, intent cleared', () async {
    store.failBuy = Exception('Store unavailable');
    final p = make();
    expect(await p.buy(a), BuyResult.failed);
    expect(p.statusOf('A').stage, PurchaseStage.failed);
    expect(intents.saved, isEmpty);
  });

  group('free courses', () {
    test('enrol through the server', () async {
      final p = make();
      expect(await p.enrollFree(free), BuyResult.started);
      await pumpEventQueue();
      expect(server.freeEnrolments, ['F']);
      expect(p.statusOf('F').stage, PurchaseStage.enrolled);
    });
    test('guests must sign in; paid courses cannot be taken for free', () async {
      final p = make();
      uid = '';
      expect(await p.enrollFree(free), BuyResult.needsAccount);
      uid = 's1';
      expect(await p.enrollFree(a), BuyResult.notAllowed);
      expect(server.freeEnrolments, isEmpty);
    });
    test('a refusal (e.g. full) is reported with its code', () async {
      server.refuse = const EnrollmentException('failed-precondition', 'This course is fully booked.');
      final p = make();
      await p.enrollFree(free);
      await pumpEventQueue();
      expect(p.statusOf('F').stage, PurchaseStage.failed);
      expect(p.statusOf('F').code, 'failed-precondition');
    });
  });

  test('statuses notify listeners (screens rebuild)', () async {
    final p = make();
    var notified = 0;
    p.addListener(() => notified++);
    await p.buy(a);
    expect(notified, greaterThan(0));
  });

  test('no work after dispose', () async {
    final p = make();
    await p.buy(a);
    p.dispose();
    store.deliver(tier100);
    await pumpEventQueue();
    expect(server.verifications, isEmpty);
  });

  test('dispose of StoreEvent kinds is exhaustive', () {
    expect(StoreEventKind.values, hasLength(4));
  });
}
