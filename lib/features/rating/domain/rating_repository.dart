import 'rating_models.dart';

/// Thrown by [RatingRepository.submit] when the student already rated the course.
class AlreadyRatedException implements Exception {
  const AlreadyRatedException();
}

abstract interface class RatingRepository {
  /// Courses [uid] is enrolled in, with what the pop-up needs.
  Future<List<RateableCourse>> enrolledCourses(String uid);

  /// Courses [uid] already rated.
  Future<Set<String>> reviewedCourseIds(String uid);

  /// Creates the review at its fixed id ([Review.idFor]); throws
  /// [AlreadyRatedException] if it exists (never a second review).
  Future<void> submit(Review review);

  /// How often [uid] was asked about each course (private to them).
  Future<Map<String, RatingPrompt>> prompts(String uid);

  /// Records that the pop-up was shown for [courseId] now.
  Future<void> markShown(String uid, String courseId);

  /// The student's name as on their profile.
  Future<String> studentName(String uid);
}
