import '../domain/classroom_models.dart';
import '../domain/classroom_repositories.dart';
import '../domain/course_board.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'classroom_assignments.dart' show ClassroomOutcome, ClassroomResult;

/// The course's teacher (or an admin) posts announcements and moves the NEXT
/// class; the server checks the move again, moves the course dates when the
/// first / last class moves, and notifies the students once.
class ClassroomBoard {
  ClassroomBoard({required BoardRepository repository, required String Function() currentUid, DateTime Function()? clock})
      : _repo = repository,
        _uid = currentUid,
        _now = clock ?? DateTime.now;

  final BoardRepository _repo;
  final String Function() _uid;
  final DateTime Function() _now;
  bool _busy = false;

  BoardRepository get repository => _repo;

  Future<ClassroomResult> post(String courseId, CourseRole role, String message) => _run(role, () async {
        if (message.trim().isEmpty) return const ClassroomResult(ClassroomOutcome.empty);
        final name = await _repo.displayName(_uid());
        await _repo.postAnnouncement(courseId, message: message.trim(), senderName: name.isEmpty ? 'Instructor' : name);
        return const ClassroomResult(ClassroomOutcome.done);
      });

  /// Moves the next class of [schedule] (checked here first, for a clear answer).
  Future<ClassroomResult> reschedule(String courseId, CourseRole role, CourseSchedule schedule, SessionChange change) =>
      _run(role, () async {
        final plan = schedule.planMove(now: _now(), newStart: change.newStart, newEnd: change.newEnd);
        if (!plan.ok) return ClassroomResult(ClassroomOutcome.invalid, rescheduleError: plan.error);
        try {
          await _repo.reschedule(courseId, SessionChange(newStart: change.newStart, newEnd: change.newEnd, note: change.note.trim()));
        } on RescheduleRefused catch (e) {
          return ClassroomResult(ClassroomOutcome.invalid, rescheduleError: e.reason);
        }
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
