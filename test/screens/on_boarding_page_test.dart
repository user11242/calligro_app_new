import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:calligro_app/screens/on_boarding_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/localization/locale_provider.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: Builder(
        builder: (context) {
          final localeProvider = Provider.of<LocaleProvider>(context);
          return MaterialApp(
            locale: localeProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: child,
            ),
          );
        },
      ),
    );
  }

  group('Layer 3: Standalone Screens -> OnboardingPage (Coverage)', () {
    testWidgets('OnboardingPage renders correctly and handles language tap', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const OnboardingPage(mockVideo: true),
      ));
      
      // Should find the language icon
      expect(find.byIcon(Icons.language), findsWidgets);
      
      // We can also find the Get Started button (text might be localized, but we check byType or Icon if available)
      // Since Get Started is definitely there, we can look for it in the localized format.
      // In English, it is 'Get Started'
      expect(find.text('Get Started'), findsOneWidget);
      
      // Tap the language selector
      final langSelector = find.byIcon(Icons.language).first;
      await tester.tap(langSelector);
      await tester.pumpAndSettle();
      
      // Should find the language bottom sheet
      expect(find.text('English'), findsWidgets);
    });
  });
}
