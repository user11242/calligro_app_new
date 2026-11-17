import '../domain/classroom_models.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart' show RescheduleError;
import '../domain/classroom_repositories.dart';

enum ClassroomOutcome { done, notAllowed, invalid, closed, empty, busy, failed }

class ClassroomResult {
  final ClassroomOutcome outcome;
  final String? id;
  final String? message;
  final List<AssignmentProblem> problems;

  /// Why moving a class was refused (by the rule here or by the server).
  final RescheduleError? rescheduleError;
  const ClassroomResult(this.outcome, {this.id, this.message, this.problems = const [], this.rescheduleError});
  bool get ok => outcome == ClassroomOutcome.done;
}

/// Assignments inside a course: the teacher creates them and marks work as
/// seen; enrolled students hand in, change or withdraw work until the due
/// date. The same rules are enforced by firestore.rules; this layer gives the
/// screens a clear answer instead of a permission error.
class ClassroomAssignments {
  ClassroomAssignments({
    required AssignmentRepository repository,
    required SubmissionFiles files,
    required String Function() currentUid,
    DateTime Function()? clock,
  })  : _repo = repository,
        _files = files,
        _uid = currentUid,
        _now = clock ?? DateTime.now;

  final AssignmentRepository _repo;
  final SubmissionFiles _files;
  final String Function() _uid;
  final DateTime Function() _now;
  bool _busy = false;

  String get currentUid => _uid();
  AssignmentRepository get repository => _repo;

  Future<ClassroomResult> createAssignment(String courseId, CourseRole role, AssignmentDraft draft) =>
      _guard(() async {
        if (!role.canManage) return const ClassroomResult(ClassroomOutcome.notAllowed);
        if (draft.problems.isNotEmpty) {
          return ClassroomResult(ClassroomOutcome.invalid, problems: draft.problems);
        }
        return ClassroomResult(ClassroomOutcome.done, id: await _repo.createAssignment(courseId, draft));
      });

  /// Hand in (or change) work. [localPath]/[fileName]: a newly picked file
  /// (already watermarked by the screen); otherwise the existing file stays.
  Future<ClassroomResult> submit(
    String courseId,
    Assignment assignment,
    CourseRole role, {
    required String note,
    Submission? existing,
    String? localPath,
    String? fileName,
  }) =>
      _guard(() async {
        final uid = _uid();
        if (role != CourseRole.student || uid.isEmpty) return const ClassroomResult(ClassroomOutcome.notAllowed);
        if (!assignment.isOpenAt(_now())) return const ClassroomResult(ClassroomOutcome.closed);
        if (note.trim().isEmpty && localPath == null && existing?.fileUrl == null) {
          return const ClassroomResult(ClassroomOutcome.empty);
        }
        var fileUrl = existing?.fileUrl;
        var name = existing?.fileName;
        if (localPath != null && fileName != null) {
          fileUrl = await _files.upload(
              courseId: courseId, assignmentId: assignment.id, studentId: uid, localPath: localPath, fileName: fileName);
          name = fileName;
        }
        final me = await _repo.studentProfile(uid);
        await _repo.saveSubmission(
          courseId,
          assignment.id,
          uid,
          SubmissionInput(note: note, fileUrl: fileUrl, fileName: name, studentName: me.name, studentImage: me.photoUrl),
          isNew: existing == null,
        );
        return const ClassroomResult(ClassroomOutcome.done);
      });

  Future<ClassroomResult> withdraw(String courseId, Assignment assignment, CourseRole role) => _guard(() async {
        final uid = _uid();
        if (role != CourseRole.student || uid.isEmpty) return const ClassroomResult(ClassroomOutcome.notAllowed);
        if (!assignment.isOpenAt(_now())) return const ClassroomResult(ClassroomOutcome.closed);
        await _repo.deleteSubmission(courseId, assignment.id, uid);
        return const ClassroomResult(ClassroomOutcome.done);
      });

  Future<ClassroomResult> setSeen(String courseId, String assignmentId, String studentId, CourseRole role, bool seen) =>
      _guard(() async {
        if (!role.canManage) return const ClassroomResult(ClassroomOutcome.notAllowed);
        await _repo.setSeen(courseId, assignmentId, studentId, seen);
        return const ClassroomResult(ClassroomOutcome.done);
      }, exclusive: false);

  Future<ClassroomResult> _guard(Future<ClassroomResult> Function() run, {bool exclusive = true}) async {
    if (exclusive && _busy) return const ClassroomResult(ClassroomOutcome.busy);
    if (exclusive) _busy = true;
    try {
      return await run();
    } catch (e) {
      return ClassroomResult(ClassroomOutcome.failed, message: '$e');
    } finally {
      if (exclusive) _busy = false;
    }
  }
}
