/// Course ratings (pure Dart). A student rates a course once, after it ends;
/// the teacher's and the course's totals are computed by the server from the
/// reviews (functions/ratings.js), never incremented by the app.
library;

class Review {
  final String id;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String courseId;
  final String courseName;

  /// 1-5 stars.
  final int rating;
  final String reviewText;
  final DateTime? timestamp;

  const Review({
    required this.id,
    required this.studentId,
    this.studentName = '',
    required this.teacherId,
    required this.courseId,
    this.courseName = '',
    required this.rating,
    this.reviewText = '',
    this.timestamp,
  });

  /// ONE review per student per course: its id says so, and firestore.rules
  /// only accepts this id. A second submission can never create a second review.
  static String idFor({required String courseId, required String studentId}) => '${courseId}_$studentId';

  /// The document the app writes. [timestamp] is the server time.
  Map<String, dynamic> toDocument({required Object timestamp}) => {
        'studentId': studentId,
        'studentName': studentName,
        'teacherId': teacherId,
        'courseId': courseId,
        'courseName': courseName,
        'rating': rating,
        'reviewText': reviewText,
        'timestamp': timestamp,
        'isPublic': true,
      };

  factory Review.fromMap(String id, Map<String, dynamic> d) {
    DateTime? at;
    try {
      final dynamic t = d['timestamp'];
      if (t is DateTime) {
        at = t;
      } else if (t != null) {
        at = t.toDate() as DateTime;
      }
    } catch (_) {}
    String s(String k) => d[k] is String ? d[k] as String : '';
    return Review(
      id: id,
      studentId: s('studentId'),
      studentName: s('studentName'),
      teacherId: s('teacherId'),
      courseId: s('courseId'),
      courseName: s('courseName'),
      rating: d['rating'] is num ? (d['rating'] as num).toInt() : 0,
      reviewText: s('reviewText'),
      timestamp: at,
    );
  }
}

/// How often the student was already asked to rate a course.
class RatingPrompt {
  final String courseId;
  final int timesShown;
  final DateTime? lastShownAt;
  const RatingPrompt({required this.courseId, this.timesShown = 0, this.lastShownAt});
}

/// What the pop-up needs about a finished course.
class RateableCourse {
  final String courseId;
  final String teacherId;
  final List<String> enrolledStudents;
  final DateTime? endDate;

  /// The stored course document (for the localised course name).
  final Map<String, dynamic> data;

  const RateableCourse({
    required this.courseId,
    required this.teacherId,
    this.enrolledStudents = const [],
    this.endDate,
    this.data = const {},
  });
}

class RatingPolicy {
  RatingPolicy._();

  static const minStars = 1;
  static const maxStars = 5;
  static const maxReviewLength = 1000;

  /// "Skip" means "not now": ask again after [snooze], at most [maxPrompts] times.
  static const snooze = Duration(days: 7);
  static const maxPrompts = 3;

  static bool isValidStars(int stars) => stars >= minStars && stars <= maxStars;

  /// Only an enrolled student, and only after the course has ended.
  static bool canRate(RateableCourse course, String uid, DateTime now) =>
      uid.isNotEmpty &&
      course.teacherId != uid &&
      course.enrolledStudents.contains(uid) &&
      course.endDate != null &&
      now.isAfter(course.endDate!);

  /// The ONE course to ask about now, or null: finished, not rated yet, and
  /// not asked too recently or too often. Oldest finished course first.
  static RateableCourse? nextToPrompt({
    required List<RateableCourse> courses,
    required String uid,
    required Set<String> reviewedCourseIds,
    required Map<String, RatingPrompt> prompts,
    required DateTime now,
  }) {
    final candidates = courses.where((c) {
      if (!canRate(c, uid, now) || reviewedCourseIds.contains(c.courseId)) return false;
      final p = prompts[c.courseId];
      if (p == null) return true;
      if (p.timesShown >= maxPrompts) return false;
      return p.lastShownAt == null || !now.isBefore(p.lastShownAt!.add(snooze));
    }).toList()
      ..sort((a, b) => a.endDate!.compareTo(b.endDate!));
    return candidates.isEmpty ? null : candidates.first;
  }
}
