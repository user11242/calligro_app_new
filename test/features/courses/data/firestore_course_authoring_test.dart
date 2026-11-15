import 'package:calligro_app/features/courses/data/firestore_course_authoring.dart';
import 'package:calligro_app/features/courses/data/firestore_course_repository.dart';
import 'package:calligro_app/features/courses/domain/course_draft.dart';
import 'package:calligro_app/features/courses/domain/course_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/course_fixtures.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreCourseAuthoring authoring;

  final draft = CourseDraft(
    courseName: 'Diwani Basics',
    writingType: 'Arabic Calligraphy',
    calligraphyStyle: 'Diwani',
    startDate: DateTime(2026, 12, 1),
    endDate: DateTime(2027, 1, 1),
    selectedDays: const ['Monday'],
    curriculumSteps: const ['Alif'],
    price: 80,
    maxStudents: 10,
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    authoring = FirestoreCourseAuthoring(firestore: db);
    await db.doc('users/t1').set({'name': 'Ustadh Ali', 'photoUrl': 'p.jpg', 'role': 'teacher', 'commissionRate': 0.7});
    await db.doc('users/t2').set({'name': 'New Teacher', 'role': 'teacher'});
    await db.doc('users/t1/private/payout').set({'method': 'cliq'});
  });

  group('author', () {
    test('name, photo, payout details and share', () async {
      final a = (await authoring.author('t1'))!;
      expect([a.name, a.photoUrl, a.hasPayoutInfo, a.commissionRate, a.earningPercentage], ['Ustadh Ali', 'p.jpg', true, 0.7, 70]);
    });
    test('no payout details / share yet', () async {
      final a = (await authoring.author('t2'))!;
      expect([a.hasPayoutInfo, a.hasCommissionRate], [false, false]);
    });
    test('unknown or signed-out user', () async {
      expect(await authoring.author('nobody'), isNull);
      expect(await authoring.author(''), isNull);
    });
  });

  group('create', () {
    test('the course AND its private meeting settings, together', () async {
      final a = (await authoring.author('t1'))!;
      final id = await authoring.create(draft, a, meetLink: 'calligro://room/x', classroomPassword: 'secret');

      final course = Course.fromMap(id, (await db.doc('courses/$id').get()).data()!);
      expect(course.courseName, 'Diwani Basics');
      expect(course.teacherId, 't1');
      expect(course.iapProductId, 'com.yazan.calligro.tier_80');
      expect(course.bannerUrl, 'assets/courses_backgrounds/diwani.jpg');
      expect((await db.doc('courses/$id').get()).data()!['createdAt'], isA<Timestamp>(), reason: 'server time');
      expect((await db.doc('courses/$id').get()).data()!.containsKey('classroomPassword'), isFalse);

      final meeting = (await db.doc('courses/$id/private/meetingConfig').get()).data()!;
      expect(meeting['classroomPassword'], 'secret');
      expect(meeting['calligroMeetLink'], 'calligro://room/x');
    });

    test('the new course appears in the teacher\'s own list, live', () async {
      final repo = FirestoreCourseRepository(firestore: db);
      await db.doc('courses/other').set(realCourseData(teacherId: 'someoneElse'));
      final a = (await authoring.author('t1'))!;
      final id = await authoring.create(draft, a);
      expect((await repo.watchTeaching('t1').first).map((c) => c.id), [id]);
      expect(await repo.watchTeaching('').first, isEmpty);
    });
  });
}
