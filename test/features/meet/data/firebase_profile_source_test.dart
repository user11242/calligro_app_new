import 'package:calligro_app/features/meet/data/firebase_profile_source.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;

  FirebaseProfileSource source({String? displayName, String? photoUrl, bool signedIn = true}) => FirebaseProfileSource(
        auth: MockFirebaseAuth(
          signedIn: signedIn,
          mockUser: MockUser(uid: 'u1', displayName: displayName, photoURL: photoUrl),
        ),
        firestore: db,
      );

  setUp(() => db = FakeFirebaseFirestore());

  test('prefers fullName, then name, from users/{uid}', () async {
    await db.collection('users').doc('u1').set({'fullName': 'Ali Hassan', 'name': 'ali', 'photoUrl': 'https://img/a.png'});
    final p = await source(displayName: 'Auth Name').load();
    expect(p.name, 'Ali Hassan');
    expect(p.avatarUrl, 'https://img/a.png');

    await db.collection('users').doc('u1').set({'name': 'ali'});
    expect((await source().load()).name, 'ali');
  });

  test('falls back to the Firebase Auth profile, ignoring empty fields', () async {
    await db.collection('users').doc('u1').set({'fullName': '', 'photoUrl': ''});
    final p = await source(displayName: 'Auth Name', photoUrl: 'https://img/auth.png').load();
    expect(p.name, 'Auth Name');
    expect(p.avatarUrl, 'https://img/auth.png');
  });

  test('no profile document at all → Auth profile', () async {
    final p = await source(displayName: 'Auth Name').load();
    expect(p.name, 'Auth Name');
  });

  test('nothing known → empty name (the controller shows a fallback)', () async {
    final p = await source(displayName: '', photoUrl: '').load();
    expect(p.name, '');
    expect(p.avatarUrl, isNull);
  });

  test('not signed in → error (the controller shows a fallback)', () async {
    await expectLater(source(signedIn: false).load(), throwsStateError);
  });
}
