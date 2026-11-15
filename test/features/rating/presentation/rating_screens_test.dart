import 'package:calligro_app/features/rating/application/course_ratings.dart';
import 'package:calligro_app/features/rating/domain/rating_models.dart';
import 'package:calligro_app/features/rating/presentation/course_completion_rating_dialog.dart';
import 'package:calligro_app/features/rating/presentation/rating_scope.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_ratings.dart';

/// The real rating pop-up with the real CourseRatings, on a fake repository.
void main() {
  late FakeRatingRepository repo;
  late CourseRatings ratings;
  final course = RateableCourse(courseId: 'c1', teacherId: 't1', enrolledStudents: const ['s1'], endDate: DateTime(2026, 1, 1));

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// A host page that asks CourseRatings for a course and shows the pop-up,
  /// like the student home page does.
  Future<void> openHost(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => RatingScope(ratings: ratings, child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final c = await RatingScope.of(context).courseToRate();
                if (c != null && context.mounted) {
                  await showCourseCompletionRatingDialog(context: context, course: c, courseName: 'Thuluth');
                }
              },
              child: const Text('OPEN HOME'),
            ),
          ),
        ),
      ),
    ));
  }

  void init() {
    repo = FakeRatingRepository()..courses.add(course);
    ratings = CourseRatings(repository: repo, currentUid: () => 's1');
  }

  testWidgets('pick stars, submit → one review, the pop-up closes, thank-you shown', (tester) async {
    init();
    await openHost(tester);
    await tester.tap(find.text('OPEN HOME'));
    await settle(tester);
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Beautiful course');
    await tester.tap(find.text('Submit Rating'));
    await settle(tester);
    expect(repo.reviews['c1_s1']!.rating, 4);
    expect(repo.reviews['c1_s1']!.reviewText, 'Beautiful course');
    expect(find.byType(CourseCompletionRatingDialog), findsNothing);
    expect(find.text('Thank you for your feedback!'), findsOneWidget);
  });

  testWidgets('the pop-up does NOT come back after "Skip" (THE BUG)', (tester) async {
    init();
    await openHost(tester);
    await tester.tap(find.text('OPEN HOME'));
    await settle(tester);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(find.byType(CourseCompletionRatingDialog), findsNothing);

    // The student opens the home page again (and again).
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('OPEN HOME'));
      await settle(tester);
      expect(find.byType(CourseCompletionRatingDialog), findsNothing);
    }
    expect(repo.shown, ['c1']);
  });

  testWidgets('submitting without stars asks for a rating; nothing saved', (tester) async {
    init();
    await openHost(tester);
    await tester.tap(find.text('OPEN HOME'));
    await settle(tester);
    await tester.tap(find.text('Submit Rating'));
    await settle(tester);
    expect(find.text('Please select a rating'), findsOneWidget);
    expect(repo.reviews, isEmpty);
  });

  testWidgets('already rated on another device: submit closes as rated, still ONE review', (tester) async {
    init();
    await openHost(tester);
    await tester.tap(find.text('OPEN HOME'));
    await settle(tester);
    repo.reviews['c1_s1'] = const Review(id: 'c1_s1', studentId: 's1', teacherId: 't1', courseId: 'c1', rating: 5);
    await tester.tap(find.byIcon(Icons.star_border).at(0));
    await tester.pump();
    await tester.tap(find.text('Submit Rating'));
    await settle(tester);
    expect(find.byType(CourseCompletionRatingDialog), findsNothing);
    expect(repo.reviews.length, 1);
    expect(repo.reviews['c1_s1']!.rating, 5);
  });
}
