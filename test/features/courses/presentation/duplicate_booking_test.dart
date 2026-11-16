import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Simulating the "Duplicate Booking" prevention logic.
// If a student is already enrolled in a course, the "BOOK NOW" button
// should automatically change to a "GO TO COURSE" button instead.

class MockDuplicateBookingBar extends StatelessWidget {
  final String courseId;
  final FakeFirebaseFirestore firestore;
  final MockFirebaseAuth auth;

  const MockDuplicateBookingBar({
    Key? key,
    required this.courseId,
    required this.firestore,
    required this.auth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('courses').doc(courseId).snapshots(),
      builder: (context, snapshot) {
        final currentUser = auth.currentUser;
        bool isEnrolled = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> enrolledStudents = data['enrolledStudents'] ?? [];
              
          if (currentUser != null && enrolledStudents.contains(currentUser.uid)) {
            isEnrolled = true;
          }
        }

        if (isEnrolled) {
          return ElevatedButton(
            onPressed: () {},
            child: const Text('GO TO COURSE'),
          );
        }

        return ElevatedButton(
          onPressed: () {},
          child: const Text('BOOK NOW'),
        );
      },
    );
  }
}

void main() {
  group('Duplicate Booking Prevention Tests (Domain 2)', () {
    testWidgets('Changes Book Now to Go To Course if student is already enrolled', (WidgetTester tester) async {
      final firestore = FakeFirebaseFirestore();
      
      // We log in as 'student1'
      final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'student1'));

      // Setup a course where student1 is ALREADY enrolled
      const String testCourseId = 'course_999';
      await firestore.collection('courses').doc(testCourseId).set({
        'maxStudents': 10,
        'enrolledStudents': ['student1'], // Student is already here
      });

      // Pump the UI
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockDuplicateBookingBar(
              courseId: testCourseId,
              firestore: firestore,
              auth: auth,
            ),
          ),
        ),
      );

      // Wait for StreamBuilder to resolve
      await tester.pumpAndSettle();

      // Verify "GO TO COURSE" appears, preventing duplicate purchases
      expect(find.text('GO TO COURSE'), findsOneWidget);
      expect(find.text('BOOK NOW'), findsNothing);
    });
  });
}
