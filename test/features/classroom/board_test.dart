import 'package:calligro_app/features/classroom/application/classroom_assignments.dart';
import 'package:calligro_app/features/classroom/application/classroom_board.dart';
import 'package:calligro_app/features/classroom/application/classroom_materials.dart';
import 'package:calligro_app/features/classroom/data/firestore_board_repository.dart';
import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:calligro_app/features/classroom/domain/course_board.dart';
import 'package:calligro_app/features/classroom/presentation/classroom_scope.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:calligro_app/features/classroom/presentation/pages/announcements_board_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_classroom.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ClassroomBoard board;
  late List<(String, Map<String, dynamic>)> calls;
  Object? serverError;

  // Mon & Wed 18:00-19:30 (UTC+3), 30 Nov – 16 Dec 2026 (test/fixtures/schedule_cases.json).
  final schedule = CourseSchedule(
    weekdays: const {1, 3},
    startDate: DateTime.parse('2026-11-29T21:00:00Z'),
    endDate: DateTime.parse('2026-12-15T21:00:00Z'),
    startTime: DateTime.parse('2026-11-20T15:00:00Z'),
    endTime: DateTime.parse('2026-11-20T16:30:00Z'),
    utcOffset: const Duration(hours: 3),
  );
  final now = DateTime.parse('2026-12-03T09:00:00Z');
  final ok = SessionChange(
      newStart: DateTime.parse('2026-12-07T17:00:00Z'), newEnd: DateTime.parse('2026-12-07T18:00:00Z'), note: '  Bring ink  ');

  setUp(() async {
    db = FakeFirebaseFirestore();
    calls = [];
    serverError = null;
    board = ClassroomBoard(
      repository: FirestoreBoardRepository(
        firestore: db,
        call: (name, data) async {
          calls.add((name, data));
          if (serverError != null) throw serverError!;
          return null;
        },
      ),
      currentUid: () => 't1',
      clock: () => now,
    );
    await db.doc('users/t1').set({'name': 'Ustadh Ali'});
    await db.doc('courses/c1').set({'teacherId': 't1', 'enrolledStudents': ['s1', 's2']});
  });

  test('moving the next class goes to the SERVER (which checks it, changes dates and notifies once)', () async {
    expect((await board.reschedule('c1', CourseRole.owner, schedule, ok)).ok, isTrue);
    expect(calls.single.$1, 'rescheduleNextSession');
    expect(calls.single.$2, {
      'courseId': 'c1',
      'newStart': DateTime.parse('2026-12-07T17:00:00Z').millisecondsSinceEpoch,
      'newEnd': DateTime.parse('2026-12-07T18:00:00Z').millisecondsSinceEpoch,
      'note': 'Bring ink',
      'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    });
    // The app writes nothing itself (no notices, no course fields).
    expect((await db.doc('courses/c1').get()).data()!.containsKey('rescheduledSession'), isFalse);
    for (final s in ['s1', 's2']) {
      expect((await db.collection('users/$s/notifications').get()).docs, isEmpty);
    }
  });

  test('a move the rule refuses never reaches the server, and says why', () async {
    final onFollowingDay = SessionChange(
        newStart: DateTime.parse('2026-12-09T09:00:00Z'), newEnd: DateTime.parse('2026-12-09T10:00:00Z'));
    final r = await board.reschedule('c1', CourseRole.owner, schedule, onFollowingDay);
    expect(r.outcome, ClassroomOutcome.invalid);
    expect(r.rescheduleError, RescheduleError.afterWindow);
    expect(calls, isEmpty);
  });

  test('the server refusing (e.g. the class just started) comes back as the same reason', () async {
    serverError = const RescheduleRefused(RescheduleError.noNextSession);
    final r = await board.reschedule('c1', CourseRole.owner, schedule, ok);
    expect(r.outcome, ClassroomOutcome.invalid);
    expect(r.rescheduleError, RescheduleError.noNextSession);
  });

  test('undo goes to the server too', () async {
    expect((await board.cancelReschedule('c1', CourseRole.owner)).ok, isTrue);
    expect(calls.single.$1, 'cancelNextSessionReschedule');
    expect(calls.single.$2, {'courseId': 'c1'});
  });

  test('students cannot move classes or post', () async {
    expect((await board.reschedule('c1', CourseRole.student, schedule, ok)).outcome, ClassroomOutcome.notAllowed);
    expect((await board.cancelReschedule('c1', CourseRole.student)).outcome, ClassroomOutcome.notAllowed);
    expect((await board.post('c1', CourseRole.visitor, 'x')).outcome, ClassroomOutcome.notAllowed);
    expect(calls, isEmpty);
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
