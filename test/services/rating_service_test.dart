import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/rating/services/rating_service.dart';

void main() {
  group('Layer 2: RatingService Tests (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late RatingService ratingService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      ratingService = RatingService(firestore: fakeFirestore);
    });

    test('submitRating() throws if rating < 1', () async {
      expect(
        () => ratingService.submitRating(
          studentId: 's1', studentName: 'Student', teacherId: 't1', courseId: 'c1', courseName: 'Course', rating: 0,
        ),
        throwsException,
      );
    });

    test('submitRating() throws if rating > 5', () async {
      expect(
        () => ratingService.submitRating(
          studentId: 's1', studentName: 'Student', teacherId: 't1', courseId: 'c1', courseName: 'Course', rating: 6,
        ),
        throwsException,
      );
    });

    test('submitRating() updates user and teacher documents', () async {
      // Setup teacher docs
      await fakeFirestore.collection('users').doc('t1').set({'totalStars': 0, 'reviewCount': 0});
      await fakeFirestore.collection('teachers').doc('t1').set({'totalStars': 0, 'reviewCount': 0});

      await ratingService.submitRating(
        studentId: 's1',
        studentName: 'Student',
        teacherId: 't1',
        courseId: 'c1',
        courseName: 'Course',
        rating: 4,
        reviewText: 'Great!',
      );

      // Verify review doc created
      final reviews = await fakeFirestore.collection('reviews').get();
      expect(reviews.docs.length, 1);
      final reviewData = reviews.docs.first.data();
      expect(reviewData['rating'], 4);
      expect(reviewData['reviewText'], 'Great!');

      // Verify stats updated
      final userDoc = await fakeFirestore.collection('users').doc('t1').get();
      expect(userDoc.data()?['totalStars'], 4);
      expect(userDoc.data()?['reviewCount'], 1);
      
      final teacherDoc = await fakeFirestore.collection('teachers').doc('t1').get();
      expect(teacherDoc.data()?['totalStars'], 4);
      expect(teacherDoc.data()?['reviewCount'], 1);
    });
    
    test('submitRating() succeeds even if teacher doc does not exist', () async {
      // No teacher doc in users
      await ratingService.submitRating(
        studentId: 's1',
        studentName: 'Student',
        teacherId: 't2',
        courseId: 'c1',
        courseName: 'Course',
        rating: 4,
      );

      final reviews = await fakeFirestore.collection('reviews').get();
      expect(reviews.docs.length, 1);
    });

    test('hasStudentRatedCourse() returns true if rated', () async {
      await fakeFirestore.collection('reviews').add({
        'studentId': 's1',
        'courseId': 'c1',
      });
      
      final result = await ratingService.hasStudentRatedCourse(studentId: 's1', courseId: 'c1');
      expect(result, true);
    });

    test('hasStudentRatedCourse() returns false if not rated', () async {
      final result = await ratingService.hasStudentRatedCourse(studentId: 's1', courseId: 'c1');
      expect(result, false);
    });

    test('getTeacherReviews() returns stream', () {
      expect(ratingService.getTeacherReviews('t1'), isA<Stream>());
    });

    test('getCourseReviews() returns stream', () {
      expect(ratingService.getCourseReviews('c1'), isA<Stream>());
    });
  });
}
