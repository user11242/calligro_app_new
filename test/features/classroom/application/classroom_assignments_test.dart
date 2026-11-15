import 'dart:async';

import 'package:calligro_app/features/classroom/application/classroom_assignments.dart';
import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_classroom.dart';

void main() {
  late FakeAssignmentRepository repo;
  late FakeSubmissionFiles files;
  late ClassroomAssignments work;
  var now = DateTime(2026, 12, 1, 12);
  var uid = 's1';
  final open = Assignment(id: 'a1', title: 'Alif', dueDate: DateTime(2026, 12, 5));

  setUp(() {
    now = DateTime(2026, 12, 1, 12);
    uid = 's1';
    repo = FakeAssignmentRepository()..profiles['s1'] = (name: 'Sara', photoUrl: 'sara.jpg');
    files = FakeSubmissionFiles();
    work = ClassroomAssignments(repository: repo, files: files, currentUid: () => uid, clock: () => now);
  });

  group('creating assignments', () {
    test('owner/admin with a complete draft', () async {
      final r = await work.createAssignment('c1', CourseRole.owner, AssignmentDraft(title: 'Ba', dueDate: DateTime(2026, 12, 9)));
      expect(r.ok, isTrue);
      expect(repo.assignments['c1']!.values.single.title, 'Ba');
      expect((await work.createAssignment('c1', CourseRole.admin, AssignmentDraft(title: 'Ta', dueDate: now))).ok, isTrue);
    });
    test('students / visitors / other teachers cannot', () async {
      for (final role in [CourseRole.student, CourseRole.visitor]) {
        expect((await work.createAssignment('c1', role, AssignmentDraft(title: 'x', dueDate: now))).outcome,
            ClassroomOutcome.notAllowed);
      }
      expect(repo.assignments, isEmpty);
    });
    test('missing title / due date → problems', () async {
      final r = await work.createAssignment('c1', CourseRole.owner, const AssignmentDraft());
      expect(r.outcome, ClassroomOutcome.invalid);
      expect(r.problems, hasLength(2));
    });
  });

  group('handing in', () {
    test('first submission: file uploaded under the student id, name from the profile', () async {
      final r = await work.submit('c1', open, CourseRole.student, note: 'done', localPath: '/tmp/w.jpg', fileName: 'w.jpg');
      expect(r.ok, isTrue);
      expect(files.uploads, ['c1/a1/s1_w.jpg']);
      final save = repo.saves.single;
      expect([save.isNew, save.input.fileUrl, save.input.studentName, save.input.studentImage],
          [true, 'https://files/s1_w.jpg', 'Sara', 'sara.jpg']);
    });

    test('changing it keeps the old file when no new one is picked, and is an update', () async {
      await work.submit('c1', open, CourseRole.student, note: 'v1', localPath: '/tmp/w.jpg', fileName: 'w.jpg');
      final existing = repo.submissions['c1/a1']!['s1'];
      final r = await work.submit('c1', open, CourseRole.student, note: 'v2', existing: existing);
      expect(r.ok, isTrue);
      expect([repo.saves.last.isNew, repo.saves.last.input.fileUrl, repo.saves.last.input.note],
          [false, 'https://files/s1_w.jpg', 'v2']);
      expect(files.uploads, hasLength(1));
    });

    test('a changed submission keeps the teacher\'s "seen" mark', () async {
      await work.submit('c1', open, CourseRole.student, note: 'v1');
      await work.setSeen('c1', 'a1', 's1', CourseRole.owner, true);
      await work.submit('c1', open, CourseRole.student, note: 'v2', existing: repo.submissions['c1/a1']!['s1']);
      expect(repo.submissions['c1/a1']!['s1']!.seenByTeacher, isTrue);
    });

    test('after the due date: refused, nothing uploaded', () async {
      now = DateTime(2026, 12, 5);
      final r = await work.submit('c1', open, CourseRole.student, note: 'late', localPath: '/tmp/w.jpg', fileName: 'w.jpg');
      expect(r.outcome, ClassroomOutcome.closed);
      expect(files.uploads, isEmpty);
      expect(repo.saves, isEmpty);
    });

    test('only enrolled students hand in (not the teacher, admins or visitors)', () async {
      for (final role in [CourseRole.owner, CourseRole.admin, CourseRole.visitor]) {
        expect((await work.submit('c1', open, role, note: 'x')).outcome, ClassroomOutcome.notAllowed);
      }
      uid = '';
      expect((await work.submit('c1', open, CourseRole.student, note: 'x')).outcome, ClassroomOutcome.notAllowed);
    });

    test('nothing to hand in', () async {
      expect((await work.submit('c1', open, CourseRole.student, note: '  ')).outcome, ClassroomOutcome.empty);
    });

    test('double tap while uploading → one submission', () async {
      files.hold = Completer<void>();
      final first = work.submit('c1', open, CourseRole.student, note: 'x', localPath: '/p', fileName: 'f.jpg');
      await Future<void>.delayed(Duration.zero);
      expect((await work.submit('c1', open, CourseRole.student, note: 'x')).outcome, ClassroomOutcome.busy);
      files.hold!.complete();
      expect((await first).ok, isTrue);
      expect(repo.saves, hasLength(1));
    });

    test('a failed write is reported and can be retried', () async {
      repo.failWrites = Exception('offline');
      final r = await work.submit('c1', open, CourseRole.student, note: 'x');
      expect([r.outcome, r.message], [ClassroomOutcome.failed, 'Exception: offline']);
      repo.failWrites = null;
      expect((await work.submit('c1', open, CourseRole.student, note: 'x')).ok, isTrue);
    });
  });

  group('withdrawing and marking seen', () {
    test('withdraw before the due date only', () async {
      await work.submit('c1', open, CourseRole.student, note: 'x');
      now = DateTime(2026, 12, 6);
      expect((await work.withdraw('c1', open, CourseRole.student)).outcome, ClassroomOutcome.closed);
      now = DateTime(2026, 12, 2);
      expect((await work.withdraw('c1', open, CourseRole.student)).ok, isTrue);
      expect(repo.submissions['c1/a1'], isEmpty);
    });

    test('only the course\'s teacher/admin marks work as seen', () async {
      await work.submit('c1', open, CourseRole.student, note: 'x');
      expect((await work.setSeen('c1', 'a1', 's1', CourseRole.student, true)).outcome, ClassroomOutcome.notAllowed);
      expect((await work.setSeen('c1', 'a1', 's1', CourseRole.owner, true)).ok, isTrue);
      expect(repo.seenCalls.single.seen, isTrue);
    });
  });
}
