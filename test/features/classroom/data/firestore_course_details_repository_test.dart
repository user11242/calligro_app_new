import 'package:calligro_app/features/classroom/data/firestore_course_details_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreCourseDetailsRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreCourseDetailsRepository(firestore: db);
  });

  test('the course, once and live; a missing course is null', () async {
    await db.doc('courses/c1').set({'teacherId': 'T1', 'enrolledStudents': ['s1']});
    expect((await repo.getCourse('c1'))!['teacherId'], 'T1');
    expect(await repo.getCourse('nope'), isNull);

    final seen = <List<dynamic>?>[];
    final sub = repo.watchCourse('c1').listen((c) => seen.add(c?['enrolledStudents'] as List?));
    await Future<void>.delayed(Duration.zero);
    await db.doc('courses/c1').update({'enrolledStudents': ['s1', 's2']});
    await Future<void>.delayed(Duration.zero);
    expect(seen.last, ['s1', 's2']);
    await sub.cancel();
  });

  test('the platform role on the profile', () async {
    await db.doc('users/a1').set({'role': 'admin'});
    await db.doc('users/x').set({'name': 'No role'});
    expect(await repo.userRole('a1'), 'admin');
    expect(await repo.userRole('x'), isNull);
    expect(await repo.userRole('missing'), isNull);
    expect(await repo.userRole(''), isNull);
  });

  test('students: more than 10 ids are read in batches; names, photos and dates with their fallbacks', () async {
    final ids = [for (var i = 0; i < 23; i++) 's$i'];
    for (final id in ids) {
      await db.doc('users/$id').set({'name': 'Name $id', 'email': '$id@x.com'});
    }
    await db.doc('users/s0').set({
      'fullName': 'Full Name', 'name': 'Short', 'profilePic': 'old.jpg', 'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
    });
    await db.doc('users/s1').set({'name': '', 'photoUrl': 'new.jpg', 'profilePic': 'old.jpg'});

    final list = await repo.students([...ids, 'ghost']);
    expect(list.length, 23); // the unknown id is left out
    final byId = {for (final s in list) s.uid: s};
    expect(byId['s0']!.name, 'Full Name');
    expect(byId['s0']!.photoUrl, 'old.jpg');
    expect(byId['s0']!.createdAt, DateTime(2026, 1, 2));
    expect(byId['s1']!.name, isNull); // empty → the screen shows "Unknown student"
    expect(byId['s1']!.photoUrl, 'new.jpg');
    expect(byId['s22']!.email, 's22@x.com');
    expect(await repo.students(const []), isEmpty);
  });
}
