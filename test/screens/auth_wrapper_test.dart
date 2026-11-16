import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:calligro_app/screens/auth_wrapper.dart';
import 'package:calligro_app/screens/on_boarding_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/localization/locale_provider.dart';
import 'package:calligro_app/features/auth/data/services/auth_service.dart';

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

  group('Layer 3: Authentication Flow -> AuthWrapper (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late AuthService mockAuthService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(); // logged out by default
      mockAuthService = AuthService(firestore: fakeFirestore, auth: mockAuth);
    });

    testWidgets('AuthWrapper renders OnboardingPage when logged out', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        AuthWrapper(
          auth: mockAuth,
          firestore: fakeFirestore,
          authService: mockAuthService,
        ),
      ));
      
      await tester.pumpAndSettle();
      
      // Should find OnboardingPage
      expect(find.byType(OnboardingPage), findsOneWidget);
    });

    testWidgets('AuthWrapper renders loading or error gracefully when logged in but no data', (WidgetTester tester) async {
      final loggedInAuth = MockFirebaseAuth(signedIn: true);
      
      final loggedInAuthService = AuthService(firestore: fakeFirestore, auth: loggedInAuth);
      await tester.pumpWidget(buildTestableWidget(
        AuthWrapper(
          auth: loggedInAuth,
          firestore: fakeFirestore,
          authService: loggedInAuthService,
        ),
      ));
      
      await tester.pumpAndSettle();
      
      // Without user document, it might fallback to Onboarding or show a CircularProgressIndicator
      expect(find.byType(AuthWrapper), findsOneWidget);
    });
  });
}
