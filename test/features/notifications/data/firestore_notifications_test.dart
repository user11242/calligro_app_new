import 'package:calligro_app/features/notifications/data/firestore_notification_repositories.dart';
import 'package:calligro_app/features/notifications/domain/notification_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('inbox: newest first, destinations, unread count, mark read / all read (old and new shapes)', () async {
    final inbox = FirestoreInboxRepository(firestore: db);
    await db.collection('users/u1/notifications').doc('old').set({
      'title': 'Session moved', 'message': 'At 7', 'isRead': false, 'type': 'reschedule', 'courseId': 'c1',
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 1)),
    });
    await db.collection('users/u1/notifications').doc('new').set({
      'title': 'New like', 'body': 'x', 'read': false, 'type': 'like', 'data': {'route': '/postDetails', 'postId': 'p1'},
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 10)),
    });
    final items = await inbox.watch('u1').first;
    expect(items.map((i) => i.id), ['new', 'old']);
    expect(items.first.target, const PostTarget('p1'));
    expect(await inbox.watchUnreadCount('u1').first, 2);

    await inbox.markRead('u1', 'new');
    expect(await inbox.watchUnreadCount('u1').first, 1);
    await inbox.markAllRead('u1');
    expect(await inbox.watchUnreadCount('u1').first, 0);
    expect(await inbox.watch('').first, isEmpty);
  });

  test('token store: save, and clear only if it is still this account\'s token', () async {
    final store = FirestorePushTokenStore(firestore: db);
    await store.save('u1', 'tok-1', language: 'ar');
    expect((await db.doc('users/u1').get()).data()!['fcmToken'], 'tok-1');
    await store.clear('u1', 'other-token');
    expect((await db.doc('users/u1').get()).data()!['fcmToken'], 'tok-1');
    await store.clear('u1', 'tok-1');
    expect((await db.doc('users/u1').get()).data()!.containsKey('fcmToken'), isFalse);
    expect((await db.doc('users/u1').get()).data()!['preferredLanguage'], 'ar');
  });

  test('token store: also saves the phone\'s time zone (moved-class notifications show local time)', () async {
    final store = FirestorePushTokenStore(firestore: db);
    await store.save('u2', 'tok-2', language: 'en', utcOffset: const Duration(hours: 3));
    expect((await db.doc('users/u2').get()).data()!['utcOffsetMinutes'], 180);
  });
}
