import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/student/student_dashboard.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/features/student/data/services/student_service.dart';
import 'package:calligro_app/features/student/data/model/student_user_model.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'dart:async';

class FakeStudentService extends StudentService {
  final _studentController = StreamController<StudentUserModel>.broadcast();
  final _coursesController = StreamController<List<Map<String, dynamic>>>.broadcast();

  FakeStudentService() {
    _studentController.add(StudentUserModel(
      uid: 'fake-uid',
      name: 'Test Student',
      email: 'test@example.com',
      photoUrl: '',
      isGuest: false,
    ));
    _coursesController.add([]);
  }

  @override
  Stream<StudentUserModel> getStudentStream() => _studentController.stream;

  @override
  Stream<List<Map<String, dynamic>>> getEnrolledCourses() => _coursesController.stream;

  @override
  Stream<List<Map<String, dynamic>>> getFeaturedCourses() => _coursesController.stream;

  @override
  Stream<List<Map<String, dynamic>>> getTeachersStream() => _coursesController.stream;
}

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeFirestore = FakeFirebaseFirestore();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StudentDashboardPage(
        isGuestMode: false,
        studentService: FakeStudentService(),
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
    );
  }

  group('Layer 3: Dashboards -> StudentDashboardPage', () {
    testWidgets('(Coverage) StudentDashboardPage renders its bottom navigation items', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify BottomAppBar is present
      expect(find.byType(BottomAppBar), findsOneWidget);

      // Verify icons are present (using the unselected icons as they appear on first load, or both)
      expect(find.byIcon(Icons.home), findsWidgets);
      expect(find.byIcon(Icons.menu_book_outlined), findsWidgets);
      expect(find.byIcon(Icons.people_outline), findsWidgets);
      expect(find.byIcon(Icons.person_outline), findsWidgets);
    });
  });
}
