import 'dart:async';

import 'package:calligro_app/features/rating/domain/rating_models.dart';
import 'package:calligro_app/features/rating/domain/rating_repository.dart';

class FakeRatingRepository implements RatingRepository {
  final courses = <RateableCourse>[];
  final reviews = <String, Review>{};
  final prompts_ = <String, RatingPrompt>{};
  final shown = <String>[];
  int enrolledReads = 0;
  Object? failReads;
  Object? failSubmit;
  Completer<void>? holdReads;
  Completer<void>? holdSubmit;
  DateTime Function() clock = DateTime.now;

  @override
  Future<List<RateableCourse>> enrolledCourses(String uid) async {
    enrolledReads++;
    if (holdReads != null) await holdReads!.future;
    if (failReads != null) throw failReads!;
    return courses.where((c) => c.enrolledStudents.contains(uid)).toList();
  }

  @override
  Future<Set<String>> reviewedCourseIds(String uid) async =>
      {for (final r in reviews.values) if (r.studentId == uid) r.courseId};

  @override
  Future<void> submit(Review review) async {
    if (holdSubmit != null) await holdSubmit!.future;
    if (failSubmit != null) throw failSubmit!;
    if (reviews.containsKey(review.id)) throw const AlreadyRatedException();
    reviews[review.id] = review;
  }

  @override
  Future<Map<String, RatingPrompt>> prompts(String uid) async => Map.of(prompts_);

  @override
  Future<void> markShown(String uid, String courseId) async {
    shown.add(courseId);
    final p = prompts_[courseId];
    prompts_[courseId] = RatingPrompt(courseId: courseId, timesShown: (p?.timesShown ?? 0) + 1, lastShownAt: clock());
  }

  @override
  Future<String> studentName(String uid) async => 'Sara';
}
