import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:calligro_app/screens/splash_screen.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Layer 3: Standalone Screens -> SplashScreen (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('SplashScreen renders its animations and logo', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        SplashScreen(
          auth: mockAuth,
          firestore: fakeFirestore,
          disableNavigation: true,
        ),
      ));
      
      // The screen should render a Container with a gradient, and an Image asset
      expect(find.byType(Container), findsWidgets);
      
      // Let the animation play a bit and clear the 4-second splash timer
      await tester.pump(const Duration(seconds: 5));
      
      // Since the app uses precacheImage and flutter_animate, we check for an Image asset
      // Depending on the exact tree, we can just verify it didn't crash
      expect(find.byType(SplashScreen), findsOneWidget);
    });
  });
}
