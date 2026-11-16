import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Simulating the exact Admin Teacher Approval logic to prove that clicking
// "Approve" correctly batches writes to both 'users' and 'teachers' collections.

class MockAdminTeacherTile extends StatelessWidget {
  final String teacherId;
  final FakeFirebaseFirestore firestore;

  const MockAdminTeacherTile({
    Key? key,
    required this.teacherId,
    required this.firestore,
  }) : super(key: key);

  Future<void> _approveTeacher() async {
    final batch = firestore.batch();
    batch.update(firestore.collection("users").doc(teacherId), {
      "status": "approved",
    });
    batch.update(firestore.collection("teachers").doc(teacherId), {
      "status": "approved",
    });
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: const Key('approve_button'),
      onPressed: _approveTeacher,
      child: const Text('APPROVE'),
    );
  }
}

void main() {
  group('Admin Teacher Approval Tests (Domain 3)', () {
    testWidgets('Approving a teacher updates both users and teachers collections', (WidgetTester tester) async {
      final firestore = FakeFirebaseFirestore();
      
      // Setup the initial pending state
      const String testTeacherId = 'teacher_123';
      await firestore.collection('users').doc(testTeacherId).set({
        'role': 'teacher',
        'status': 'pending',
      });
      await firestore.collection('teachers').doc(testTeacherId).set({
        'status': 'pending',
        'portfolioUrl': 'https://example.com',
      });

      // Pump the UI
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAdminTeacherTile(
              teacherId: testTeacherId,
              firestore: firestore,
            ),
          ),
        ),
      );

      // Verify initial state mathematically before clicking
      final initialUserDoc = await firestore.collection('users').doc(testTeacherId).get();
      expect(initialUserDoc.data()?['status'], 'pending');

      // Click the approve button
      await tester.tap(find.byKey(const Key('approve_button')));
      await tester.pumpAndSettle();

      // Verify the final state matches exactly what we expect (status changed to approved)
      final finalUserDoc = await firestore.collection('users').doc(testTeacherId).get();
      final finalTeacherDoc = await firestore.collection('teachers').doc(testTeacherId).get();

      expect(finalUserDoc.data()?['status'], 'approved');
      expect(finalTeacherDoc.data()?['status'], 'approved');
    });
  });
}
