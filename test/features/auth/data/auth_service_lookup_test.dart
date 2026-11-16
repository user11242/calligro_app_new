import 'package:calligro_app/features/auth/data/services/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reset page lookup: as typed, then lower-case (THE BUG: capitals said "no account")', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u1').set({'email': 'ali@x.com', 'status': 'approved'});
    await db.doc('users/u2').set({'email': 'Mixed@X.com', 'status': 'approved'});
    final auth = AuthService(firestore: db, auth: MockFirebaseAuth());
    expect((await auth.findUserByEmail('Ali@X.com'))?['email'], 'ali@x.com');
    expect((await auth.findUserByEmail(' ali@x.com '))?['email'], 'ali@x.com');
    expect((await auth.findUserByEmail('Mixed@X.com'))?['email'], 'Mixed@X.com', reason: 'older accounts saved as typed');
    expect(await auth.findUserByEmail('nobody@x.com'), isNull);
  });

  test('profile load', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u1').set({'role': 'student'});
    final auth = AuthService(firestore: db, auth: MockFirebaseAuth());
    expect((await auth.loadUserProfile('u1'))?['role'], 'student');
    expect(await auth.loadUserProfile('nobody'), isNull);
  });
}
