import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('role in ONE course', () {
    CourseRole role(String uid, {bool admin = false}) =>
        ClassroomAccess.roleOf(teacherId: 't1', enrolledStudents: const ['s1'], uid: uid, isAdmin: admin);

    test('owner, student, admin, visitor', () {
      expect(role('t1'), CourseRole.owner);
      expect(role('s1'), CourseRole.student);
      expect(role('boss', admin: true), CourseRole.admin);
      expect(role('stranger'), CourseRole.visitor);
      expect(role(''), CourseRole.visitor);
    });

    test('a teacher of ANOTHER course is just a visitor here (the old page gave them teacher controls)', () {
      expect(role('t2'), CourseRole.visitor);
      expect(role('t2').canManage, isFalse);
    });

    test('who manages / who is a member', () {
      expect([CourseRole.owner, CourseRole.admin].every((r) => r.canManage), isTrue);
      expect([CourseRole.student, CourseRole.visitor].any((r) => r.canManage), isFalse);
      expect(CourseRole.student.isMember, isTrue);
      expect(CourseRole.visitor.isMember, isFalse);
    });
  });

  group('assignment', () {
    final due = DateTime(2026, 12, 10, 18);
    final a = Assignment.fromMap('a1', {
      'title': 'Alif drills',
      'instructions': 'Ten lines',
      'dueDate': Timestamp.fromDate(due),
      'practiceSheet': 'paper2.jpg',
    });

    test('reads the stored fields (Timestamp dates)', () {
      expect([a.title, a.instructions, a.dueDate, a.practiceSheet], ['Alif drills', 'Ten lines', due, 'paper2.jpg']);
    });

    test('open until the due date, closed from that moment', () {
      expect(a.isOpenAt(due.subtract(const Duration(minutes: 1))), isTrue);
      expect(a.isOpenAt(due), isFalse);
      expect(const Assignment(id: 'x').isOpenAt(DateTime(2000)), isFalse, reason: 'no due date = not open');
    });

    test('draft problems and document', () {
      expect(const AssignmentDraft().problems, [AssignmentProblem.missingTitle, AssignmentProblem.missingDueDate]);
      final doc = AssignmentDraft(title: '  Ba  ', dueDate: due).toDocument(dueDate: 'D', createdAt: 'C');
      expect(doc, {'title': 'Ba', 'instructions': '', 'dueDate': 'D', 'createdAt': 'C'});
      expect(doc.containsKey('submissionCount'), isFalse, reason: 'nobody reads it; clients may no longer write it');
    });
  });

  group('submission', () {
    test('a student writes only student fields (never seen / grade)', () {
      const input = SubmissionInput(note: ' done ', fileUrl: 'u', fileName: 'f.jpg', studentName: 'Sara');
      final doc = input.toDocument('s1', submittedAt: 'NOW');
      expect(doc.keys.toSet(), {'note', 'fileUrl', 'fileName', 'submittedAt', 'studentName', 'studentImage', 'studentId'});
      expect(doc['note'], 'done');
      expect(input.toDocument('s1', submittedAt: 'NOW', includeId: false).containsKey('studentId'), isFalse);
    });

    test('empty = no note and no file', () {
      expect(const SubmissionInput().isEmpty, isTrue);
      expect(const SubmissionInput(note: 'x').isEmpty, isFalse);
      expect(const SubmissionInput(fileUrl: 'u').isEmpty, isFalse);
    });

    test('reads the teacher\'s grading (web portal) for the student to see', () {
      final s = Submission.fromMap('s1', {'status': 'graded', 'points': 9, 'feedback': 'Lovely alif'});
      expect([s.isGraded, s.points, s.feedback], [true, 9, 'Lovely alif']);
      expect(Submission.fromMap('s1', const {}).status, 'submitted');
    });

    test('reads older documents (status/points present, studentId missing)', () {
      final s = Submission.fromMap('s9', {'note': 'n', 'status': 'submitted', 'points': 0, 'seenByTeacher': true});
      expect([s.studentId, s.note, s.seenByTeacher], ['s9', 'n', true]);
    });
  });
}
