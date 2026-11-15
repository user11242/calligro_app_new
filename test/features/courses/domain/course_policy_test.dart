import 'package:calligro_app/features/courses/domain/course_models.dart';
import 'package:calligro_app/features/courses/domain/course_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/course_fixtures.dart';

/// Rules for browsing / buying, on documents shaped like real course documents
/// (the fields add_course_dashboard.dart writes — no invented ones).
void main() {
  group('reading a real course document', () {
    test('every field the screens and rules need', () {
      final c = courseDoc('c1');
      expect(c.courseName, 'Thuluth Foundations');
      expect(c.teacherId, 't1');
      expect(c.teacherName, 'Ustadh Ali');
      expect(c.teacherPhotoUrl, 'https://img/t1.jpg', reason: 'stored as teacherProfilePic');
      expect(c.bannerUrl, 'https://img/banner.jpg', reason: 'stored as courseBanner');
      expect(c.price, 100);
      expect(c.isFree, isFalse);
      expect(c.iapProductId, 'com.yazan.calligro.tier_100');
      expect(c.level, 'Beginner');
      expect(c.calligraphyStyle, 'Thuluth');
      expect(c.ageCategory, 'Adults');
      expect(c.requiredTools.map((t) => t['name']), ['Qalam', 'Ink']);
      expect(c.curriculumSteps, hasLength(2));
      expect(c.selectedDays, ['Monday']);
      expect(c.startDate, isNotNull);
      expect(c.startTime, isNotNull, reason: 'startTime, falling back to selectedTime');
      expect(c.maxStudents, 3);
      expect(c.raw['courseBanner'], 'https://img/banner.jpg', reason: 'raw kept for the course pages');
    });

    test('missing / odd values never crash', () {
      final c = Course.fromMap('x', {'price': '50', 'enrolledStudents': 'oops', 'maxStudents': null});
      expect(c.price, 50);
      expect(c.enrolledStudents, isEmpty);
      expect(c.maxStudents, 0);
      expect(c.isFree, isFalse);
      expect(Course.fromMap('f', const {}).isFree, isTrue);
    });
  });

  group('which store product to buy (must equal functions/purchases.js expectedProductId)', () {
    test('the course\'s own product id', () {
      expect(CoursePolicy.productIdFor(courseDoc('c1')), 'com.yazan.calligro.tier_100');
    });
    test('otherwise the tier for the price, rounded DOWN like the server', () {
      expect(CoursePolicy.productIdFor(courseDoc('c1', iapProductId: null, price: 65)), 'com.yazan.calligro.tier_65');
      expect(CoursePolicy.productIdFor(courseDoc('c1', iapProductId: null, price: 49.9)), 'com.yazan.calligro.tier_49');
    });
  });

  group('full (same count as the server)', () {
    test('uses the larger of enrolledCount and the real list', () {
      expect(CoursePolicy.isFull(courseDoc('c1', enrolled: ['a', 'b', 'c'], enrolledCount: 1)), isTrue,
          reason: 'counter drifted low; the list says full');
      expect(CoursePolicy.isFull(courseDoc('c1', enrolled: ['a'], enrolledCount: 3)), isTrue);
      expect(CoursePolicy.isFull(courseDoc('c1', enrolled: ['a'], enrolledCount: 1)), isFalse);
    });
    test('no limit → never full; a student already inside is never blocked', () {
      expect(CoursePolicy.isFull(courseDoc('c1', maxStudents: 0, enrolled: List.filled(50, 'x'))), isFalse);
      expect(CoursePolicy.isFullFor(courseDoc('c1', enrolled: ['a', 'b', 'c']), 'a'), isFalse);
    });
  });

  group('the main button', () {
    final c = courseDoc('c1', enrolled: ['s1']);
    test('owner → manage, enrolled → open, full → sold out, otherwise buy / free', () {
      expect(CoursePolicy.action(c, 't1'), CourseAction.manage);
      expect(CoursePolicy.action(c, 's1'), CourseAction.open);
      expect(CoursePolicy.action(courseDoc('c1', enrolled: ['a', 'b', 'c']), 's9'), CourseAction.soldOut);
      expect(CoursePolicy.action(c, 's9'), CourseAction.buy);
      expect(CoursePolicy.action(courseDoc('c2', price: 0), 's9'), CourseAction.enrollFree);
    });
    test('guests see buy / free (tapping asks them to sign in)', () {
      expect(CoursePolicy.action(c, ''), CourseAction.buy);
      expect(CoursePolicy.action(courseDoc('c2', price: 0), ''), CourseAction.enrollFree);
    });
  });

  group('catalogue visibility (as before the refactor)', () {
    final c = courseDoc('c1', enrolled: ['s1']); // starts 2026-12-01
    test('a course that has started is hidden from people not in it', () {
      expect(CoursePolicy.isVisibleInCatalog(c, 's9', now: DateTime(2026, 11, 30)), isTrue);
      expect(CoursePolicy.isVisibleInCatalog(c, 's9', now: DateTime(2026, 12, 2)), isFalse);
      expect(CoursePolicy.isVisibleInCatalog(c, '', now: DateTime(2026, 12, 2)), isFalse);
    });
    test('…but stays visible to its students', () {
      expect(CoursePolicy.isVisibleInCatalog(c, 's1', now: DateTime(2027, 1, 5)), isTrue);
    });
    test('no start date → visible', () {
      expect(CoursePolicy.isVisibleInCatalog(Course.fromMap('x', const {'price': 10}), 's9', now: DateTime(2030)), isTrue);
    });
    test('the stored Ruq\'ah spelling matches its chip', () {
      expect(CoursePolicy.matches(courseDoc('r', style: "Ruq'ah"), CourseFilter.ruqah, ''), isTrue);
    });
  });

  group('catalogue filters (by stored value, never by translated label)', () {
    final thuluth = courseDoc('a', style: 'Thuluth', level: 'Beginner');
    final naskh = courseDoc('b', style: 'Naskh', level: 'Advanced', enrolled: ['s1']);
    test('style, level, my courses', () {
      expect(CoursePolicy.matches(thuluth, CourseFilter.thuluth, 's1'), isTrue);
      expect(CoursePolicy.matches(naskh, CourseFilter.thuluth, 's1'), isFalse);
      expect(CoursePolicy.matches(naskh, CourseFilter.advanced, 's1'), isTrue);
      expect(CoursePolicy.matches(thuluth, CourseFilter.advanced, 's1'), isFalse);
      expect(CoursePolicy.matches(naskh, CourseFilter.myCourses, 's1'), isTrue);
      expect(CoursePolicy.matches(thuluth, CourseFilter.myCourses, 's1'), isFalse);
      expect(CoursePolicy.matches(thuluth, CourseFilter.myCourses, ''), isFalse);
      expect(CoursePolicy.matches(thuluth, CourseFilter.all, ''), isTrue);
    });
    test('search: any of name, teacher, style; case- and Arabic-letter-insensitive', () {
      final ar = courseDoc('x', name: 'خط الثلث للمبتدئين', teacher: 'أحمد');
      expect(CoursePolicy.matchesSearch(thuluth, 'ustadh'), isTrue);
      expect(CoursePolicy.matchesSearch(thuluth, 'THULUTH'), isTrue);
      expect(CoursePolicy.matchesSearch(thuluth, 'kufi'), isFalse);
      expect(CoursePolicy.matchesSearch(ar, 'احمد'), isTrue, reason: 'أ and ا match');
      expect(CoursePolicy.matchesSearch(thuluth, '  '), isTrue);
      expect(CoursePolicy.matchesSearch(thuluth, 'beginners', extraText: 'Thuluth for Beginners'), isTrue,
          reason: 'the translated display title is searchable too');
    });
  });
}
