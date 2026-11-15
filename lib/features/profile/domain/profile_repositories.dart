import 'profile_models.dart';

/// A user's profile, live. Emits null when the user does not exist.
abstract interface class ProfileRepository {
  Stream<UserProfile?> watchProfile(String userId);
}

/// Live counters for the header and the tab badges.
abstract interface class ProfileCountsRepository {
  Stream<int> watchPostCount(String userId);
  Stream<int> watchSavedCount(String userId);
  Stream<int> watchLikedCount(String userId);
  Stream<int> watchCourseCount(String teacherId);
}

/// Followers / following of a user (existing accounts only).
abstract interface class FollowListRepository {
  Future<List<FollowListEntry>> load(String userId, FollowListKind kind);
}

/// A teacher's courses, live.
abstract interface class TeacherCoursesRepository {
  Stream<List<TeacherCourse>> watchCourses(String teacherId);
}

/// Reviews of a teacher, newest first, with each student's current photo.
abstract interface class TeacherReviewsRepository {
  Stream<List<TeacherReview>> watchReviews(String teacherId);
}

/// The signed-in user (guest when signed out).
abstract interface class ProfileViewerSource {
  Future<ProfileViewer> currentViewer();
}
