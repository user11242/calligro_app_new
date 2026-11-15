import 'package:calligro_app/features/classroom/application/classroom_assignments.dart';
import 'package:calligro_app/features/classroom/application/classroom_materials.dart';
import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:calligro_app/features/classroom/presentation/classroom_scope.dart';
import 'package:calligro_app/features/courses/application/course_purchases.dart';
import 'package:calligro_app/features/courses/presentation/course_scope.dart';
import 'package:calligro_app/features/teacher/pages/course_details/assignment_details_page.dart';
import 'package:calligro_app/features/teacher/pages/course_details/assignments_page.dart';
import 'package:calligro_app/features/teacher/pages/course_details/student_submissions_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../courses/fakes/course_fixtures.dart';
import '../../courses/fakes/fake_courses.dart';
import '../fakes/fake_classroom.dart';

/// The real assignment screens on fakes, with the real ClassroomAssignments.
void main() {
  late FakeAssignmentRepository repo;
  late FakeSubmissionFiles files;
  var uid = 's1';
  final now = DateTime.now();
  final open = Assignment(id: 'a1', title: 'Alif drills', instructions: 'Ten lines', dueDate: now.add(const Duration(days: 3)));
  final closed = Assignment(id: 'a2', title: 'Old drills', dueDate: now.subtract(const Duration(days: 1)));

  Future<void> settle(WidgetTester tester) async {
    // One real async gap: the fakes' one-shot reads (.first) finish outside fake time.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final classroom = ClassroomServices(
      assignments: ClassroomAssignments(repository: repo, files: files, currentUid: () => uid),
      materials: ClassroomMaterials(repository: FakeMaterialsRepository(), files: FakeMaterialFiles(), currentUid: () => uid),
    );
    final courses = CourseServices(
      courses: FakeCourseRepository()..put(courseDoc('c1', enrolled: ['s1'])),
      authoring: FakeAuthoring(),
      purchases: () => throw StateError('unused') as CoursePurchases,
      currentUid: () => uid,
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) =>
          CourseScope(services: courses, child: ClassroomScope(services: classroom, child: child!)),
      home: screen,
    ));
    await settle(tester);
  }

  // Created INSIDE each test: the fakes' streams must live in the widget test's zone.
  void init() {
    uid = 's1';
    repo = FakeAssignmentRepository()
      ..profiles['s1'] = (name: 'Sara', photoUrl: null)
      ..putAssignment('c1', open)
      ..putAssignment('c1', closed);
    files = FakeSubmissionFiles();
  }

  void testScreen(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        init();
        await body(tester);
      });

  group('assignments list', () {
    testScreen('students see the course\'s assignments, live', (tester) async {
      await pump(tester, const AssignmentsPage(courseId: 'c1', role: CourseRole.student));
      expect(find.text('Alif drills'), findsOneWidget);
      expect(find.text('Old drills'), findsOneWidget);
      repo.putAssignment('c1', Assignment(id: 'a3', title: 'New drills', dueDate: now.add(const Duration(days: 9))));
      await settle(tester);
      expect(find.text('New drills'), findsOneWidget);
    });

    testScreen('the teacher sees each assignment\'s live submission count', (tester) async {
      repo.putSubmission('c1', 'a1', const Submission(studentId: 's1', note: 'x'));
      repo.putSubmission('c1', 'a1', const Submission(studentId: 's2', note: 'y'));
      uid = 't1';
      await pump(tester, const AssignmentsPage(courseId: 'c1', role: CourseRole.owner));
      expect(find.text('2'), findsWidgets);
    });
  });

  group('a student\'s assignment page', () {
    testScreen('changing a submission updates only the note (file kept)', (tester) async {
      repo.putSubmission('c1', 'a1',
          const Submission(studentId: 's1', note: 'v1', fileUrl: 'https://files/s1_w.jpg', fileName: 'w.jpg'));
      await pump(tester, AssignmentDetailsPage(courseId: 'c1', assignment: open, role: CourseRole.student));
      expect(find.text('w.jpg'), findsOneWidget);

      await tester.tap(find.text('EDIT SUBMISSION'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'v2');
      await tester.tap(find.text('UPDATE SUBMISSION'));
      await settle(tester);

      final save = repo.saves.single;
      expect([save.isNew, save.input.note, save.input.fileUrl], [false, 'v2', 'https://files/s1_w.jpg']);
      expect(files.uploads, isEmpty);
    });

    testScreen('after the deadline it is locked (no edit, no delete)', (tester) async {
      repo.putSubmission('c1', 'a2', const Submission(studentId: 's1', note: 'v1', fileName: 'w.jpg', fileUrl: 'u'));
      await pump(tester, AssignmentDetailsPage(courseId: 'c1', assignment: closed, role: CourseRole.student));
      expect(find.text('Deadline Passed'), findsOneWidget);
      expect(find.text('EDIT SUBMISSION'), findsNothing);
      expect(find.text('DELETE SUBMISSION'), findsNothing);
    });

    testScreen('withdrawing before the deadline removes it', (tester) async {
      repo.putSubmission('c1', 'a1', const Submission(studentId: 's1', note: 'v1', fileName: 'w.jpg', fileUrl: 'u'));
      await pump(tester, AssignmentDetailsPage(courseId: 'c1', assignment: open, role: CourseRole.student));
      await tester.tap(find.text('DELETE SUBMISSION'));
      await settle(tester);
      await tester.tap(find.text('DELETE'));
      await settle(tester);
      expect(repo.submissions['c1/a1'], isEmpty);
    });
  });

  group('the teacher\'s submissions page', () {
    testScreen('lists work live and marks it reviewed', (tester) async {
      uid = 't1';
      repo.putSubmission('c1', 'a1', const Submission(studentId: 's1', studentName: 'Sara', note: 'my lines'));
      await pump(tester,
          const StudentSubmissionsPage(courseId: 'c1', assignmentId: 'a1', assignmentTitle: 'Alif', role: CourseRole.owner));
      expect(find.text('Sara'), findsOneWidget);
      await tester.tap(find.text('Sara'));
      await settle(tester);
      await tester.tap(find.text('Mark as Reviewed'));
      await settle(tester);
      expect(repo.seenCalls.single, (studentId: 's1', seen: true));
      expect(find.text('Marked as Reviewed'), findsOneWidget);
    });

    testScreen('a student role cannot mark work (even if the page were opened)', (tester) async {
      repo.putSubmission('c1', 'a1', const Submission(studentId: 's2', studentName: 'Omar', note: 'x'));
      await pump(tester,
          const StudentSubmissionsPage(courseId: 'c1', assignmentId: 'a1', assignmentTitle: 'Alif', role: CourseRole.student));
      await tester.tap(find.text('Omar'));
      await settle(tester);
      await tester.tap(find.text('Mark as Reviewed'));
      await settle(tester);
      expect(repo.seenCalls, isEmpty);
    });
  });
}
