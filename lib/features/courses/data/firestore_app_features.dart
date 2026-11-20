import 'package:cloud_firestore/cloud_firestore.dart';

/// `app_config/features`: remote switches the admins control (readable by everyone,
/// writable by admins only: firestore.rules `app_config`).
class FirestoreAppFeatures {
  FirestoreAppFeatures({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('app_config').doc('features');

  Stream<Map<String, dynamic>?> watch() => _doc.snapshots().map((s) => s.data());

  Future<void> setJoinLock(bool on) =>
      _doc.set({'joinLock': on, 'joinLockUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
}
