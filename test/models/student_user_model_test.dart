import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/student/data/model/student_user_model.dart';

void main() {
  group('Layer 1: StudentUserModel Tests (Coverage)', () {
    test('fromMap() converts Firebase map to StudentUserModel correctly', () {
      final mockMap = {
        'name': 'Student Name',
        'email': 'student@calligro.com',
        'photoUrl': 'https://example.com/student.jpg',
        'followingCount': 5,
      };

      final student = StudentUserModel.fromMap(mockMap, 'student_123');

      expect(student.uid, 'student_123');
      expect(student.name, 'Student Name');
      expect(student.email, 'student@calligro.com');
      expect(student.photoUrl, 'https://example.com/student.jpg');
      expect(student.isGuest, false);
      expect(student.followingCount, 5);
    });

    test('fromMap() handles missing fullName fallback to name', () {
      final mockMap = {
        'fullName': 'Full Name',
      };

      final student = StudentUserModel.fromMap(mockMap, 'student_456');
      expect(student.name, 'Full Name');
    });

    test('fromMap() handles null values safely with defaults', () {
      final student = StudentUserModel.fromMap({}, 'student_789');

      expect(student.uid, 'student_789');
      expect(student.name, 'Student');
      expect(student.email, '');
      expect(student.photoUrl, '');
      expect(student.isGuest, false);
      expect(student.followingCount, 0);
    });

    test('guest() factory creates correct guest profile', () {
      final guest = StudentUserModel.guest();

      expect(guest.uid, 'guest');
      expect(guest.name, 'Guest');
      expect(guest.email, '');
      expect(guest.photoUrl, '');
      expect(guest.isGuest, true);
      expect(guest.followingCount, 0);
    });
  });
}
