import 'package:calligro_app/features/rating/domain/rating_models.dart';
import 'package:flutter_test/flutter_test.dart';

RateableCourse course(String id, {DateTime? end, List<String> students = const ['s1'], String teacher = 't1'}) =>
    RateableCourse(courseId: id, teacherId: teacher, enrolledStudents: students, endDate: end ?? DateTime(2026, 11, 1));

void main() {
  final now = DateTime(2026, 11, 15);

  test('one review per student per course: the id says so', () {
    expect(Review.idFor(courseId: 'c1', studentId: 's1'), 'c1_s1');
  });

  test('stars 1-5 only', () {
    expect([0, 1, 5, 6].map(RatingPolicy.isValidStars), [false, true, true, false]);
  });

  group('who may rate', () {
    test('an enrolled student, after the end date', () {
      expect(RatingPolicy.canRate(course('c1'), 's1', now), isTrue);
    });
    test('not before the end, not outsiders, not the teacher, not guests, not without an end date', () {
      expect(RatingPolicy.canRate(course('c1', end: DateTime(2026, 12, 1)), 's1', now), isFalse);
      expect(RatingPolicy.canRate(course('c1'), 'stranger', now), isFalse);
      expect(RatingPolicy.canRate(course('c1', students: ['t1'], teacher: 't1'), 't1', now), isFalse);
      expect(RatingPolicy.canRate(course('c1'), '', now), isFalse);
      expect(RatingPolicy.canRate(const RateableCourse(courseId: 'x', teacherId: 't1', enrolledStudents: ['s1']), 's1', now), isFalse);
    });
  });

  group('THE BUG: the pop-up came on the last DAY, before the last class even started', () {
    // endDate is stored as the start of the last day; the last class is 18:00–19:30 that day.
    final lastDay = DateTime(2026, 11, 20);
    final c = RateableCourse(
      courseId: 'c1', teacherId: 't1', enrolledStudents: const ['s1'],
      endDate: lastDay, lastClassEnd: DateTime(2026, 11, 20, 19, 30),
    );

    test('not during the last day before the last class ends', () {
      expect(RatingPolicy.canRate(c, 's1', DateTime(2026, 11, 20, 9)), isFalse);
      expect(RatingPolicy.canRate(c, 's1', DateTime(2026, 11, 20, 19, 0)), isFalse, reason: 'class still running');
    });

    test('right after the last class ends', () {
      expect(RatingPolicy.canRate(c, 's1', DateTime(2026, 11, 20, 19, 31)), isTrue);
      expect(RatingPolicy.ratingOpensAt(c), DateTime(2026, 11, 20, 19, 30));
    });

    test('a course whose class times are unknown waits until the whole last day is over', () {
      final noTimes = RateableCourse(courseId: 'c2', teacherId: 't1', enrolledStudents: const ['s1'], endDate: lastDay);
      expect(RatingPolicy.canRate(noTimes, 's1', DateTime(2026, 11, 20, 23, 59)), isFalse);
      expect(RatingPolicy.canRate(noTimes, 's1', DateTime(2026, 11, 21, 0, 1)), isTrue);
    });
  });

  group('which course to ask about (THE BUG: the same course kept coming back)', () {
    RateableCourse? next(List<RateableCourse> courses, {Set<String> reviewed = const {}, Map<String, RatingPrompt> prompts = const {}}) =>
        RatingPolicy.nextToPrompt(courses: courses, uid: 's1', reviewedCourseIds: reviewed, prompts: prompts, now: now);

    test('a finished, unrated course', () => expect(next([course('c1')])!.courseId, 'c1'));

    test('never a course already rated', () => expect(next([course('c1')], reviewed: {'c1'}), isNull));

    test('"Skip" snoozes it for a week', () {
      final justAsked = {'c1': RatingPrompt(courseId: 'c1', timesShown: 1, lastShownAt: now.subtract(const Duration(days: 2)))};
      expect(next([course('c1')], prompts: justAsked), isNull);
      final weekAgo = {'c1': RatingPrompt(courseId: 'c1', timesShown: 1, lastShownAt: now.subtract(const Duration(days: 7)))};
      expect(next([course('c1')], prompts: weekAgo)!.courseId, 'c1');
    });

    test('asked at most 3 times, ever', () {
      final often = {'c1': RatingPrompt(courseId: 'c1', timesShown: 3, lastShownAt: DateTime(2026, 1, 1))};
      expect(next([course('c1')], prompts: often), isNull);
    });

    test('several finished courses: the oldest first, one at a time', () {
      final r = next([course('new', end: DateTime(2026, 11, 10)), course('old', end: DateTime(2026, 10, 1)), course('running', end: DateTime(2027, 1, 1))]);
      expect(r!.courseId, 'old');
    });
  });

  test('the document written and read back', () {
    const r = Review(id: 'c1_s1', studentId: 's1', studentName: 'Sara', teacherId: 't1', courseId: 'c1', courseName: 'Thuluth', rating: 4, reviewText: 'Great');
    final doc = r.toDocument(timestamp: 'NOW');
    expect(doc.keys.toSet(), {'studentId', 'studentName', 'teacherId', 'courseId', 'courseName', 'rating', 'reviewText', 'timestamp', 'isPublic'});
    final back = Review.fromMap('c1_s1', doc..['timestamp'] = DateTime(2026, 11, 15));
    expect([back.rating, back.reviewText, back.timestamp], [4, 'Great', DateTime(2026, 11, 15)]);
  });
}
