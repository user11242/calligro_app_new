import 'dart:async';

import 'package:calligro_app/features/rating/application/course_ratings.dart';
import 'package:calligro_app/features/rating/domain/rating_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_ratings.dart';

void main() {
  late FakeRatingRepository repo;
  late CourseRatings ratings;
  var now = DateTime(2026, 11, 15);
  final finished = RateableCourse(courseId: 'c1', teacherId: 't1', enrolledStudents: const ['s1'], endDate: DateTime(2026, 11, 1));

  setUp(() {
    now = DateTime(2026, 11, 15);
    repo = FakeRatingRepository()
      ..clock = (() => now)
      ..courses.add(finished);
    ratings = CourseRatings(repository: repo, currentUid: () => 's1', clock: () => now);
  });

  group('the pop-up (THE BUG: shown again and again for the same course)', () {
    test('a finished course is offered once, and marked as shown before it appears', () async {
      expect((await ratings.courseToRate())!.courseId, 'c1');
      expect(repo.shown, ['c1']);
      expect(await ratings.courseToRate(), isNull, reason: 'reopening the home page does not ask again');
    });

    test('two checks at the same time share one result (one pop-up, not two)', () async {
      repo.holdReads = Completer<void>();
      final a = ratings.courseToRate();
      final b = ratings.courseToRate();
      repo.holdReads!.complete();
      expect([(await a)!.courseId, (await b)!.courseId], ['c1', 'c1']);
      expect(repo.enrolledReads, 1);
      expect(repo.shown, ['c1']);
    });

    test('after "Skip" it comes back only after a week, and never after 3 times', () async {
      for (var i = 0; i < 3; i++) {
        expect((await ratings.courseToRate())?.courseId, 'c1', reason: 'week ${i + 1}');
        now = now.add(const Duration(days: 3));
        expect(await ratings.courseToRate(), isNull);
        now = now.add(const Duration(days: 4));
      }
      expect(await ratings.courseToRate(), isNull);
    });

    test('rated → never asked again', () async {
      await ratings.courseToRate();
      expect((await ratings.submit(finished, stars: 5)).isRated, isTrue);
      now = now.add(const Duration(days: 30));
      expect(await ratings.courseToRate(), isNull);
    });

    test('on any error it does NOT ask (the old code asked when its check failed)', () async {
      repo.failReads = Exception('offline');
      expect(await ratings.courseToRate(), isNull);
      expect(repo.shown, isEmpty);
    });

    test('running courses and signed-out users: no pop-up', () async {
      repo.courses
        ..clear()
        ..add(RateableCourse(courseId: 'c2', teacherId: 't1', enrolledStudents: const ['s1'], endDate: DateTime(2027, 1, 1)));
      expect(await ratings.courseToRate(), isNull);
      expect(await CourseRatings(repository: repo, currentUid: () => '').courseToRate(), isNull);
    });
  });

  group('submitting (THE BUG: many ratings for one course)', () {
    test('one review, at the fixed id, with the profile name', () async {
      final r = await ratings.submit(finished, stars: 4, reviewText: '  Lovely  ', courseName: 'Thuluth');
      expect(r.outcome, RatingOutcome.done);
      final saved = repo.reviews['c1_s1']!;
      expect([saved.rating, saved.reviewText, saved.studentName, saved.teacherId, saved.courseName], [4, 'Lovely', 'Sara', 't1', 'Thuluth']);
    });

    test('submitting again (retry, second device) does not add a second review', () async {
      await ratings.submit(finished, stars: 4);
      final again = await ratings.submit(finished, stars: 1);
      expect(again.outcome, RatingOutcome.alreadyRated);
      expect(again.isRated, isTrue, reason: 'the pop-up closes as rated');
      expect(repo.reviews.length, 1);
      expect(repo.reviews['c1_s1']!.rating, 4);
    });

    test('double tap while saving → one review', () async {
      repo.holdSubmit = Completer<void>();
      final first = ratings.submit(finished, stars: 5);
      await Future<void>.delayed(Duration.zero);
      expect((await ratings.submit(finished, stars: 5)).outcome, RatingOutcome.busy);
      repo.holdSubmit!.complete();
      expect((await first).outcome, RatingOutcome.done);
      expect(repo.reviews.length, 1);
    });

    test('bad stars, too long, not enrolled, not finished → refused', () async {
      expect((await ratings.submit(finished, stars: 0)).outcome, RatingOutcome.invalid);
      expect((await ratings.submit(finished, stars: 6)).outcome, RatingOutcome.invalid);
      expect((await ratings.submit(finished, stars: 5, reviewText: 'x' * 1001)).outcome, RatingOutcome.invalid);
      expect((await ratings.submit(RateableCourse(courseId: 'c9', teacherId: 't1', endDate: DateTime(2026, 1, 1)), stars: 5)).outcome,
          RatingOutcome.notAllowed);
      expect((await ratings.submit(RateableCourse(courseId: 'c8', teacherId: 't1', enrolledStudents: const ['s1'], endDate: DateTime(2027, 1, 1)), stars: 5)).outcome,
          RatingOutcome.notAllowed);
      expect(repo.reviews, isEmpty);
    });

    test('a failed save is reported and can be retried', () async {
      repo.failSubmit = Exception('offline');
      expect((await ratings.submit(finished, stars: 5)).outcome, RatingOutcome.failed);
      repo.failSubmit = null;
      expect((await ratings.submit(finished, stars: 5)).outcome, RatingOutcome.done);
    });
  });
}
