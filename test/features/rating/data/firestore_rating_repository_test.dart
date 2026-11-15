import 'package:calligro_app/features/rating/data/firestore_rating_repository.dart';
import 'package:calligro_app/features/rating/domain/rating_models.dart';
import 'package:calligro_app/features/rating/domain/rating_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreRatingRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreRatingRepository(firestore: db);
    await db.doc('users/s1').set({'name': 'Sara'});
    await db.doc('courses/c1').set({
      'teacherId': 't1', 'enrolledStudents': ['s1'], 'endDate': Timestamp.fromDate(DateTime(2026, 11, 1)), 'courseName': 'Thuluth',
    });
    await db.doc('courses/c2').set({'teacherId': 't1', 'enrolledStudents': ['s2']});
  });

  test('enrolled courses with their end date', () async {
    final list = await repo.enrolledCourses('s1');
    expect(list.single.courseId, 'c1');
    expect([list.single.teacherId, list.single.endDate, list.single.data['courseName']], ['t1', DateTime(2026, 11, 1), 'Thuluth']);
  });

  test('the review is created at its fixed id; a second one is refused', () async {
    const review = Review(id: 'c1_s1', studentId: 's1', teacherId: 't1', courseId: 'c1', rating: 5);
    await repo.submit(review);
    final saved = (await db.doc('reviews/c1_s1').get()).data()!;
    expect([saved['rating'], saved['isPublic']], [5, true]);
    expect(saved['timestamp'], isA<Timestamp>());
    expect(() => repo.submit(review), throwsA(isA<AlreadyRatedException>()));
    expect((await db.collection('reviews').get()).size, 1);
  });

  test('already-rated courses include reviews from older app versions (random ids)', () async {
    await db.collection('reviews').add({'studentId': 's1', 'courseId': 'old-course', 'rating': 4});
    await repo.submit(const Review(id: 'c1_s1', studentId: 's1', teacherId: 't1', courseId: 'c1', rating: 5));
    expect(await repo.reviewedCourseIds('s1'), {'old-course', 'c1'});
  });

  test('prompts: counted and time-stamped per course', () async {
    await repo.markShown('s1', 'c1');
    await repo.markShown('s1', 'c1');
    final p = (await repo.prompts('s1'))['c1']!;
    expect(p.timesShown, 2);
    expect(p.lastShownAt, isNotNull);
    expect(await repo.studentName('s1'), 'Sara');
  });
}
