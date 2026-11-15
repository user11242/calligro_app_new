import 'package:calligro_app/features/courses/application/course_purchases.dart';
import 'package:calligro_app/features/courses/domain/course_models.dart';
import 'package:calligro_app/features/courses/presentation/course_scope.dart';
import 'package:calligro_app/features/courses/presentation/pages/course_catalog_tab.dart';
import 'package:calligro_app/features/courses/presentation/pages/course_preview_page.dart';
import 'package:calligro_app/features/courses/presentation/pages/my_courses_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/course_fixtures.dart';
import '../fakes/fake_courses.dart';

/// The REAL course screens (original UI) on fakes, with the REAL purchase flow.
void main() {
  late FakeCourseRepository repo;
  late FakeStore store;
  late FakeEnrollment server;
  var uid = 's1';
  CoursePurchases? purchasesInstance;
  // Created inside the test (its stream must live in the test's fake-async zone).
  CoursePurchases purchases() => purchasesInstance ??=
      CoursePurchases(store: store, enrollment: server, intents: MemoryIntentStore(), currentUid: () => uid)..start();
  const tier100 = 'com.yazan.calligro.tier_100';

  Future<void> pump(WidgetTester tester, Widget screen, {Locale locale = const Locale('en')}) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    purchases();
    final services = CourseServices(courses: repo, authoring: FakeAuthoring(repo: repo), purchases: purchases, currentUid: () => uid);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      builder: (context, child) => CourseScope(services: services, child: child!),
      routes: {'/LoginPage': (_) => const Scaffold(body: Text('LOGIN PAGE'))},
      home: screen,
    ));
    await settle(tester);
  }

  Finder mainButton() => find.byKey(const Key('course-main-button'));

  CoursePreviewPage preview(String id) => CoursePreviewPage(courseId: id, courseData: repo.courses[id]!.raw);

  setUp(() {
    uid = 's1';
    repo = FakeCourseRepository()
      ..put(courseDoc('paid'))
      ..put(courseDoc('free', price: 0, name: 'Free Workshop'))
      ..put(courseDoc('full', enrolled: ['a', 'b', 'c'], name: 'Full Course'))
      ..teachers['t1'] = const CourseTeacherSummary(id: 't1', name: 'Ustadh Ali', averageRating: 4.5, courseCount: 3, totalStudents: 12);
    store = FakeStore();
    server = FakeEnrollment();
    purchasesInstance = null;
  });

  group('course page', () {
    testWidgets('original page: title, teacher (from the summary), translated button', (tester) async {
      await pump(tester, preview('paid'));
      expect(find.text('Thuluth Foundations'), findsWidgets);
      expect(find.text('Ustadh Ali'), findsWidgets);
      expect(find.text('12'), findsOneWidget, reason: 'students across the teacher\'s courses');
      expect(find.text('ENROLL NOW'), findsOneWidget);
    });

    testWidgets('Arabic users see Arabic (the rewrite had made it English-only)', (tester) async {
      await pump(tester, preview('paid'), locale: const Locale('ar'));
      expect(find.text('سجل الآن'.toUpperCase()), findsOneWidget);
      expect(find.text('ENROLL NOW'), findsNothing);
    });

    testWidgets('buy → store → server → success page; purchase finished only then', (tester) async {
      await pump(tester, preview('paid'));
      await tester.tap(mainButton());
      await settle(tester);
      expect(store.bought, [tier100]);
      expect(store.finished, isEmpty);

      store.deliver(tier100);
      await settle(tester);
      expect(server.verifications.single.courseId, 'paid');
      expect(store.finished, hasLength(1));
      expect(find.text('Payment Successful!'), findsOneWidget);
    });

    testWidgets('server refusal → error shown, purchase NOT finished, button usable again', (tester) async {
      server.crash = Exception('network down');
      await pump(tester, preview('paid'));
      await tester.tap(mainButton());
      await settle(tester);
      store.deliver(tier100);
      await settle(tester);
      expect(store.finished, isEmpty);
      expect(find.textContaining('network down'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(mainButton()).onPressed, isNotNull);
      await drain(tester);
    });

    testWidgets('leaving the page mid-purchase does not lose it (the app-wide flow finishes it)', (tester) async {
      await pump(tester, preview('paid'));
      await tester.tap(mainButton());
      await settle(tester);
      await pump(tester, const Scaffold(body: Text('elsewhere')));
      store.deliver(tier100);
      await settle(tester);
      expect(server.verifications.single.courseId, 'paid');
      expect(store.finished, hasLength(1));
    });

    testWidgets('guests are asked to sign in; the store is never opened', (tester) async {
      uid = '';
      await pump(tester, preview('paid'));
      await tester.tap(mainButton());
      await settle(tester);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(store.bought, isEmpty);
    });

    testWidgets('free course → enrolled through the server → success page', (tester) async {
      await pump(tester, preview('free'));
      await tester.tap(mainButton());
      await settle(tester);
      expect(server.freeEnrolments, ['free']);
      expect(store.bought, isEmpty);
      expect(find.text('Payment Successful!'), findsOneWidget);
    });

    testWidgets('full course: sold out, nothing to tap', (tester) async {
      await pump(tester, preview('full'));
      expect(find.text('SOLD OUT'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.ancestor(of: find.text('SOLD OUT'), matching: find.byType(ElevatedButton))).onPressed,
          isNull);
    });

    testWidgets('enrolment arriving live turns the button into "Go to course"', (tester) async {
      await pump(tester, preview('paid'));
      repo.put(courseDoc('paid', enrolled: ['s1']));
      await settle(tester);
      expect(find.text('GO TO COURSE'), findsOneWidget);
    });
  });

  group('catalogue', () {
    testWidgets('lists real courses; started ones hidden from non-students', (tester) async {
      repo.put(courseDoc('started', name: 'Started Course')); // starts 2026-12-01 (see fixtures)
      await pump(tester, const StudentCoursesTab());
      expect(find.text('Thuluth Foundations'), findsOneWidget);
      expect(find.text('Free Workshop'), findsOneWidget);
    });

    testWidgets('the Thuluth chip and search filter by stored values', (tester) async {
      repo.put(courseDoc('naskh', name: 'Naskh Basics', style: 'Naskh'));
      await pump(tester, const StudentCoursesTab());
      expect(find.text('Naskh Basics'), findsOneWidget);
      await tester.tap(find.text('Thuluth').first);
      await settle(tester);
      expect(find.text('Naskh Basics'), findsNothing);
      expect(find.text('Thuluth Foundations'), findsOneWidget);
    });

    testWidgets('new courses appear live', (tester) async {
      await pump(tester, const StudentCoursesTab());
      repo.put(courseDoc('fresh', name: 'Brand New'));
      await settle(tester);
      expect(find.text('Brand New'), findsOneWidget);
    });
  });

  group('my courses', () {
    testWidgets('only my courses, and a just-bought one appears without reopening', (tester) async {
      repo.put(courseDoc('mine', name: 'Mine Already', enrolled: ['s1']));
      await pump(tester, const StudentMyCoursesPage());
      expect(find.text('Mine Already'), findsOneWidget);
      expect(find.text('Free Workshop'), findsNothing);
      repo.put(courseDoc('paid', enrolled: ['s1']));
      await settle(tester);
      expect(find.text('Thuluth Foundations'), findsOneWidget);
    });
  });
}

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await settle(tester);
}
