import 'package:calligro_app/features/profile/data/firestore_profile_editor.dart';
import 'package:calligro_app/features/profile/domain/profile_edit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreProfileEditorRepository repo;

  Future<EditableProfile> original(String uid) async => (await repo.load(uid))!;
  Future<Map<String, dynamic>?> doc(String path) async => (await db.doc(path).get()).data();

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreProfileEditorRepository(firestore: db);
    await db.doc('users/t1').set({
      'name': 'Ali Hassan', 'name_lower': 'ali hassan', 'bio': 'Teacher', 'phone': '+962791234567',
      'photoUrl': 'old.jpg', 'role': 'teacher', 'email': 't1@x.com',
    });
    await db.doc('teachers/t1').set({'role': 'teacher', 'name': 'Ali Hassan'});
    await db.doc('locked_usernames/ali hassan').set({'uid': 't1'});
    await db.doc('locked_phones/+962791234567').set({'uid': 't1'});
    await db.doc('users/s1').set({'name': 'Old Student', 'role': 'student'}); // no reservations (older account)
    await db.doc('students/s1').set({'role': 'student'});
    await db.doc('locked_usernames/taken name').set({'uid': 'someone'});
    await db.doc('locked_phones/+962790000000').set({'uid': 'someone'});
    await db.collection('community_posts').doc('p1').set({'userId': 't1', 'userName': 'Ali Hassan'});
    await db.collection('courses').doc('c1').set({'teacherId': 't1', 'teacherName': 'Ali Hassan'});
  });

  test('loads the editable fields', () async {
    final p = await original('t1');
    expect(p.name, 'Ali Hassan');
    expect(p.bio, 'Teacher');
    expect(p.phone, '+962791234567');
    expect(p.photoUrl, 'old.jpg');
    expect(p.role, 'teacher');
    expect(p.email, 't1@x.com');
    expect(await repo.load('ghost'), isNull);
  });

  test('taken checks ignore your own reservation', () async {
    expect(await repo.isNameTaken('Taken Name', uid: 't1'), isTrue);
    expect(await repo.isNameTaken('  ALI hassan ', uid: 't1'), isFalse, reason: 'mine');
    expect(await repo.isNameTaken('Free Name', uid: 't1'), isFalse);
    expect(await repo.isPhoneTaken('+962 79 000 0000', uid: 't1'), isTrue, reason: 'normalized');
    expect(await repo.isPhoneTaken('+962791234567', uid: 't1'), isFalse);
  });

  test('saves the profile on users + the role document', () async {
    await repo.save(await original('t1'),
        const ProfileDraft(name: ' Ali H ', bio: ' New bio ', phone: '+962791234567'), photoUrl: 'new.jpg');
    final u = (await doc('users/t1'))!;
    expect(u['name'], 'Ali H');
    expect(u['name_lower'], 'ali h');
    expect(u['bio'], 'New bio');
    expect(u['photoUrl'], 'new.jpg');
    expect(u['updatedAt'], isA<Timestamp>());
    expect((await doc('teachers/t1'))!['name'], 'Ali H');
  });

  test('a rename moves the name reservation', () async {
    await repo.save(await original('t1'), const ProfileDraft(name: 'Omar', bio: 'Teacher', phone: '+962791234567'),
        photoUrl: 'old.jpg');
    expect(await doc('locked_usernames/ali hassan'), isNull);
    expect((await doc('locked_usernames/omar'))!['uid'], 't1');
  });

  test('a case-only rename keeps the same reservation', () async {
    await repo.save(await original('t1'),
        const ProfileDraft(name: 'ALI HASSAN', bio: 'Teacher', phone: '+962791234567'), photoUrl: 'old.jpg');
    expect((await doc('locked_usernames/ali hassan'))!['uid'], 't1');
    expect((await doc('users/t1'))!['name'], 'ALI HASSAN');
  });

  test('an older account without reservations can rename (nothing to release)', () async {
    await repo.save(await original('s1'), const ProfileDraft(name: 'New Student', bio: '', phone: ''), photoUrl: '');
    expect((await doc('locked_usernames/new student'))!['uid'], 's1');
    expect((await doc('students/s1'))!['name'], 'New Student');
  });

  test('someone else\'s reservation of the old name is never deleted', () async {
    await db.doc('locked_usernames/old student').set({'uid': 'someone'});
    await repo.save(await original('s1'), const ProfileDraft(name: 'New Student', bio: '', phone: ''), photoUrl: '');
    expect((await doc('locked_usernames/old student'))!['uid'], 'someone');
  });

  test('reservation keys match what registration writes (+ and digits, Arabic digits converted)', () {
    expect(FirestoreProfileEditorRepository.phoneKey('+962 79-123 4567'), '+962791234567');
    expect(FirestoreProfileEditorRepository.phoneKey('+٩٦٢٧٩١٢٣٤٥٦٧'), '+962791234567');
  });

  test('a phone change moves the phone reservation (normalized)', () async {
    await repo.save(await original('t1'), const ProfileDraft(name: 'Ali Hassan', bio: 'Teacher', phone: '+962 79 555 5555'),
        photoUrl: 'old.jpg');
    expect(await doc('locked_phones/+962791234567'), isNull);
    expect((await doc('locked_phones/+962795555555'))!['uid'], 't1');
  });

  test('copies elsewhere are NOT rewritten from the app (the server does that)', () async {
    await repo.save(await original('t1'), const ProfileDraft(name: 'Omar', bio: 'Teacher', phone: '+962791234567'),
        photoUrl: 'new.jpg');
    expect((await doc('community_posts/p1'))!['userName'], 'Ali Hassan');
    expect((await doc('courses/c1'))!['teacherName'], 'Ali Hassan');
  });
}
