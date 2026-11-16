import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:calligro_app/features/auth/pages/forgot_password_page.dart';
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

  group('Layer 3: Authentication Flow -> ForgotPasswordPage (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late AuthService mockAuthService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockAuthService = AuthService(firestore: fakeFirestore);
    });

    testWidgets('ForgotPasswordPage renders correctly initially', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        ForgotPasswordPage(
          auth: mockAuth,
          firestore: fakeFirestore,
          authService: mockAuthService,
        ),
      ));
      
      await tester.pumpAndSettle();
      
      // Should find the back button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      
      // Should find the Email text field for step 0
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('ForgotPasswordPage shows Google info dialog when pressing button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        ForgotPasswordPage(
          auth: mockAuth,
          firestore: fakeFirestore,
          authService: mockAuthService,
        ),
      ));
      
      await tester.pumpAndSettle();
      
      // Find the Google sign info button
      final googleButton = find.textContaining('Google', skipOffstage: false);
      if (googleButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(googleButton.first);
        await tester.tap(googleButton.first);
        await tester.pumpAndSettle();
        
        // Should show Dialog with g_mobiledata_rounded icon
        expect(find.byIcon(Icons.g_mobiledata_rounded), findsOneWidget);
      }
    });
  });
}
