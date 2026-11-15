import '../domain/rating_models.dart';
import '../domain/rating_repository.dart';

enum RatingOutcome { done, alreadyRated, notAllowed, invalid, busy, failed }

class RatingResult {
  final RatingOutcome outcome;
  final String? message;
  const RatingResult(this.outcome, {this.message});

  /// Saved now, or already saved before: either way the student has rated.
  bool get isRated => outcome == RatingOutcome.done || outcome == RatingOutcome.alreadyRated;
}

/// The rating pop-up and rating submission.
///
///  * [courseToRate] picks at most ONE course and records that it was shown
///    BEFORE the pop-up appears, so it cannot come back on the next screen,
///    restart or second check running at the same time.
///  * [submit] writes the review at its fixed id: a second tap, a retry or a
///    second device can never create a second review.
///  * Teacher / course totals are the server's job (functions/ratings.js).
class CourseRatings {
  CourseRatings({required RatingRepository repository, required String Function() currentUid, DateTime Function()? clock})
      : _repo = repository,
        _uid = currentUid,
        _now = clock ?? DateTime.now;

  final RatingRepository _repo;
  final String Function() _uid;
  final DateTime Function() _now;
  Future<RateableCourse?>? _checking;
  bool _submitting = false;

  /// Concurrent calls share ONE check (the home page used to start several).
  Future<RateableCourse?> courseToRate() => _checking ??= _pick().whenComplete(() => _checking = null);

  Future<RateableCourse?> _pick() async {
    final uid = _uid();
    if (uid.isEmpty) return null;
    try {
      final courses = await _repo.enrolledCourses(uid);
      final now = _now();
      if (!courses.any((c) => RatingPolicy.canRate(c, uid, now))) return null;
      final next = RatingPolicy.nextToPrompt(
        courses: courses,
        uid: uid,
        reviewedCourseIds: await _repo.reviewedCourseIds(uid),
        prompts: await _repo.prompts(uid),
        now: now,
      );
      if (next != null) await _repo.markShown(uid, next.courseId);
      return next;
    } catch (_) {
      // When unsure, do NOT ask (the old code asked again on any error).
      return null;
    }
  }

  Future<RatingResult> submit(RateableCourse course, {required int stars, String reviewText = '', String courseName = ''}) async {
    final uid = _uid();
    if (!RatingPolicy.canRate(course, uid, _now())) return const RatingResult(RatingOutcome.notAllowed);
    if (!RatingPolicy.isValidStars(stars) || reviewText.trim().length > RatingPolicy.maxReviewLength) {
      return const RatingResult(RatingOutcome.invalid);
    }
    if (_submitting) return const RatingResult(RatingOutcome.busy);
    _submitting = true;
    try {
      final name = await _repo.studentName(uid);
      await _repo.submit(Review(
        id: Review.idFor(courseId: course.courseId, studentId: uid),
        studentId: uid,
        studentName: name.isEmpty ? 'Student' : name,
        teacherId: course.teacherId,
        courseId: course.courseId,
        courseName: courseName,
        rating: stars,
        reviewText: reviewText.trim(),
      ));
      return const RatingResult(RatingOutcome.done);
    } on AlreadyRatedException {
      return const RatingResult(RatingOutcome.alreadyRated);
    } catch (e) {
      return RatingResult(RatingOutcome.failed, message: '$e');
    } finally {
      _submitting = false;
    }
  }
}
