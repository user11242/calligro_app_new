import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:calligro_app/core/utils/numeric_utils.dart';

import '../domain/profile_edit.dart';
import '../domain/profile_repositories.dart';

/// Own-profile editing. Name / phone uniqueness lives in the locked_usernames /
/// locked_phones reservations (enforced by firestore.rules). The copies of the
/// name / photo on courses, posts and comments are updated by the
/// `syncProfileCopies` Cloud Function, not here.
class FirestoreProfileEditorRepository implements ProfileEditorRepository {
  FirestoreProfileEditorRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;

  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> _nameLock(String name) =>
      _db.collection('locked_usernames').doc(ProfileEditPolicy.nameKey(name));
  DocumentReference<Map<String, dynamic>> _phoneLock(String phone) =>
      _db.collection('locked_phones').doc(phoneKey(phone));

  /// locked_phones document id — exactly what registration writes ('+' and digits).
  static String phoneKey(String phone) => NumericUtils.normalize(phone, clean: true);

  static String _s(Object? v) => v is String ? v : '';

  @override
  Future<EditableProfile?> load(String uid) async {
    final d = (await _db.collection('users').doc(uid).get()).data();
    if (d == null) return null;
    return EditableProfile(
      uid: uid,
      role: _s(d['role']).isEmpty ? 'student' : _s(d['role']),
      name: _s(d['name']),
      bio: _s(d['bio']),
      phone: _s(d['phone']),
      photoUrl: _s(d['photoUrl']),
      email: _s(d['email']),
    );
  }

  Future<bool> _reservedByOther(DocumentReference<Map<String, dynamic>> ref, String uid) async {
    final owner = (await ref.get()).data()?['uid'];
    return owner != null && owner != uid;
  }

  @override
  Future<bool> isNameTaken(String name, {required String uid}) => _reservedByOther(_nameLock(name), uid);

  @override
  Future<bool> isPhoneTaken(String phone, {required String uid}) =>
      phoneKey(phone).isEmpty ? Future.value(false) : _reservedByOther(_phoneLock(phone), uid);

  @override
  Future<void> save(EditableProfile original, ProfileDraft draft, {required String photoUrl}) async {
    final uid = original.uid;
    final name = draft.name.trim();
    final bio = draft.bio.trim();
    final phone = draft.phone.trim();
    final moveName = ProfileEditPolicy.nameReservationMoves(original.name, name);
    final movePhone = phoneKey(phone) != phoneKey(original.phone);

    await _db.runTransaction((tx) async {
      // Reads first (a transaction's rule). Only OUR old reservations are released;
      // older accounts may have none (deleting a missing one is refused by the rules).
      final oldName = moveName && original.name.trim().isNotEmpty ? await tx.get(_nameLock(original.name)) : null;
      final oldPhone = movePhone && phoneKey(original.phone).isNotEmpty ? await tx.get(_phoneLock(original.phone)) : null;

      final data = {
        'name': name,
        'name_lower': name.toLowerCase(),
        'phone': phone,
        'bio': bio,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      tx.set(_db.collection('users').doc(uid), data, SetOptions(merge: true));
      if (original.role == 'teacher' || original.role == 'student') {
        tx.set(_db.collection('${original.role}s').doc(uid), data, SetOptions(merge: true));
      }

      if (moveName) {
        if (oldName != null && oldName.data()?['uid'] == uid) tx.delete(oldName.reference);
        tx.set(_nameLock(name), {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
      }
      if (movePhone) {
        if (oldPhone != null && oldPhone.data()?['uid'] == uid) tx.delete(oldPhone.reference);
        if (phoneKey(phone).isNotEmpty) {
          tx.set(_phoneLock(phone), {'uid': uid, 'email': original.email, 'createdAt': FieldValue.serverTimestamp()});
        }
      }
    });
  }
}
