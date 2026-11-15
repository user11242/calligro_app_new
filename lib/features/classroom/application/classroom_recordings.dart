import '../domain/classroom_models.dart';
import '../domain/classroom_repositories.dart';
import 'classroom_assignments.dart' show ClassroomOutcome, ClassroomResult;

/// Recordings: members watch (signed links, MeetBackend.playback); only the
/// course's teacher / an admin renames them.
class ClassroomRecordings {
  ClassroomRecordings({required RecordingsRepository repository}) : _repo = repository;
  final RecordingsRepository _repo;

  RecordingsRepository get repository => _repo;

  Future<ClassroomResult> rename(String courseId, CourseRole role, String recordingId, String? title) async {
    if (!role.canManage) return const ClassroomResult(ClassroomOutcome.notAllowed);
    try {
      await _repo.rename(courseId, recordingId, title);
      return const ClassroomResult(ClassroomOutcome.done);
    } catch (e) {
      return ClassroomResult(ClassroomOutcome.failed, message: '$e');
    }
  }
}
