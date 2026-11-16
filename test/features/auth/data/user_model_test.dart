import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/features/auth/data/models/user_model.dart';

void main() {
  group('Layer 1: UserModel Tests (Coverage)', () {
    final now = DateTime(2026, 1, 1);
    final timestamp = Timestamp.fromDate(now);

    final mockMap = {
      'uid': 'user123',
      'email': 'test@calligro.com',
      'authProvider': 'google',
      'phone': '+1234567890',
      'name': 'Yazan',
      'role': 'teacher',
      'status': 'approved',
      'acceptedTerms': true,
      'bio': 'Master Calligrapher',
      'photoUrl': 'https://example.com/photo.jpg',
      'portfolio': 'https://portfolio.com',
      'language': 'ar',
      'spokenLanguages': ['ar', 'en'],
      'followersCount': 100,
      'followingCount': 50,
      'postCount': 10,
      'totalStars': 500,
      'reviewCount': 100,
      'createdAt': timestamp,
    };

    test('fromMap() converts Firebase map to UserModel correctly', () {
      final user = UserModel.fromMap(mockMap);

      expect(user.uid, 'user123');
      expect(user.email, 'test@calligro.com');
      expect(user.authProvider, 'google');
      expect(user.phone, '+1234567890');
      expect(user.name, 'Yazan');
      expect(user.role, 'teacher');
      expect(user.status, 'approved');
      expect(user.acceptedTerms, true);
      expect(user.bio, 'Master Calligrapher');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.portfolio, 'https://portfolio.com');
      expect(user.language, 'ar');
      expect(user.spokenLanguages, ['ar', 'en']);
      expect(user.followersCount, 100);
      expect(user.followingCount, 50);
      expect(user.postCount, 10);
      expect(user.totalStars, 500);
      expect(user.reviewCount, 100);
      expect(user.createdAt, now);
    });

    test('fromMap() handles null values safely with defaults', () {
      final user = UserModel.fromMap({});

      expect(user.uid, '');
      expect(user.email, '');
      expect(user.authProvider, 'email');
      expect(user.phone, '');
      expect(user.name, '');
      expect(user.role, 'student');
      expect(user.status, 'pending');
      expect(user.acceptedTerms, false);
      expect(user.bio, '');
      expect(user.photoUrl, '');
      expect(user.portfolio, null);
      expect(user.language, 'en');
      expect(user.spokenLanguages, isEmpty);
      expect(user.followersCount, 0);
      expect(user.followingCount, 0);
      expect(user.postCount, 0);
      expect(user.totalStars, 0);
      expect(user.reviewCount, 0);
      expect(user.createdAt, isA<DateTime>()); // Falls back to DateTime.now()
    });

    test('toMap() converts UserModel back to Firebase map', () {
      final user = UserModel.fromMap(mockMap);
      final generatedMap = user.toMap();

      expect(generatedMap['uid'], 'user123');
      expect(generatedMap['email'], 'test@calligro.com');
      expect(generatedMap['authProvider'], 'google');
      expect(generatedMap['phone'], '+1234567890');
      expect(generatedMap['name'], 'Yazan');
      expect(generatedMap['role'], 'teacher');
      expect(generatedMap['status'], 'approved');
      expect(generatedMap['acceptedTerms'], true);
      expect(generatedMap['bio'], 'Master Calligrapher');
      expect(generatedMap['photoUrl'], 'https://example.com/photo.jpg');
      expect(generatedMap['portfolio'], 'https://portfolio.com');
      expect(generatedMap['language'], 'ar');
      expect(generatedMap['spokenLanguages'], ['ar', 'en']);
      expect(generatedMap['followersCount'], 100);
      expect(generatedMap['followingCount'], 50);
      expect(generatedMap['postCount'], 10);
      expect(generatedMap['totalStars'], 500);
      expect(generatedMap['reviewCount'], 100);
      expect(generatedMap['createdAt'], isA<Timestamp>()); // Must convert to Timestamp for Firestore
    });
  });
}
