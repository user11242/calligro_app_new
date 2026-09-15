import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/auth/pages/terms_and_conditions_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: child,
    );
  }

  group('Layer 3: Standalone Screens -> TermsAndConditionsPage (Coverage)', () {
    testWidgets('TermsAndConditionsPage renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const TermsAndConditionsPage(),
      ));
      
      // Should find the AppBar
      expect(find.byType(AppBar), findsOneWidget);
      
      // Should find a SingleChildScrollView
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      
      // We assume it renders the text, we can check that there is at least one Text widget
      expect(find.byType(Text), findsWidgets);
    });
  });
}
