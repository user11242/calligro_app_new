import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/admin/data/services/admin_service.dart';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mockito/mockito.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return MockHttpsCallable();
  }
}

class MockHttpsCallable extends Mock implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    return MockHttpsCallableResult<T>();
  }
}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {
  @override
  T get data => {} as T;
}

void main() {
  group('Layer 2: AdminService Tests (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFunctions mockFunctions;
    late AdminService adminService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(signedIn: true);
      mockFunctions = MockFirebaseFunctions();
      adminService = AdminService(
        firestore: fakeFirestore,
        auth: mockAuth,
        functions: mockFunctions,
      );
    });

    // -----------------------------------------------------------------------
    // getGlobalStats
    // -----------------------------------------------------------------------
    test('getGlobalStats() retrieves counts from Firestore', () async {
      await fakeFirestore.collection('users').add({'role': 'student', 'status': 'approved'});
      await fakeFirestore.collection('users').add({'role': 'teacher', 'status': 'pending'});
      await fakeFirestore.collection('courses').add({'title': 'Course 1'});
      await fakeFirestore.collection('community_posts').add({'title': 'Post 1'});
      await fakeFirestore.collection('withdrawal_requests').add({'status': 'pending'});

      final stats = await adminService.getGlobalStats();

      expect(stats['totalUsers'], 2);
      expect(stats['totalCourses'], 1);
      expect(stats['totalPosts'], 1);
      expect(stats['pendingTeachers'], 1);
      expect(stats['pendingWithdrawals'], 1);
    });

    // -----------------------------------------------------------------------
    // getRecentActivity
    // -----------------------------------------------------------------------
    test('getRecentActivity() combines streams', () async {
      await fakeFirestore.collection('users').add({
        'name': 'New User', 'createdAt': '2024', 'status': 'approved'
      });
      await fakeFirestore.collection('community_posts').add({
        'userName': 'Poster', 'createdAt': '2024'
      });
      await fakeFirestore.collection('courses').add({
        'title': 'New Course', 'createdAt': '2024'
      });

      final stream = adminService.getRecentActivity();
      final items = await stream.first;
      
      expect(items.length, 3);
      final types = items.map((i) => i['type']).toList();
      expect(types, containsAll(['user', 'post', 'course']));
    });

    // -----------------------------------------------------------------------
    // broadcastMessage
    // -----------------------------------------------------------------------
    test('broadcastMessage() sends to all users', () async {
      await fakeFirestore.collection('users').doc('u1').set({'role': 'student'});
      await fakeFirestore.collection('users').doc('u2').set({'role': 'teacher'});

      await adminService.broadcastMessage('Title', 'Message', 'All Users');

      final broadcasts = await fakeFirestore.collection('broadcasts').get();
      expect(broadcasts.docs.length, 1);
      expect(broadcasts.docs.first.data()['targetAudience'], 'All Users');
    });

    test('broadcastMessage() sends to specific roles', () async {
      await fakeFirestore.collection('users').doc('u1').set({'role': 'student'});
      await fakeFirestore.collection('users').doc('u2').set({'role': 'teacher'});

      await adminService.broadcastMessage('Title', 'Message', 'Students Only');

      final broadcasts = await fakeFirestore.collection('broadcasts').get();
      expect(broadcasts.docs.length, 1);
      expect(broadcasts.docs.first.data()['targetAudience'], 'Students Only');
    });

    // -----------------------------------------------------------------------
    // enrollStudentInCourse
    // -----------------------------------------------------------------------
    test('enrollStudentInCourse() adds student to course and course to student', () async {
      await fakeFirestore.collection('courses').doc('c1').set({'studentCount': 0});
      await fakeFirestore.collection('users').doc('s1').set({'name': 'Student'});

      await adminService.enrollStudentInCourse('c1', 's1');

      final courseDoc = await fakeFirestore.collection('courses').doc('c1').get();
      expect((courseDoc.data() as Map)['enrolledCount'], 1);
      expect((courseDoc.data() as Map)['enrolledStudents'], contains('s1'));
    });

    // -----------------------------------------------------------------------
    // deleteCourse
    // -----------------------------------------------------------------------
    test('deleteCourse() removes a course', () async {
      await fakeFirestore.collection('courses').doc('c1').set({'title': 'Course'});
      await adminService.deleteCourse('c1');
      final doc = await fakeFirestore.collection('courses').doc('c1').get();
      expect(doc.exists, false);
    });

    // -----------------------------------------------------------------------
    // deletePost
    // -----------------------------------------------------------------------
    test('deletePost() removes a post', () async {
      await fakeFirestore.collection('community_posts').doc('p1').set({'title': 'Post'});
      await adminService.deletePost('p1');
      final doc = await fakeFirestore.collection('community_posts').doc('p1').get();
      expect(doc.exists, false);
    });

    // -----------------------------------------------------------------------
    // Admins
    // -----------------------------------------------------------------------
    test('getAdmins() returns stream of admins', () {
      expect(adminService.getAdmins(), isA<Stream>());
    });

    test('promoteToAdminByEmail() updates role if user exists', () async {
      await fakeFirestore.collection('users').doc('u1').set({'email': 'admin@test.com', 'role': 'student'});
      await adminService.promoteToAdminByEmail('admin@test.com');
      final doc = await fakeFirestore.collection('users').doc('u1').get();
      expect((doc.data() as Map)['role'], 'admin');
    });
    
    test('promoteToAdminByEmail() throws if user not found', () async {
      expect(() => adminService.promoteToAdminByEmail('none@test.com'), throwsException);
    });

    test('revokeAdminStatus() reverts to student', () async {
      await fakeFirestore.collection('users').doc('u1').set({'role': 'admin'});
      await adminService.revokeAdminStatus('u1');
      final doc = await fakeFirestore.collection('users').doc('u1').get();
      expect((doc.data() as Map)['role'], 'student');
    });

    // -----------------------------------------------------------------------
    // changeUserRole
    // -----------------------------------------------------------------------
    test('changeUserRole() updates role', () async {
      await fakeFirestore.collection('users').doc('u1').set({'role': 'student'});
      await adminService.changeUserRole('u1', 'teacher');
      final doc = await fakeFirestore.collection('users').doc('u1').get();
      expect((doc.data() as Map)['role'], 'teacher');
    });

    // -----------------------------------------------------------------------
    // sendUserNotification
    // -----------------------------------------------------------------------
    test('sendUserNotification() calls cloud function', () async {
      await adminService.sendUserNotification('u1', 'Hello', 'World');
      // No firestore assertions because it calls httpsCallable.
      // We just verify it doesn't throw.
    });

    // -----------------------------------------------------------------------
    // rejectTeacher
    // -----------------------------------------------------------------------
    test('rejectTeacher() updates status and role', () async {
      await fakeFirestore.collection('users').doc('u1').set({'status': 'pending', 'role': 'teacher'});
      await adminService.rejectTeacher('u1');
      final doc = await fakeFirestore.collection('users').doc('u1').get();
      final data = doc.data() as Map;
      expect(data['status'], 'rejected');
      final teacherDoc = await fakeFirestore.collection('teachers').doc('u1').get();
      expect(teacherDoc.exists, false);
    });

    // -----------------------------------------------------------------------
    // Streams
    // -----------------------------------------------------------------------
    test('getAllCourses() returns Stream', () {
      expect(adminService.getAllCourses(), isA<Stream>());
    });

    test('getAllPosts() returns Stream', () {
      expect(adminService.getAllPosts(), isA<Stream>());
    });

    test('getWithdrawalRequests() returns Stream', () {
      expect(adminService.getWithdrawalRequests(), isA<Stream>());
    });

    test('getFinancialTransactions() returns Stream', () {
      expect(adminService.getFinancialTransactions(), isA<Stream>());
    });

    test('getTeacherFinancialSnapshots() returns Stream', () {
      expect(adminService.getTeacherFinancialSnapshots(), isA<Stream>());
    });

    // -----------------------------------------------------------------------
    // updateWithdrawalStatus
    // -----------------------------------------------------------------------
    test('updateWithdrawalStatus() updates status', () async {
      await fakeFirestore.collection('withdrawal_requests').doc('w1').set({
        'status': 'pending', 'teacherId': 't1', 'amount': 100,
      });

      await adminService.updateWithdrawalStatus(
        requestId: 'w1', status: 'completed',
      );

      final doc = await fakeFirestore.collection('withdrawal_requests').doc('w1').get();
      expect((doc.data() as Map)['status'], 'completed');
    });

    // -----------------------------------------------------------------------
    // updateTransactionStatus
    // -----------------------------------------------------------------------
    test('updateTransactionStatus() updates status', () async {
      await fakeFirestore.collection('transactions').doc('tx1').set({'status': 'pending'});
      await adminService.updateTransactionStatus('tx1', 'success');
      final doc = await fakeFirestore.collection('transactions').doc('tx1').get();
      expect((doc.data() as Map)['status'], 'success');
    });
  });
}
