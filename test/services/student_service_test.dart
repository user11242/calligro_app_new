import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:calligro_app/features/student/data/services/student_service.dart';
import 'package:calligro_app/features/student/data/model/student_user_model.dart';

void main() {
  group('Layer 2: StudentService Tests (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late StudentService studentService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      
      final user = MockUser(
        uid: 'student_123',
        email: 'test@student.com',
        displayName: 'Test Student',
      );
      mockAuth = MockFirebaseAuth(mockUser: user, signedIn: true);
      
      studentService = StudentService(
        auth: mockAuth,
        firestore: fakeFirestore,
      );
    });

    // -----------------------------------------------------------------------
    // getCurrentStudent
    // -----------------------------------------------------------------------
    test('getCurrentStudent() returns student data when document exists', () async {
      await fakeFirestore.collection('users').doc('student_123').set({
        'fullName': 'Test Student Data',
        'email': 'test@student.com',
        'photoUrl': 'photo.png',
        'followingCount': 10,
      });

      final student = await studentService.getCurrentStudent();

      expect(student.uid, 'student_123');
      expect(student.name, 'Test Student Data');
      expect(student.email, 'test@student.com');
      expect(student.photoUrl, 'photo.png');
      expect(student.isGuest, false);
      expect(student.followingCount, 10);
    });

    test('getCurrentStudent() returns guest model when user is null', () async {
      final loggedOutAuth = MockFirebaseAuth(signedIn: false);
      final loggedOutService = StudentService(
        auth: loggedOutAuth,
        firestore: fakeFirestore,
      );

      final student = await loggedOutService.getCurrentStudent();

      expect(student.uid, 'guest');
      expect(student.isGuest, true);
    });
    
    test('getCurrentStudent() creates default doc if not exists', () async {
      final student = await studentService.getCurrentStudent();

      expect(student.uid, 'student_123');
      expect(student.name, 'Student');
      expect(student.email, 'test@student.com');
      
      final doc = await fakeFirestore.collection('users').doc('student_123').get();
      expect(doc.exists, false);
    });

    // -----------------------------------------------------------------------
    // getStudentStream
    // -----------------------------------------------------------------------
    test('getStudentStream() returns a stream of StudentUserModel', () {
      expect(studentService.getStudentStream(), isA<Stream<StudentUserModel>>());
    });
    
    test('getStudentStream() returns guest if not logged in', () async {
      final loggedOutAuth = MockFirebaseAuth(signedIn: false);
      final loggedOutService = StudentService(
        auth: loggedOutAuth,
        firestore: fakeFirestore,
      );

      final stream = loggedOutService.getStudentStream();
      final student = await stream.first;
      expect(student.isGuest, true);
    });

    // -----------------------------------------------------------------------
    // getEnrolledCourses
    // -----------------------------------------------------------------------
    test('getEnrolledCourses() returns stream of enrolled courses', () {
      expect(studentService.getEnrolledCourses(), isA<Stream<List<Map<String, dynamic>>>>());
    });
    
    test('getEnrolledCourses() yields empty list when not logged in', () async {
      final loggedOutAuth = MockFirebaseAuth(signedIn: false);
      final loggedOutService = StudentService(
        auth: loggedOutAuth,
        firestore: fakeFirestore,
      );

      final stream = loggedOutService.getEnrolledCourses();
      final courses = await stream.first;
      expect(courses, isEmpty);
    });

    // -----------------------------------------------------------------------
    // getFeaturedCourses
    // -----------------------------------------------------------------------
    test('getFeaturedCourses() returns stream of active courses', () {
      expect(studentService.getFeaturedCourses(), isA<Stream<List<Map<String, dynamic>>>>());
    });

    // -----------------------------------------------------------------------
    // getTeachersStream
    // -----------------------------------------------------------------------
    test('getTeachersStream() returns stream of approved teachers', () {
      expect(studentService.getTeachersStream(), isA<Stream<List<Map<String, dynamic>>>>());
    });
  });
}
