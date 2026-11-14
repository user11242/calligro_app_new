import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/meet_media.dart';

/// Name + avatar of the signed-in user, from `users/{uid}` (falls back to the
/// Firebase Auth profile).
class FirebaseProfileSource implements MeetProfileSource {
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  const FirebaseProfileSource({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth,
        _firestore = firestore;

  @override
  Future<MeetUserProfile> load() async {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) throw StateError('Not signed in');
    final doc = await (_firestore ?? FirebaseFirestore.instance).collection('users').doc(user.uid).get();
    final data = doc.data() ?? const <String, dynamic>{};
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    return MeetUserProfile(
      name: text(data['fullName']) ?? text(data['name']) ?? text(user.displayName) ?? '',
      avatarUrl: text(data['photoUrl']) ?? text(user.photoURL),
    );
  }
}
