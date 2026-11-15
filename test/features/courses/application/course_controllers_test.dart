import 'package:calligro_app/features/courses/application/course_controllers.dart';
import 'package:calligro_app/features/courses/domain/course_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/course_fixtures.dart';
import '../fakes/fake_courses.dart';

void main() {
  late FakeCourseRepository repo;

  setUp(() {
    repo = FakeCourseRepository()
      ..put(courseDoc('thuluth', name: 'Thuluth Foundations', style: 'Thuluth', level: 'Beginner'))
      ..put(courseDoc('naskh', name: 'Naskh Advanced', style: 'Naskh', level: 'Advanced', enrolled: ['s1']))
      ..teachers['t1'] = const CourseTeacherSummary(id: 't1', name: 'Ustadh Ali', averageRating: 4.5);
  });

  group('CoursePreviewController', () {
    test('live course, teacher read once, action from the policy', () async {
      final c = CoursePreviewController(repository: repo, courseId: 'thuluth', uid: 's9')..start();
      await pumpEventQueue();
      expect(c.course!.courseName, 'Thuluth Foundations');
      expect(c.teacher!.averageRating, 4.5);
      expect(c.action, CourseAction.buy);

      repo.put(courseDoc('thuluth', enrolled: ['s9']));
      await pumpEventQueue();
      expect(c.action, CourseAction.open, reason: 'enrolment arrives live after the purchase');
      expect(repo.summaryReads, ['t1'], reason: 'teacher read once, not on every change');
      c.dispose();
    });

    test('shows the passed-in course immediately, then the live one', () async {
      final c = CoursePreviewController(repository: repo, courseId: 'thuluth', uid: 's9', initial: courseDoc('thuluth', name: 'Cached'));
      expect(c.isLoading, isFalse);
      expect(c.course!.courseName, 'Cached');
      c.start();
      await pumpEventQueue();
      expect(c.course!.courseName, 'Thuluth Foundations');
    });

    test('unknown course → not found', () async {
      final c = CoursePreviewController(repository: repo, courseId: 'nope', uid: 's9')..start();
      await pumpEventQueue();
      expect(c.notFound, isTrue);
    });
  });

  group('CourseCatalogController', () {
    CourseCatalogController make({String uid = 's1', DateTime? now}) =>
        CourseCatalogController(repository: repo, uid: uid, now: () => now ?? DateTime(2026, 11, 15))..start();

    test('all courses, live', () async {
      final c = make();
      await pumpEventQueue();
      expect(c.visible().map((x) => x.id).toSet(), {'thuluth', 'naskh'});
      repo.put(courseDoc('kufi', style: 'Kufi'));
      await pumpEventQueue();
      expect(c.visible(), hasLength(3));
    });

    test('chips and search', () async {
      final c = make();
      await pumpEventQueue();
      c.filter = CourseFilter.thuluth;
      expect(c.visible().single.id, 'thuluth');
      c.filter = CourseFilter.myCourses;
      expect(c.visible().single.id, 'naskh');
      c.filter = CourseFilter.all;
      c.query = 'naskh';
      expect(c.visible().single.id, 'naskh');
      c.query = 'مبتدئ';
      expect(c.visible(displayTitle: (x) => x.id == 'thuluth' ? 'خط الثلث للمبتدئين' : '').single.id, 'thuluth');
    });

    test('started courses disappear for non-students, stay for students', () async {
      final c = make(uid: 's1', now: DateTime(2026, 12, 5));
      await pumpEventQueue();
      expect(c.visible().map((x) => x.id), ['naskh']);
    });
  });

  group('CourseListController (my courses)', () {
    test('live enrolled courses; errors end loading', () async {
      final c = CourseListController(repo.watchEnrolled('s1'))..start();
      await pumpEventQueue();
      expect(c.all.single.id, 'naskh');
      repo.put(courseDoc('thuluth', enrolled: ['s1']));
      await pumpEventQueue();
      expect(c.all, hasLength(2));
      final broken = CourseListController(Stream.error(Exception('x')))..start();
      await pumpEventQueue();
      expect(broken.isLoading, isFalse);
      expect(broken.hasError, isTrue);
    });
  });
}
