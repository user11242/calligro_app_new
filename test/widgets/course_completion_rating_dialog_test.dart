import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/rating/widgets/course_completion_rating_dialog.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('Layer 3: Dialogs -> CourseCompletionRatingDialog (Coverage)', () {
    testWidgets('CourseCompletionRatingDialog renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const CourseCompletionRatingDialog(
          courseId: 'course_123',
          courseName: 'Thuluth Mastery',
          teacherId: 'teacher_123',
        ),
      ));
      
      // Dialog has an animation or translation future, so we pumpAndSettle
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      
      // Should find 5 stars (Icons.star_border or Icons.star depending on state)
      // The widget uses a Row of 5 gesture detectors for stars. We can just check for star icons
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      
      // Should find a text field for the review
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('CourseCompletionRatingDialog updates stars when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const CourseCompletionRatingDialog(
          courseId: 'course_123',
          courseName: 'Thuluth Mastery',
          teacherId: 'teacher_123',
        ),
      ));
      
      await tester.pumpAndSettle();

      // Tap the 3rd star (index 2)
      final stars = find.byIcon(Icons.star_border);
      await tester.tap(stars.at(2));
      await tester.pumpAndSettle();

      // Now there should be 3 filled stars and 2 border stars
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });
  });
}
