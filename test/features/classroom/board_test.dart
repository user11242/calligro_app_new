import 'package:calligro_app/features/classroom/application/classroom_assignments.dart';
import 'package:calligro_app/features/classroom/application/classroom_board.dart';
import 'package:calligro_app/features/classroom/application/classroom_materials.dart';
import 'package:calligro_app/features/classroom/data/firestore_board_repository.dart';
import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:calligro_app/features/classroom/domain/course_board.dart';
import 'package:calligro_app/features/classroom/presentation/classroom_scope.dart';
import 'package:calligro_app/features/teacher/pages/course_details/announcements_board_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_classroom.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ClassroomBoard board;

  final change = SessionChange(
    originalDate: DateTime(2026, 12, 2),
    newStart: DateTime(2026, 12, 2, 19),
    newEnd: DateTime(2026, 12, 2, 20),
    title: 'Session rescheduled',
    message: 'Moved to 7:00 PM',
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    board = ClassroomBoard(repository: FirestoreBoardRepository(firestore: db), currentUid: () => 't1');
    await db.doc('users/t1').set({'name': 'Ustadh Ali'});
    await db.doc('courses/c1').set({'teacherId': 't1', 'enrolledStudents': ['s1', 's2']});
  });

  test('moving the session sets it AND tells every current student', () async {
    expect((await board.reschedule('c1', CourseRole.owner, change)).ok, isTrue);
    final session = (await db.doc('courses/c1').get()).data()!['rescheduledSession'] as Map;
    expect((session['newStartTime'] as Timestamp).toDate(), DateTime(2026, 12, 2, 19));
    for (final s in ['s1', 's2']) {
      final n = (await db.collection('users/$s/notifications').get()).docs.single.data();
      expect([n['title'], n['message'], n['type'], n['courseId'], n['isRead']],
          ['Session rescheduled', 'Moved to 7:00 PM', 'reschedule', 'c1', false]);
    }
    expect((await board.cancelReschedule('c1', CourseRole.owner)).ok, isTrue);
    expect((await db.doc('courses/c1').get()).data()!.containsKey('rescheduledSession'), isFalse);
  });

  test('students cannot move sessions or post; an end before the start is refused', () async {
    expect((await board.reschedule('c1', CourseRole.student, change)).outcome, ClassroomOutcome.notAllowed);
    expect((await board.post('c1', CourseRole.visitor, 'x')).outcome, ClassroomOutcome.notAllowed);
    final backwards = SessionChange(
        originalDate: change.originalDate, newStart: change.newEnd, newEnd: change.newStart, title: '', message: '');
    expect((await board.reschedule('c1', CourseRole.owner, backwards)).outcome, ClassroomOutcome.invalid);
    expect((await db.collection('users/s1/notifications').get()).docs, isEmpty);
  });

  test('announcements are posted under the teacher\'s profile name, newest first', () async {
    expect((await board.post('c1', CourseRole.owner, '  Bring ink  ')).ok, isTrue);
    expect((await board.post('c1', CourseRole.owner, ' ')).outcome, ClassroomOutcome.empty);
    final list = await board.repository.watchAnnouncements('c1').first;
    expect([list.single.message, list.single.senderName], ['Bring ink', 'Ustadh Ali']);
  });

  testWidgets('the board screen: the teacher posts, the feed shows it', (tester) async {
    final services = ClassroomServices(
      assignments: ClassroomAssignments(repository: FakeAssignmentRepository(), files: FakeSubmissionFiles(), currentUid: () => 't1'),
      materials: ClassroomMaterials(repository: FakeMaterialsRepository(), files: FakeMaterialFiles(), currentUid: () => 't1'),
      board: board,
    );
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => ClassroomScope(services: services, child: child!),
      home: const AnnouncementsBoardPage(courseId: 'c1', courseName: 'Thuluth', role: CourseRole.owner),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Class at 7 today');
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Class at 7 today'), findsOneWidget);
  });
}
