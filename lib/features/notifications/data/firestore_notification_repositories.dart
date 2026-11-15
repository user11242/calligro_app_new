import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/notification_models.dart';
import '../domain/notification_repositories.dart';

class FirestoreInboxRepository implements InboxRepository {
  FirestoreInboxRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  @override
  Stream<List<InboxItem>> watch(String uid) => uid.isEmpty
      ? Stream.value(const [])
      : _inbox(uid)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => [for (final d in s.docs) InboxItem.fromMap(d.id, d.data())]);

  @override
  Stream<int> watchUnreadCount(String uid) => watch(uid).map((l) => l.where((i) => !i.read).length);

  @override
  Future<void> markRead(String uid, String itemId) => _inbox(uid).doc(itemId).update({'read': true});

  @override
  Future<void> markAllRead(String uid) async {
    final batch = _db.batch();
    for (final d in (await _inbox(uid).limit(450).get()).docs) {
      final data = d.data();
      if (data['read'] != true && data['isRead'] != true) batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}

class FirestorePushTokenStore implements PushTokenStore {
  FirestorePushTokenStore({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  @override
  Future<void> save(String uid, String token, {required String language}) =>
      _db.collection('users').doc(uid).set({
        'fcmToken': token,
        'preferredLanguage': language,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> clear(String uid, String token) async {
    final ref = _db.collection('users').doc(uid);
    final current = (await ref.get()).data()?['fcmToken'];
    if (current == token) await ref.update({'fcmToken': FieldValue.delete()});
  }
}

class FirebasePushGateway implements PushGateway {
  FirebasePushGateway({FirebaseMessaging? messaging}) : _injected = messaging;
  final FirebaseMessaging? _injected;
  FirebaseMessaging get _m => _injected ?? FirebaseMessaging.instance;

  @override
  Future<String?> token() async {
    final settings = await _m.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
    return _m.getToken();
  }

  @override
  Future<void> deleteToken() => _m.deleteToken();
}
