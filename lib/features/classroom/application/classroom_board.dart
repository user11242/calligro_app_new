import '../domain/classroom_models.dart';
import '../domain/classroom_repositories.dart';
import '../domain/course_board.dart';
import 'classroom_assignments.dart' show ClassroomOutcome, ClassroomResult;

/// The course's teacher (or an admin) posts announcements and moves today's
/// session; students are notified in the same write.
class ClassroomBoard {
  ClassroomBoard({required BoardRepository repository, required String Function() currentUid})
      : _repo = repository,
        _uid = currentUid;

  final BoardRepository _repo;
  final String Function() _uid;
  bool _busy = false;

  BoardRepository get repository => _repo;

  Future<ClassroomResult> post(String courseId, CourseRole role, String message) => _run(role, () async {
        if (message.trim().isEmpty) return const ClassroomResult(ClassroomOutcome.empty);
        final name = await _repo.displayName(_uid());
        await _repo.postAnnouncement(courseId, message: message.trim(), senderName: name.isEmpty ? 'Instructor' : name);
        return const ClassroomResult(ClassroomOutcome.done);
      });

  Future<ClassroomResult> reschedule(String courseId, CourseRole role, SessionChange change) => _run(role, () async {
        if (!change.isValid) return const ClassroomResult(ClassroomOutcome.invalid);
        await _repo.reschedule(courseId, change);
        return const ClassroomResult(ClassroomOutcome.done);
      });

  Future<ClassroomResult> cancelReschedule(String courseId, CourseRole role) => _run(role, () async {
        await _repo.cancelReschedule(courseId);
        return const ClassroomResult(ClassroomOutcome.done);
      });

  Future<ClassroomResult> _run(CourseRole role, Future<ClassroomResult> Function() body) async {
    if (!role.canManage) return const ClassroomResult(ClassroomOutcome.notAllowed);
    if (_busy) return const ClassroomResult(ClassroomOutcome.busy);
    _busy = true;
    try {
      return await body();
    } catch (e) {
      return ClassroomResult(ClassroomOutcome.failed, message: '$e');
    } finally {
      _busy = false;
    }
  }
}
