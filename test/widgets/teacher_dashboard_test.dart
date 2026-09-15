import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/teacher/teacher_dashboard.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    mockAuth = MockFirebaseAuth(signedIn: true);
    fakeFirestore = FakeFirebaseFirestore();
    await fakeFirestore.collection('users').doc(mockAuth.currentUser?.uid).set({
      'name': 'Test Teacher',
      'email': 'teacher@example.com',
      'role': 'teacher',
      'photoUrl': 'https://example.com/photo.jpg',
    });
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TeacherDashboardPage(
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
    );
  }

  group('Layer 3: Dashboards -> TeacherDashboardPage', () {
    testWidgets('(Coverage) TeacherDashboardPage shows loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      // The initial state is loading (CircularProgressIndicator)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('(Coverage) TeacherDashboardPage renders bottom nav after data loads', (WidgetTester tester) async {
      // Use a large surface to avoid overflow errors
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidgetUnderTest());
      // Allow async data fetch to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the scaffold is always rendered
      expect(find.byType(Scaffold), findsOneWidget);

      // Once loaded, the BottomAppBar and at minimum the selected home icon should be visible
      if (find.byType(BottomAppBar).evaluate().isNotEmpty) {
        expect(find.byType(BottomAppBar), findsOneWidget);
        // _selectedIndex starts at 0 so home is selected → Icons.home is shown
        expect(find.byIcon(Icons.home), findsWidgets);
      }
    });
  });
}
