import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/auth/pages/register_page.dart';
import 'package:calligro_app/features/auth/widgets/google_hint_dialog.dart';
import 'package:calligro_app/features/auth/data/services/auth_service.dart';
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

  group('Layer 3: Authentication Flow -> RegisterPage & RegisterForm (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AuthService mockAuthService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthService = AuthService(firestore: fakeFirestore);
    });

    testWidgets('RegisterPage renders correctly and shows GoogleHintDialog on load', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        RegisterPage(
          authService: mockAuthService,
        ),
      ));
      
      await tester.pumpAndSettle();
      
      // Should find the back button on the RegisterPage
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      
      // Should find the RegisterForm fields (Name, Email, Password, etc.)
      expect(find.byType(TextField), findsWidgets);
      
      // Should find the GoogleHintDialog that pops up post-frame
      expect(find.byType(GoogleHintDialog), findsOneWidget);
    });

    testWidgets('RegisterForm handles obscure password toggles', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        RegisterPage(
          authService: mockAuthService,
        ),
      ));
      
      await tester.pumpAndSettle();
      
      // Dismiss the dialog first
      final maybeLaterButton = find.descendant(
        of: find.byType(GoogleHintDialog), 
        matching: find.byType(TextButton)
      );
      await tester.ensureVisible(maybeLaterButton);
      await tester.tap(maybeLaterButton);
      await tester.pumpAndSettle();
      
      // Find the visibility toggle buttons
      final toggleButtons = find.widgetWithIcon(IconButton, Icons.visibility_off);
      expect(toggleButtons, findsWidgets); // at least 2
      
      // Ensure visible and Tap the first button (password)
      await tester.ensureVisible(toggleButtons.first);
      await tester.tap(toggleButtons.first);
      await tester.pumpAndSettle();
      
      // It should change to Icons.visibility (at least one)
      expect(find.byIcon(Icons.visibility), findsWidgets);
    });
  });
}
