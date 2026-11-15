import 'package:calligro_app/core/utils/search_normalizer.dart';

import 'course_models.dart';

/// Browsing / buying rules (pure, unit-tested). Kept identical to the server
/// (functions/purchases.js) wherever both decide the same thing.
class CoursePolicy {
  CoursePolicy._();

  static const productPrefix = 'com.yazan.calligro.tier_';

  static bool isEnrolled(Course c, String uid) => uid.isNotEmpty && c.enrolledStudents.contains(uid);

  static bool isOwner(Course c, String uid) => uid.isNotEmpty && c.teacherId == uid;

  /// Same as the server: the larger of the counter and the real list.
  static bool isFull(Course c) {
    if (c.maxStudents <= 0) return false;
    final taken = c.enrolledCount > c.enrolledStudents.length ? c.enrolledCount : c.enrolledStudents.length;
    return taken >= c.maxStudents;
  }

  /// Full for [uid] — someone already inside is never blocked.
  static bool isFullFor(Course c, String uid) => !isEnrolled(c, uid) && isFull(c);

  /// The store product to buy. MUST equal expectedProductId() in functions/purchases.js.
  static String productIdFor(Course c) => c.iapProductId ?? '$productPrefix${c.price.truncate()}';

  static CourseAction action(Course c, String uid) {
    if (isOwner(c, uid)) return CourseAction.manage;
    if (isEnrolled(c, uid)) return CourseAction.open;
    if (isFull(c)) return CourseAction.soldOut;
    return c.isFree ? CourseAction.enrollFree : CourseAction.buy;
  }

  /// Courses that already started are not sold any more (hidden from non-students).
  static bool isVisibleInCatalog(Course c, String uid, {required DateTime now}) {
    final start = c.startDate;
    if (start == null || isEnrolled(c, uid)) return true;
    return !now.isAfter(start);
  }

  static bool matches(Course c, CourseFilter f, String uid) => switch (f) {
        CourseFilter.all => true,
        CourseFilter.myCourses => isEnrolled(c, uid),
        _ when f.isLevel => c.level == f.storedValue,
        _ => c.calligraphyStyle == f.storedValue,
      };

  /// [extraText]: e.g. the translated display title, which only the UI knows.
  static bool matchesSearch(Course c, String query, {String extraText = ''}) {
    final q = SearchNormalizer.prepare(query);
    if (q.isEmpty) return true;
    final corpus = SearchNormalizer.prepare(
        '${c.courseName} $extraText ${c.teacherName} ${c.courseDescription} ${c.calligraphyStyle}');
    return corpus.contains(q);
  }
}
