import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/admin/admin_dashboard.dart';
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
      'name': 'Test Admin',
      'email': 'admin@example.com',
      'role': 'admin',
      'photoUrl': 'https://example.com/photo.jpg',
    });
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminDashboardPage(
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
    );
  }

  group('Layer 3: Dashboards -> AdminDashboardPage', () {
    testWidgets('(Coverage) AdminDashboardPage renders its initial loading scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      // Before async data loads: shows loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
