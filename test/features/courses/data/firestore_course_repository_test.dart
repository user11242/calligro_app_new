import 'package:calligro_app/features/courses/data/firestore_course_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/course_fixtures.dart';

/// The course data layer on documents shaped EXACTLY like real ones
/// (no isPublished / isFree / status — real courses do not have them).
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreCourseRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreCourseRepository(firestore: db);
    await db.doc('courses/old').set(realCourseData(name: 'Old', createdAt: DateTime(2026, 1, 1)));
    await db.doc('courses/new').set(realCourseData(name: 'New', createdAt: DateTime(2026, 10, 1), enrolled: ['s1']));
    final legacy = realCourseData(name: 'Legacy')..remove('createdAt');
    await db.doc('courses/legacy').set(legacy);
    await db.doc('users/t1').set({
      'name': 'Ustadh Ali', 'photoUrl': 'p.jpg', 'role': 'teacher', 'totalStars': 9, 'reviewCount': 2,
      'followerCount': 7, 'spokenLanguages': ['Arabic'],
    });
  });

  test('the catalogue lists REAL courses (none has isPublished), newest first, undated last', () async {
    final list = await repo.watchCatalog().first;
    expect(list.map((c) => c.courseName), ['New', 'Old', 'Legacy']);
  });

  test('the catalogue is live', () async {
    final stream = repo.watchCatalog();
    final first = await stream.first;
    expect(first, hasLength(3));
    await db.doc('courses/another').set(realCourseData(name: 'Another', createdAt: DateTime(2026, 11, 1)));
    expect((await repo.watchCatalog().first).first.courseName, 'Another');
  });

  test('my courses: only where I am enrolled, live', () async {
    expect((await repo.watchEnrolled('s1').first).map((c) => c.id), ['new']);
    expect(await repo.watchEnrolled('').first, isEmpty);
    await db.doc('courses/old').update({'enrolledStudents': ['s1']});
    expect((await repo.watchEnrolled('s1').first).map((c) => c.id).toSet(), {'new', 'old'});
  });

  test('latest courses for the home page', () async {
    expect((await repo.watchLatest(limit: 1).first).single.id, 'new');
  });

  test('one course, live; missing → null', () async {
    expect((await repo.watchCourse('old').first)!.courseName, 'Old');
    expect(await repo.watchCourse('nope').first, isNull);
  });

  test('teacher summary: REAL average (stars / reviews), courses and students counted once', () async {
    final s = (await repo.teacherSummary('t1'))!;
    expect(s.name, 'Ustadh Ali');
    expect(s.averageRating, 4.5, reason: 'totalStars is a SUM, not an average');
    expect(s.reviewCount, 2);
    expect(s.followerCount, 7);
    expect(s.courseCount, 3);
    expect(s.totalStudents, 1);
    expect(s.spokenLanguages, ['Arabic']);
  });

  test('teacher summary is cached (read once per teacher)', () async {
    await repo.teacherSummary('t1');
    await db.doc('users/t1').update({'name': 'Changed'});
    expect((await repo.teacherSummary('t1'))!.name, 'Ustadh Ali');
    expect(await repo.teacherSummary('ghost'), isNull);
  });

  test('a teacher with no reviews averages 0, not 5', () async {
    await db.doc('users/t2').set({'name': 'New Teacher', 'role': 'teacher'});
    expect((await repo.teacherSummary('t2'))!.averageRating, 0);
  });
}
