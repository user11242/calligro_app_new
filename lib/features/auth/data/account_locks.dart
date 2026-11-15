import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/account_keys.dart';

/// The "taken" registries, reserved in the SAME batch as the new account's
/// documents (email, Google and Apple sign-up all use this; Apple used to
/// reserve nothing, so names and phones could be duplicated).
class AccountLocks {
  AccountLocks._();

  static void reserve(
    FirebaseFirestore db,
    WriteBatch batch, {
    required String uid,
    String? email,
    String? username,
    String? phone,
  }) {
    final now = Timestamp.now();
    if (email != null && email.trim().isNotEmpty) {
      batch.set(db.collection('locked_emails').doc(AccountKeys.email(email)), {'uid': uid, 'createdAt': now});
    }
    if (username != null && username.trim().isNotEmpty) {
      batch.set(db.collection('locked_usernames').doc(AccountKeys.username(username)), {'uid': uid, 'createdAt': now});
    }
    if (phone != null && phone.trim().isNotEmpty) {
      batch.set(db.collection('locked_phones').doc(AccountKeys.phone(phone)), {
        'uid': uid,
        if (email != null) 'email': AccountKeys.email(email),
        'createdAt': now,
      });
    }
  }

  static Future<bool> isTaken(FirebaseFirestore db, String collection, String key) async {
    try {
      return (await db.collection(collection).doc(key).get()).exists;
    } catch (_) {
      return false; // as before: a failed check does not block sign-up
    }
  }
}
