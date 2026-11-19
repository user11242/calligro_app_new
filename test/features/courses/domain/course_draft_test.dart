import 'package:calligro_app/features/courses/domain/course_draft.dart';
import 'package:calligro_app/features/courses/domain/course_models.dart';
import 'package:calligro_app/features/courses/domain/course_policy.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

CourseDraft draft({
  String name = 'Thuluth Foundations',
  String? writingType = 'Arabic Calligraphy',
  String? style = 'Thuluth',
  double price = 100,
  int maxStudents = 12,
  DateTime? start,
  DateTime? end,
  List<String> days = const ['Monday'],
  List<String> curriculum = const ['Alif', 'Ba'],
}) =>
    CourseDraft(
      courseName: name,
      courseDescription: 'Learn',
      writingType: writingType,
      calligraphyStyle: style,
      level: 'Beginner',
      ageCategory: 'Adults',
      startDate: start ?? DateTime(2026, 12, 1),
      endDate: end ?? DateTime(2027, 1, 30),
      startTime: DateTime(2026, 12, 1, 18),
      endTime: DateTime(2026, 12, 1, 19),
      selectedDays: days,
      requiredTools: const [
        {'name': 'Qalam', 'icon': 'edit'},
      ],
      curriculumSteps: curriculum,
      price: price,
      maxStudents: maxStudents,
    );

const author = CourseAuthor(id: 't1', name: 'Ustadh Ali', photoUrl: 'https://img/t1.jpg', hasPayoutInfo: true, commissionRate: 0.7);

void main() {
  group('validation', () {
    test('a complete draft has no problems', () => expect(draft().problems, isEmpty));

    test('missing or reversed dates', () {
      expect(CourseDraft(courseName: 'x', price: 100, maxStudents: 3, selectedDays: const ['Monday']).problems,
          contains(DraftProblem.missingDates));
      expect(draft(start: DateTime(2027, 2, 1), end: DateTime(2027, 1, 1)).problems, contains(DraftProblem.endBeforeStart));
    });

    test('no days, bad seat limit, negative / fractional price', () {
      expect(draft(days: const []).problems, contains(DraftProblem.noDays));
      expect(draft(maxStudents: 0).problems, contains(DraftProblem.badMaxStudents));
      expect(draft(price: -5).problems, contains(DraftProblem.badPrice));
      expect(draft(price: 99.5).problems, contains(DraftProblem.badPrice), reason: 'store products are whole tiers');
      expect(draft(price: double.nan).problems, contains(DraftProblem.badPrice));
    });

    test('no writing type', () => expect(draft(writingType: null).problems, contains(DraftProblem.missingWritingType)));
  });

  group('maxStudents from the text field', () {
    test('a positive number is used; anything else falls back to 30 (as before)', () {
      expect(CourseDraft.parseMaxStudents('12'), 12);
      expect(CourseDraft.parseMaxStudents('١٢'), 12, reason: 'Arabic digits');
      expect(CourseDraft.parseMaxStudents(''), 30);
      expect(CourseDraft.parseMaxStudents('0'), 30);
      expect(CourseDraft.parseMaxStudents('abc'), 30);
    });
  });

  group('banner', () {
    test('by writing type and style, as before', () {
      expect(CourseDraft.bannerFor('Normal Pen Writing', null), 'assets/courses_backgrounds/normal_writing.jpg');
      expect(CourseDraft.bannerFor('Arabic Calligraphy', 'Diwani'), 'assets/courses_backgrounds/diwani.jpg');
      expect(CourseDraft.bannerFor('Arabic Calligraphy', "Persian (Ta'liq)"), 'assets/courses_backgrounds/taliq.png');
      expect(CourseDraft.bannerFor('Arabic Calligraphy', 'Unknown'), 'assets/courses_backgrounds/thuluth.jpg');
      expect(CourseDraft.bannerFor(null, null), 'assets/courses_backgrounds/thuluth.jpg');
    });
  });

  group('the document written', () {
    final created = Object();

    test('round-trips through Course.fromMap (what every screen reads)', () {
      final doc = draft().toDocument(author, createdAt: created);
      final c = Course.fromMap('new', doc);
      expect(c.courseName, 'Thuluth Foundations');
      expect(c.teacherId, 't1');
      expect(c.teacherName, 'Ustadh Ali');
      expect(c.teacherPhotoUrl, 'https://img/t1.jpg');
      expect(c.level, 'Beginner');
      expect(c.calligraphyStyle, 'Thuluth');
      expect(c.maxStudents, 12);
      expect(c.selectedDays, ['Monday']);
      expect(c.curriculumSteps, ['Alif', 'Ba']);
      expect(c.requiredTools.single['name'], 'Qalam');
      expect(c.enrolledStudents, isEmpty);
      expect(c.enrolledCount, 0);
      expect(c.bannerUrl, 'assets/courses_backgrounds/thuluth.jpg');
      expect(doc['createdAt'], same(created), reason: 'server time, not the phone clock');
    });

    test('product id is exactly what the app buys and the server expects', () {
      final c = Course.fromMap('new', draft(price: 120).toDocument(author, createdAt: created));
      expect(c.iapProductId, 'com.yazan.calligro.tier_120');
      expect(CoursePolicy.productIdFor(c), 'com.yazan.calligro.tier_120');
    });

    test('a new course saves the teacher\'s time zone, and it matches the one read back from its start date', () {
      final d = draft();
      final doc = d.toDocument(author, createdAt: created);
      expect(doc['scheduleUtcOffsetMinutes'], d.startDate!.timeZoneOffset.inMinutes);
      expect(CourseSchedule.offsetFromStartDate(d.startDate!.toUtc())?.inMinutes, d.startDate!.timeZoneOffset.inMinutes,
          reason: 'the picker gives local midnight, so both ways agree');
    });

    test('free courses store no product (was tier_0 / tier_50)', () {
      final doc = draft(price: 0).toDocument(author, createdAt: created);
      expect(doc.containsKey('iapProductId'), isFalse);
      expect(Course.fromMap('f', doc).isFree, isTrue);
    });

    test('an empty name is generated later from type/style/level', () {
      final doc = draft(name: '  ').toDocument(author, createdAt: created, generatedName: 'Thuluth - Beginner');
      expect(doc['courseName'], 'Thuluth - Beginner');
      expect(doc['isAutoGeneratedName'], isTrue);
    });

    test('the classroom marker is public (the Join buttons check it); there is no password', () {
      final doc = draft().toDocument(author, createdAt: created, meetLink: CourseDraft.calligroClassroomLink);
      expect(doc['calligroMeetLink'], 'calligro-meet');
      expect(doc.containsKey('classroomPassword'), isFalse);
    });
  });

  group('curriculum as stored by older courses', () {
    test('plain strings (what the app writes) and {title} maps both read as titles', () {
      expect(Course.fromMap('a', {'curriculumSteps': ['Alif', 'Ba']}).curriculumSteps, ['Alif', 'Ba']);
      expect(
          Course.fromMap('b', {
            'curriculumSteps': [
              {'title': 'Week 1'},
              'Week 2',
            ]
          }).curriculumSteps,
          ['Week 1', 'Week 2']);
    });
  });
}
