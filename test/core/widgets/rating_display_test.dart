import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/core/widgets/rating_display.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );
  }

  group('Layer 3: Core Widgets -> RatingDisplay (Coverage)', () {
    testWidgets('RatingDisplay renders compact mode correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const RatingDisplay(averageRating: 4.5, reviewCount: 10, isCompact: true),
      ));
      
      // Wait for localizations to load
      await tester.pumpAndSettle();

      // In compact mode, we do NOT show the number "4.5"
      expect(find.text('4.5'), findsNothing);
      
      // But we DO show the review count "(10)"
      expect(find.text('(10)'), findsOneWidget);

      // And we should see icons for stars (4 full, 1 half)
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_half), findsOneWidget);
    });

    testWidgets('RatingDisplay renders expanded mode correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const RatingDisplay(averageRating: 4.8, reviewCount: 150, isCompact: false),
      ));
      
      await tester.pumpAndSettle();

      // In expanded mode, we DO show the number
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('(150)'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(4)); // 4.8 rounds to 5 stars internally via RatingUtils? Or maybe 4 full, 1 half
    });

    testWidgets('RatingDisplay shows No Reviews when count is 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const RatingDisplay(averageRating: 0, reviewCount: 0),
      ));
      
      await tester.pumpAndSettle();

      // Assuming English fallback for 'noReviewsYet' is 'No reviews yet'
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('RatingDisplayDetailed renders correctly with reviews', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const RatingDisplayDetailed(averageRating: 3.5, reviewCount: 42),
      ));
      
      await tester.pumpAndSettle();

      expect(find.text('3.5'), findsWidgets);
      expect(find.text('(42)'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_half), findsOneWidget);
    });
  });
}
