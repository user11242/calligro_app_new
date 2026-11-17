import 'classroom_models.dart';
import 'course_board.dart';
import 'course_materials.dart';
import 'course_recordings.dart';

/// Assignments and submissions of one course (firestore.rules decides who may
/// do what; these interfaces only describe the data).
abstract interface class AssignmentRepository {
  /// By due date, soonest first, live.
  Stream<List<Assignment>> watchAssignments(String courseId);
  Future<String> createAssignment(String courseId, AssignmentDraft draft);

  /// Newest first, live (teacher).
  Stream<List<Submission>> watchSubmissions(String courseId, String assignmentId);

  /// The student's own submission, live (null = not handed in).
  Stream<Submission?> watchSubmission(String courseId, String assignmentId, String studentId);

  /// Creates or replaces the student's fields; teacher fields are left alone.
  Future<void> saveSubmission(String courseId, String assignmentId, String studentId, SubmissionInput input,
      {required bool isNew});
  Future<void> deleteSubmission(String courseId, String assignmentId, String studentId);
  Future<void> setSeen(String courseId, String assignmentId, String studentId, bool seen);

  /// The student's name/photo as stored on their profile.
  Future<({String name, String? photoUrl})> studentProfile(String uid);
}

/// Where submission files live (Firebase Storage today).
abstract interface class SubmissionFiles {
  /// Uploads the file at [localPath] as `uid_fileName` and returns its URL.
  Future<String> upload({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String localPath,
    required String fileName,
  });
}

/// Course material folders (courses/{id}/materials).
abstract interface class MaterialsRepository {
  /// Newest first, live.
  Stream<List<CourseMaterialFolder>> watchFolders(String courseId);
  Stream<CourseMaterialFolder?> watchFolder(String courseId, String folderId);
  Future<String> createFolder(String courseId, Map<String, dynamic> folder);
  Future<void> renameFolder(String courseId, String folderId, String title);
  Future<void> deleteFolder(String courseId, String folderId);
  Future<void> replaceFiles(String courseId, String folderId, List<CourseMaterialFileItem> files);
  Future<String> displayName(String uid);
}

/// Where material files live (Firebase Storage today).
abstract interface class MaterialFiles {
  /// Returns the download URL and the storage path (kept for deletion).
  Future<({String url, String storagePath})> upload(String courseId, String localPath, String fileName);
  Future<void> delete(String storagePath);
}

/// Class recordings (courses/{id}/recordings).
abstract interface class RecordingsRepository {
  /// Newest first, live.
  Stream<List<CourseRecording>> watchRecordings(String courseId);

  /// [title] null/empty = back to "Lesson N".
  Future<void> rename(String courseId, String recordingId, String? title);
}

/// Announcements board and session changes of one course.
abstract interface class BoardRepository {
  /// Newest first, live.
  Stream<List<Announcement>> watchAnnouncements(String courseId);
  Future<void> postAnnouncement(String courseId, {required String message, required String senderName});

  /// Asks the server to move the next class (it checks the rule, moves the course
  /// dates when needed and notifies the students once). Throws [RescheduleRefused].
  Future<void> reschedule(String courseId, SessionChange change);

  /// Asks the server to put the next class back at its usual time.
  Future<void> cancelReschedule(String courseId);
  Future<String> displayName(String uid);
}
