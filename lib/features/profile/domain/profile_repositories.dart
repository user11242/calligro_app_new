import 'profile_edit.dart';
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

/// Loading / checking / saving the signed-in user's own profile.
abstract interface class ProfileEditorRepository {
  Future<EditableProfile?> load(String uid);

  /// Reserved by someone else (your own reservation does not count).
  Future<bool> isNameTaken(String name, {required String uid});
  Future<bool> isPhoneTaken(String phone, {required String uid});

  /// Saves the profile and moves the name / phone reservations, atomically.
  /// Copies of the name / photo elsewhere are updated by the server.
  Future<void> save(EditableProfile original, ProfileDraft draft, {required String photoUrl});
}

/// Uploads a new profile photo; returns its download URL.
abstract interface class ProfilePhotoUploader {
  Future<String> upload(String uid, String localPath);
}

/// Phone number format check for a country (ISO code like 'JO').
abstract interface class PhoneNumberChecker {
  Future<bool> isValid(String phone, String isoCode);

  /// Splits a saved international number for the phone field: (ISO country code, national number).
  Future<(String, String)?> split(String phone);

  /// The device's country (SIM, then system region) for an empty phone field; 'US' when unknown.
  Future<String> deviceCountry();
}

/// Opens the gallery; returns the picked photo's local path (null when cancelled).
typedef ProfilePhotoPicker = Future<String?> Function();
