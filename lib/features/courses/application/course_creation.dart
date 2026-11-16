import '../domain/course_draft.dart';
import '../domain/course_repositories.dart';

enum CreateCourseOutcome { created, notSignedIn, needsPayout, needsCommission, invalid, busy, failed }

class CreateCourseResult {
  final CreateCourseOutcome outcome;
  final String? courseId;
  final List<DraftProblem> problems;
  final String? message;
  const CreateCourseResult(this.outcome, {this.courseId, this.problems = const [], this.message});
}

/// Creating a course (the add-course wizard's last step). Checks, in order:
/// signed in → a complete draft → payout details saved → share set by an
/// admin → ONE atomic write. The teacher is re-read every time, so payout
/// details saved a moment ago (from the wizard's dialog) count at once.
class CourseCreation {
  CourseCreation({required CourseAuthoring authoring, required String Function() currentUid})
      : _authoring = authoring,
        _uid = currentUid;

  final CourseAuthoring _authoring;
  final String Function() _uid;
  bool _saving = false;

  /// For the wizard's price step (teacher's share) before anything is saved.
  Future<CourseAuthor?> loadAuthor() async {
    final uid = _uid();
    return uid.isEmpty ? null : _authoring.author(uid);
  }

  Future<CreateCourseResult> create(
    CourseDraft draft, {
    String generatedName = '',
    String meetLink = '',
  }) async {
    if (_saving) return const CreateCourseResult(CreateCourseOutcome.busy);
    final uid = _uid();
    if (uid.isEmpty) return const CreateCourseResult(CreateCourseOutcome.notSignedIn);
    final problems = draft.problems;
    if (problems.isNotEmpty) return CreateCourseResult(CreateCourseOutcome.invalid, problems: problems);

    _saving = true;
    try {
      final author = await _authoring.author(uid);
      if (author == null) return const CreateCourseResult(CreateCourseOutcome.notSignedIn);
      if (!author.hasPayoutInfo) return const CreateCourseResult(CreateCourseOutcome.needsPayout);
      if (!author.hasCommissionRate) return const CreateCourseResult(CreateCourseOutcome.needsCommission);
      final id = await _authoring.create(draft, author,
          generatedName: generatedName, meetLink: meetLink);
      return CreateCourseResult(CreateCourseOutcome.created, courseId: id);
    } catch (e) {
      return CreateCourseResult(CreateCourseOutcome.failed, message: '$e');
    } finally {
      _saving = false;
    }
  }
}
