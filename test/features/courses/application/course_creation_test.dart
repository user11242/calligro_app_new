import 'dart:async';

import 'package:calligro_app/features/courses/application/course_creation.dart';
import 'package:calligro_app/features/courses/domain/course_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_courses.dart';

final good = CourseDraft(
  writingType: 'Arabic Calligraphy',
  calligraphyStyle: 'Naskh',
  startDate: DateTime(2026, 12, 1),
  endDate: DateTime(2027, 1, 1),
  selectedDays: const ['Monday'],
  price: 60,
);

void main() {
  late FakeAuthoring authoring;
  late CourseCreation creation;
  var uid = 't1';

  setUp(() {
    uid = 't1';
    authoring = FakeAuthoring()
      ..authors['t1'] = const CourseAuthor(id: 't1', name: 'Ali', hasPayoutInfo: true, commissionRate: 0.7);
    creation = CourseCreation(authoring: authoring, currentUid: () => uid);
  });

  test('a ready teacher with a complete draft → one course, with its meeting settings', () async {
    final r = await creation.create(good, generatedName: 'Naskh - Beginner', meetLink: 'room', classroomPassword: 'pw');
    expect(r.outcome, CreateCourseOutcome.created);
    expect(r.courseId, 'new1');
    final saved = authoring.created.single;
    expect([saved.author.id, saved.generatedName, saved.meetLink, saved.password], ['t1', 'Naskh - Beginner', 'room', 'pw']);
  });

  test('signed out → nothing written', () async {
    uid = '';
    expect((await creation.create(good)).outcome, CreateCourseOutcome.notSignedIn);
    expect(authoring.created, isEmpty);
  });

  test('incomplete draft → its problems, nothing written, teacher not even read', () async {
    final r = await creation.create(const CourseDraft(price: 60));
    expect(r.outcome, CreateCourseOutcome.invalid);
    expect(r.problems, containsAll([DraftProblem.missingDates, DraftProblem.noDays]));
    expect(authoring.created, isEmpty);
    expect(authoring.authorReads, isEmpty);
  });

  test('no payout details → asked to add them; saving them then works without reopening', () async {
    authoring.authors['t1'] = const CourseAuthor(id: 't1', commissionRate: 0.7);
    expect((await creation.create(good)).outcome, CreateCourseOutcome.needsPayout);
    expect(authoring.created, isEmpty);

    authoring.authors['t1'] = const CourseAuthor(id: 't1', hasPayoutInfo: true, commissionRate: 0.7);
    expect((await creation.create(good)).outcome, CreateCourseOutcome.created, reason: 'teacher re-read each time');
  });

  test('no share set by an admin → refused', () async {
    authoring.authors['t1'] = const CourseAuthor(id: 't1', hasPayoutInfo: true);
    expect((await creation.create(good)).outcome, CreateCourseOutcome.needsCommission);
    expect(authoring.created, isEmpty);
  });

  test('double tap while saving → one course', () async {
    authoring.holdCreate = Completer<void>();
    final first = creation.create(good);
    await Future<void>.delayed(Duration.zero);
    expect((await creation.create(good)).outcome, CreateCourseOutcome.busy);
    authoring.holdCreate!.complete();
    expect((await first).outcome, CreateCourseOutcome.created);
    expect(authoring.created, hasLength(1));
  });

  test('a failed write is reported and the teacher can try again', () async {
    authoring.failCreate = Exception('offline');
    final r = await creation.create(good);
    expect(r.outcome, CreateCourseOutcome.failed);
    expect(r.message, contains('offline'));
    authoring.failCreate = null;
    expect((await creation.create(good)).outcome, CreateCourseOutcome.created);
  });

  test('loadAuthor for the price step', () async {
    expect((await creation.loadAuthor())!.earningPercentage, 70);
    uid = '';
    expect(await creation.loadAuthor(), isNull);
  });
}
