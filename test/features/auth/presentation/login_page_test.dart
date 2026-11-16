import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:calligro_app/features/auth/pages/login_page.dart';
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
            home: child,
          );
        },
      ),
    );
  }

  group('Layer 3: Authentication Flow -> LoginPage & LoginForm (Coverage)', () {
    late MockFirebaseAuth mockAuth;

    setUp(() {
      mockAuth = MockFirebaseAuth();
    });

    testWidgets('LoginPage renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        LoginPage(
          auth: mockAuth,
        ),
      ));
      
      await tester.pumpAndSettle();
      
      // Should find the back button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      
      // Should find the email and password text fields
      expect(find.byType(TextField), findsWidgets);
      
      // Tests pass if TextFields render correctly
    });

    testWidgets('LoginForm toggles password visibility', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        LoginPage(
          auth: mockAuth,
        ),
      ));
      
      await tester.pumpAndSettle();
      
      // Find the visibility toggle icon (Icons.visibility_off is default)
      final visibilityIcon = find.byIcon(Icons.visibility_off);
      expect(visibilityIcon, findsOneWidget);
      
      // Tap the icon
      await tester.tap(visibilityIcon);
      await tester.pumpAndSettle();
      
      // It should change to Icons.visibility
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });
}
