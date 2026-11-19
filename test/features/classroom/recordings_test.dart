import 'package:calligro_app/features/classroom/application/classroom_assignments.dart';
import 'package:calligro_app/features/classroom/application/classroom_materials.dart';
import 'package:calligro_app/features/classroom/application/classroom_recordings.dart';
import 'package:calligro_app/features/classroom/data/firestore_recordings_repository.dart';
import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:calligro_app/features/classroom/domain/course_recordings.dart';
import 'package:calligro_app/features/classroom/presentation/classroom_scope.dart';
import 'package:calligro_app/features/classroom/presentation/pages/recordings_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_classroom.dart';

void main() {
  group('recording model', () {
    final now = DateTime(2026, 12, 20);
    test('duration in nanoseconds (LiveKit) or seconds (older)', () {
      expect(CourseRecording.fromMap('r', {'duration': 3723000000000}).durationSeconds, 3723);
      expect(CourseRecording.fromMap('r', {'duration': 95}).durationSeconds, 95);
      expect(CourseRecording.fromMap('r', {'duration': '61.4'}).durationSeconds, 61);
    });
    test('hidden when failed or older than 14 days; undated kept', () {
      expect(CourseRecording(id: 'a', recordedAt: now.subtract(const Duration(days: 2))).isAvailableAt(now), isTrue);
      expect(CourseRecording(id: 'b', recordedAt: now.subtract(const Duration(days: 15))).isAvailableAt(now), isFalse);
      expect(CourseRecording(id: 'c', status: 'failed', recordedAt: now).isAvailableAt(now), isFalse);
      expect(const CourseRecording(id: 'd').isAvailableAt(now), isTrue);
    });
    test('reads title, qualities, Timestamp date', () {
      final r = CourseRecording.fromMap('r', {
        'title': 'Alif class',
        'recordedAt': Timestamp.fromDate(now),
        'qualities': {'720p': 'u7', '1080p': 'u10'},
      });
      expect([r.title, r.recordedAt, r.qualities], ['Alif class', now, {'720p': 'u7', '1080p': 'u10'}]);
      expect(CourseRecording.fromMap('r', {'title': ''}).title, isNull);
    });
  });

  test('renaming: teacher/admin only; empty title removes it', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c1/recordings/r1').set({'title': 'Old', 'recordedAt': Timestamp.now()});
    final recordings = ClassroomRecordings(repository: FirestoreRecordingsRepository(firestore: db));
    expect((await recordings.rename('c1', CourseRole.student, 'r1', 'Hacked')).outcome, ClassroomOutcome.notAllowed);
    expect((await recordings.rename('c1', CourseRole.owner, 'r1', ' New ')).ok, isTrue);
    expect((await db.doc('courses/c1/recordings/r1').get()).data()!['title'], 'New');
    await recordings.rename('c1', CourseRole.admin, 'r1', '');
    expect((await db.doc('courses/c1/recordings/r1').get()).data()!.containsKey('title'), isFalse);
    expect((await recordings.repository.watchRecordings('c1').first).single.id, 'r1');
  });

  group('recordings screen', () {
    Future<FakeRecordingsRepository> pump(WidgetTester tester, CourseRole role) async {
      final repo = FakeRecordingsRepository()
        ..put(CourseRecording(id: 'r1', title: 'Alif class', recordedAt: DateTime.now().subtract(const Duration(days: 1))));
      final services = ClassroomServices(
        assignments: ClassroomAssignments(repository: FakeAssignmentRepository(), files: FakeSubmissionFiles(), currentUid: () => 'x'),
        materials: ClassroomMaterials(repository: FakeMaterialsRepository(), files: FakeMaterialFiles(), currentUid: () => 'x'),
        recordings: ClassroomRecordings(repository: repo),
      );
      await tester.binding.setSurfaceSize(const Size(900, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => ClassroomScope(services: services, child: child!),
        home: RecordingsPage(courseId: 'c1', role: role),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return repo;
    }

    testWidgets('students watch but get no rename button (it could only fail)', (tester) async {
      await pump(tester, CourseRole.student);
      expect(find.text('Alif class'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('opening the list asks the server once to recover missing recordings; a failure stays silent', (tester) async {
      final repo = await pump(tester, CourseRole.student);
      expect(repo.recoverCalls, ['c1']);
      expect(find.text('Alif class'), findsOneWidget);
    });

    test('recoverMissing never throws (nothing recovered this time is fine)', () async {
      final repo = FakeRecordingsRepository()..failRecover = Exception('offline');
      await ClassroomRecordings(repository: repo).recoverMissing('c1');
      expect(repo.recoverCalls, ['c1']);
    });

    testWidgets('the teacher renames', (tester) async {
      final repo = await pump(tester, CourseRole.owner);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'Alif — lesson 1');
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.renames.single, (id: 'r1', title: 'Alif — lesson 1'));
    });
  });
}
