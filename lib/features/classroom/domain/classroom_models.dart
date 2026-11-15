/// Inside a course: who may do what, assignments and submissions (pure Dart).
library;

/// The viewer's place in ONE course. Being a teacher somewhere else gives no
/// rights here (the old page treated every teacher as this course's teacher).
enum CourseRole {
  owner,
  student,
  admin,
  visitor;

  /// Upload materials, create assignments, read submissions, reschedule.
  bool get canManage => this == owner || this == admin;

  /// Read paid content (materials, assignments, recordings, chat).
  bool get isMember => this != visitor;
}

class ClassroomAccess {
  ClassroomAccess._();

  static CourseRole roleOf({
    required String teacherId,
    required List<String> enrolledStudents,
    required String uid,
    bool isAdmin = false,
  }) {
    if (uid.isEmpty) return CourseRole.visitor;
    if (teacherId == uid) return CourseRole.owner;
    if (enrolledStudents.contains(uid)) return CourseRole.student;
    if (isAdmin) return CourseRole.admin;
    return CourseRole.visitor;
  }
}

DateTime? _date(Object? v) {
  if (v is DateTime) return v;
  try {
    // Firestore Timestamp (kept out of the domain's imports).
    final dynamic t = v;
    if (v != null) return t.toDate() as DateTime;
  } catch (_) {}
  return null;
}

String _s(Object? v) => v is String ? v : '';

class Assignment {
  final String id;
  final String title;
  final String instructions;
  final DateTime? dueDate;
  final DateTime? createdAt;

  /// Practice sheet template ('paper1.jpg' …), when the teacher attached one.
  final String? practiceSheet;
  final Map<String, dynamic> raw;

  const Assignment({
    required this.id,
    this.title = '',
    this.instructions = '',
    this.dueDate,
    this.createdAt,
    this.practiceSheet,
    this.raw = const {},
  });

  factory Assignment.fromMap(String id, Map<String, dynamic> d) => Assignment(
        id: id,
        title: _s(d['title']),
        instructions: _s(d['instructions']),
        dueDate: _date(d['dueDate']),
        createdAt: _date(d['createdAt']),
        practiceSheet: d['practiceSheet'] is String ? d['practiceSheet'] as String : null,
        raw: Map.unmodifiable(d),
      );

  /// Open for submissions (and changes) until the due date — the server
  /// enforces the same moment (firestore.rules).
  bool isOpenAt(DateTime now) => dueDate != null && now.isBefore(dueDate!);
}

enum AssignmentProblem { missingTitle, missingDueDate }

class AssignmentDraft {
  final String title;
  final String instructions;
  final DateTime? dueDate;
  final String? practiceSheet;

  const AssignmentDraft({this.title = '', this.instructions = '', this.dueDate, this.practiceSheet});

  List<AssignmentProblem> get problems => [
        if (title.trim().isEmpty) AssignmentProblem.missingTitle,
        if (dueDate == null) AssignmentProblem.missingDueDate,
      ];

  /// [dueDate] / [createdAt] are converted by the data layer.
  Map<String, dynamic> toDocument({required Object dueDate, required Object createdAt}) => {
        'title': title.trim(),
        'instructions': instructions.trim(),
        'dueDate': dueDate,
        'createdAt': createdAt,
        if (practiceSheet != null) 'practiceSheet': practiceSheet,
      };
}

class Submission {
  final String studentId;
  final String studentName;
  final String? studentImage;
  final String note;
  final String? fileUrl;
  final String? fileName;
  final DateTime? submittedAt;
  final bool seenByTeacher;

  /// Teacher-owned grading (web portal "Homeworks"): 'submitted' | 'graded' | …
  final String status;
  final int? points;
  final String feedback;

  const Submission({
    required this.studentId,
    this.studentName = '',
    this.studentImage,
    this.note = '',
    this.fileUrl,
    this.fileName,
    this.submittedAt,
    this.seenByTeacher = false,
    this.status = 'submitted',
    this.points,
    this.feedback = '',
  });

  bool get isGraded => status == 'graded';

  factory Submission.fromMap(String id, Map<String, dynamic> d) => Submission(
        studentId: d['studentId'] is String ? d['studentId'] as String : id,
        studentName: _s(d['studentName']),
        studentImage: d['studentImage'] is String ? d['studentImage'] as String : null,
        note: _s(d['note']),
        fileUrl: d['fileUrl'] is String ? d['fileUrl'] as String : null,
        fileName: d['fileName'] is String ? d['fileName'] as String : null,
        submittedAt: _date(d['submittedAt']),
        seenByTeacher: d['seenByTeacher'] == true,
        status: d['status'] is String ? d['status'] as String : 'submitted',
        points: d['points'] is num ? (d['points'] as num).toInt() : null,
        feedback: _s(d['feedback']),
      );
}

/// What a student hands in. Teacher-owned fields (seen, grade) are NOT here,
/// so a student can never write them (firestore.rules agrees).
class SubmissionInput {
  final String note;
  final String? fileUrl;
  final String? fileName;
  final String studentName;
  final String? studentImage;

  const SubmissionInput({this.note = '', this.fileUrl, this.fileName, this.studentName = '', this.studentImage});

  bool get isEmpty => note.trim().isEmpty && (fileUrl == null || fileUrl!.isEmpty);

  /// The fields a student writes. [submittedAt] is the server time.
  Map<String, dynamic> toDocument(String studentId, {required Object submittedAt, bool includeId = true}) => {
        'note': note.trim(),
        'fileUrl': fileUrl,
        'fileName': fileName,
        'submittedAt': submittedAt,
        'studentName': studentName,
        'studentImage': studentImage,
        if (includeId) 'studentId': studentId,
      };
}
