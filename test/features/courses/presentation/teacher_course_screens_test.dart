import 'package:calligro_app/features/courses/application/course_purchases.dart';
import 'package:calligro_app/features/courses/domain/course_draft.dart';
import 'package:calligro_app/features/courses/presentation/course_scope.dart';
import 'package:calligro_app/features/teacher/tabs/teacher_courses_tab.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/course_fixtures.dart';
import '../fakes/fake_courses.dart';

/// The teacher's real "My courses" tab on the course repository.
void main() {
  late FakeCourseRepository repo;
  late FakeAuthoring authoring;

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final services = CourseServices(
      courses: repo,
      authoring: authoring,
      purchases: () => throw StateError('teachers never buy here') as CoursePurchases,
      currentUid: () => 't1',
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: CourseScope(
        services: services,
        child: TeacherCoursesTab(auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 't1'))),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(() {
    repo = FakeCourseRepository()
      ..put(courseDoc('mine', name: 'My Thuluth Class'))
      ..put(courseDoc('theirs', name: 'Someone Else Class', teacherId: 't2'));
    authoring = FakeAuthoring(repo: repo)
      ..authors['t1'] = const CourseAuthor(id: 't1', name: 'Ustadh Ali', hasPayoutInfo: true, commissionRate: 0.7);
  });

  testWidgets('only the teacher\'s own courses', (tester) async {
    await pump(tester);
    expect(find.text('My Thuluth Class'), findsOneWidget);
    expect(find.text('Someone Else Class'), findsNothing);
  });

  testWidgets('a course just created appears without reopening the tab', (tester) async {
    await pump(tester);
    final services = CourseScope.of(tester.element(find.byType(TeacherCoursesTab)));
    final result = await services.creation.create(CourseDraft(
      courseName: 'Brand New Diwani',
      writingType: 'Arabic Calligraphy',
      calligraphyStyle: 'Diwani',
      startDate: DateTime(2026, 12, 1),
      endDate: DateTime(2027, 1, 1),
      selectedDays: const ['Monday'],
      price: 60,
    ));
    expect(result.courseId, isNotNull);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Brand New Diwani'), findsOneWidget);
  });
}
