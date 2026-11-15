import 'package:calligro_app/features/community/data/firestore_community_repository.dart';
import 'package:calligro_app/features/profile/data/firestore_profile_repository.dart';
import 'package:calligro_app/features/profile/domain/profile_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// The profile data layer against a fake Firestore holding REAL field names.
void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('users/t1').set({
      'name': 'Ustadh Ali',
      'photoUrl': 'https://img/t1.jpg',
      'bio': 'Thuluth teacher',
      'role': 'teacher',
      'followerCount': 12,
      'followingCount': 3,
      'spokenLanguages': ['Arabic', 'English'],
      'totalStars': 9,
      'reviewCount': 2,
      'commissionRate': 0.6,
      'phone': '+962791234567',
      'email': 't1@example.com',
    });
    await db.doc('users/s1').set({'name': 'Sara', 'role': 'student'});
  });

  group('FirestoreProfileRepository', () {
    test('reads every profile field', () async {
      final p = (await FirestoreProfileRepository(firestore: db).watchProfile('t1').first)!;
      expect(p.name, 'Ustadh Ali');
      expect(p.photoUrl, 'https://img/t1.jpg');
      expect(p.bio, 'Thuluth teacher');
      expect(p.role, 'teacher');
      expect(p.followerCount, 12);
      expect(p.followingCount, 3);
      expect(p.spokenLanguages, ['Arabic', 'English']);
      expect(p.averageRating, 4.5);
      expect(p.commissionRate, 0.6);
      expect(p.email, 't1@example.com');
      expect(p.countryFlag, '🇯🇴', reason: 'flag from the phone number; the number itself is not exposed');
    });

    test('missing fields get safe defaults; unknown users are null', () async {
      final p = (await FirestoreProfileRepository(firestore: db).watchProfile('s1').first)!;
      expect(p.followerCount, 0);
      expect(p.spokenLanguages, isEmpty);
      expect(p.commissionRate, isNull);
      expect(p.countryFlag, '');
      expect(await FirestoreProfileRepository(firestore: db).watchProfile('ghost').first, isNull);
    });

    test('counts are integers even when stored as doubles; missing role is student', () async {
      await db.doc('users/x').set({'followerCount': 4.0, 'name': 'X'});
      final p = (await FirestoreProfileRepository(firestore: db).watchProfile('x').first)!;
      expect(p.followerCount, 4);
      expect(p.role, 'student');
    });
  });

  group('FirestoreFollowListRepository', () {
    setUp(() async {
      await db.doc('users/s2').set({'name': 'Omar', 'role': 'student', 'photoUrl': 'o.jpg'});
      for (final id in ['s1', 's2', 'gone']) {
        await db.doc('users/t1/followers/$id').set({'timestamp': Timestamp.now()});
      }
      await db.doc('users/t1/following/s2').set({'timestamp': Timestamp.now()});
    });

    test('loads existing accounts and skips deleted ones (without writing anything)', () async {
      final list = await FirestoreFollowListRepository(firestore: db).load('t1', FollowListKind.followers);
      expect(list.map((e) => e.id).toSet(), {'s1', 's2'});
      expect(list.firstWhere((e) => e.id == 's2').photoUrl, 'o.jpg');
      expect((await db.collection('users/t1/followers').get()).docs, hasLength(3), reason: 'no client-side cleanup');
    });

    test('following list', () async {
      final list = await FirestoreFollowListRepository(firestore: db).load('t1', FollowListKind.following);
      expect(list.single.name, 'Omar');
    });
  });

  group('FirestoreTeacherCoursesRepository', () {
    test('a teacher\'s courses with banner, level and students', () async {
      await db.collection('courses').doc('c1').set({
        'teacherId': 't1',
        'courseBanner': 'https://img/c1.jpg',
        'selectedCategory': 'Advanced',
        'enrolledStudents': ['s1', 's2'],
        'courseName': 'Thuluth 101',
      });
      await db.collection('courses').doc('c2').set({'teacherId': 'other'});
      final courses = await FirestoreTeacherCoursesRepository(firestore: db).watchCourses('t1').first;
      final c = courses.single;
      expect(c.id, 'c1');
      expect(c.bannerUrl, 'https://img/c1.jpg');
      expect(c.level, 'Advanced');
      expect(c.studentCount, 2);
      expect(c.isEnrolled('s2'), isTrue);
      expect(c.raw['courseName'], 'Thuluth 101');
    });

    test('enrolledStudents stored as a number still gives a count', () async {
      await db.collection('courses').doc('c1').set({'teacherId': 't1', 'enrolledStudents': 7});
      final c = (await FirestoreTeacherCoursesRepository(firestore: db).watchCourses('t1').first).single;
      expect(c.studentCount, 7);
      expect(c.isEnrolled('s1'), isFalse);
    });
  });

  group('FirestoreTeacherReviewsRepository', () {
    test('newest first, with each student\'s current photo', () async {
      await db.doc('users/s1').set({'name': 'Sara', 'role': 'student', 'photoUrl': 'sara.jpg'});
      await db.collection('reviews').doc('r1').set({
        'teacherId': 't1', 'studentId': 's1', 'studentName': 'Sara', 'courseName': 'Naskh',
        'rating': 4, 'reviewText': ' Great ', 'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      await db.collection('reviews').doc('r2').set({
        'teacherId': 't1', 'studentName': 'Anon', 'rating': 5, 'timestamp': Timestamp.fromDate(DateTime(2026, 3, 1)),
      });
      await db.collection('reviews').doc('r3').set({'teacherId': 'other', 'rating': 1});

      final reviews = await FirestoreTeacherReviewsRepository(firestore: db).watchReviews('t1').first;
      expect(reviews.map((r) => r.id), ['r2', 'r1']);
      expect(reviews.last.studentPhotoUrl, 'sara.jpg');
      expect(reviews.last.text, 'Great');
      expect(reviews.last.rating, 4);
      expect(reviews.last.courseName, 'Naskh');
      expect(reviews.first.studentPhotoUrl, '');
    });
  });

  group('FirestoreProfileCountsRepository (posts via the community repository)', () {
    test('posts, saved, liked and courses', () async {
      final posts = db.collection('community_posts');
      await posts.doc('p1').set({'userId': 't1', 'timestamp': Timestamp.now(), 'likes': {'s1': true}});
      await posts.doc('p2').set({'userId': 't1', 'timestamp': Timestamp.now(), 'likes': <String, dynamic>{}});
      await db.doc('users/s1/saved_posts/p1').set({'timestamp': Timestamp.now()});
      await db.collection('courses').doc('c1').set({'teacherId': 't1'});

      final counts = FirestoreProfileCountsRepository(
          firestore: db, community: FirestoreCommunityRepository(firestore: db));
      expect(await counts.watchPostCount('t1').first, 2);
      expect(await counts.watchLikedCount('s1').first, 1);
      expect(await counts.watchSavedCount('s1').first, 1);
      expect(await counts.watchCourseCount('t1').first, 1);
    });
  });

  group('FirebaseProfileViewerSource', () {
    test('signed-in user with role from users/{uid}; guest when signed out', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 't1'));
      final viewer = await FirebaseProfileViewerSource(auth: auth, firestore: db).currentViewer();
      expect(viewer.userId, 't1');
      expect(viewer.role, 'teacher');
      final guest = await FirebaseProfileViewerSource(auth: MockFirebaseAuth(), firestore: db).currentViewer();
      expect(guest.isGuest, isTrue);
    });
  });
}
