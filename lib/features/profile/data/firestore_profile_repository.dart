import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:calligro_app/core/utils/country_utils.dart';
import 'package:calligro_app/features/community/domain/repositories/community_repositories.dart';

import '../domain/profile_models.dart';
import '../domain/profile_repositories.dart';

/// The ONE place that knows the users/{uid} field names.
class ProfileFirestoreMapper {
  ProfileFirestoreMapper._();

  static int _int(Object? v) => v is num ? v.toInt() : 0;
  static String _str(Object? v) => v is String ? v : '';

  static UserProfile profile(String id, Map<String, dynamic> d) => UserProfile(
        id: id,
        name: _str(d['name']),
        photoUrl: _str(d['photoUrl']),
        bio: _str(d['bio']),
        role: _str(d['role']).isEmpty ? 'student' : _str(d['role']),
        followerCount: _int(d['followerCount']),
        followingCount: _int(d['followingCount']),
        spokenLanguages: [for (final l in (d['spokenLanguages'] as List?) ?? const []) if (l is String) l],
        totalStars: d['totalStars'] is num ? d['totalStars'] as num : 0,
        reviewCount: _int(d['reviewCount']),
        // Only the flag leaves the data layer, never the phone number.
        countryFlag: CountryUtils.getFlagFromPhoneNumber(_str(d['phone']).isNotEmpty ? _str(d['phone']) : _str(d['phoneNumber'])),
        commissionRate: d['commissionRate'] is num ? (d['commissionRate'] as num).toDouble() : null,
        email: _str(d['email']),
      );

  static FollowListEntry entry(String id, Map<String, dynamic> d) => FollowListEntry(
        id: id,
        name: _str(d['name']),
        photoUrl: _str(d['photoUrl']),
        role: _str(d['role']).isEmpty ? 'student' : _str(d['role']),
      );

  static TeacherCourse course(String id, Map<String, dynamic> d) {
    final enrolled = d['enrolledStudents'];
    final ids = enrolled is List ? [for (final e in enrolled) if (e is String) e] : const <String>[];
    return TeacherCourse(
      id: id,
      raw: d,
      bannerUrl: _str(d['courseBanner']),
      level: _str(d['selectedCategory']).isEmpty ? 'Beginner' : _str(d['selectedCategory']),
      enrolledStudentIds: ids,
      studentCount: enrolled is List ? enrolled.length : _int(enrolled),
    );
  }

  static TeacherReview review(String id, Map<String, dynamic> d, {String photoUrl = ''}) => TeacherReview(
        id: id,
        studentId: _str(d['studentId']),
        studentName: _str(d['studentName']),
        studentPhotoUrl: photoUrl,
        courseName: _str(d['courseName']),
        rating: d['rating'] is num ? (d['rating'] as num).toInt() : 5,
        text: _str(d['reviewText']).trim(),
        createdAt: d['timestamp'] is Timestamp ? (d['timestamp'] as Timestamp).toDate() : null,
      );
}

FirebaseFirestore _db(FirebaseFirestore? injected) => injected ?? FirebaseFirestore.instance;

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;

  @override
  Stream<UserProfile?> watchProfile(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    return _db(_injected).collection('users').doc(userId).snapshots().map((d) {
      final data = d.data();
      return data == null ? null : ProfileFirestoreMapper.profile(d.id, data);
    });
  }
}

class FirestoreFollowListRepository implements FollowListRepository {
  FirestoreFollowListRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;

  @override
  Future<List<FollowListEntry>> load(String userId, FollowListKind kind) async {
    final db = _db(_injected);
    final ids = (await db.collection('users').doc(userId).collection(kind.collection).get()).docs.map((d) => d.id);
    final docs = await Future.wait(ids.map((id) => db.collection('users').doc(id).get()));
    // Deleted accounts are skipped. Cleaning them up belongs on the server (a
    // client may not edit someone else's follower list under firestore.rules).
    return [
      for (final d in docs)
        if (d.data() != null) ProfileFirestoreMapper.entry(d.id, d.data()!),
    ];
  }
}

class FirestoreTeacherCoursesRepository implements TeacherCoursesRepository {
  FirestoreTeacherCoursesRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;

  @override
  Stream<List<TeacherCourse>> watchCourses(String teacherId) => _db(_injected)
      .collection('courses')
      .where('teacherId', isEqualTo: teacherId)
      .snapshots()
      .map((s) => [for (final d in s.docs) ProfileFirestoreMapper.course(d.id, d.data())]);
}

class FirestoreTeacherReviewsRepository implements TeacherReviewsRepository {
  FirestoreTeacherReviewsRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;

  @override
  Stream<List<TeacherReview>> watchReviews(String teacherId) {
    final db = _db(_injected);
    return db.collection('reviews').where('teacherId', isEqualTo: teacherId).snapshots().asyncMap((s) async {
      // One read per reviewer (not one per review tile, as before).
      final studentIds = {for (final d in s.docs) if (d.data()['studentId'] is String) d.data()['studentId'] as String}
        ..remove('');
      final photos = <String, String>{};
      await Future.wait(studentIds.map((id) async {
        try {
          final u = await db.collection('users').doc(id).get();
          final photo = u.data()?['photoUrl'];
          if (photo is String) photos[id] = photo;
        } catch (e) {
          debugPrint('Reviewer photo $id could not be loaded: $e');
        }
      }));
      final reviews = [
        for (final d in s.docs)
          ProfileFirestoreMapper.review(d.id, d.data(), photoUrl: photos[d.data()['studentId']] ?? ''),
      ]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return reviews;
    });
  }
}

/// Post / saved / liked counts come from the community repository (which owns
/// that schema); course counts from courses.
class FirestoreProfileCountsRepository implements ProfileCountsRepository {
  FirestoreProfileCountsRepository({FirebaseFirestore? firestore, required CommunityRepository community})
      : _injected = firestore,
        _community = community;
  final FirebaseFirestore? _injected;
  final CommunityRepository _community;

  @override
  Stream<int> watchPostCount(String userId) => _community.watchUserPosts(userId).map((p) => p.length);

  @override
  Stream<int> watchSavedCount(String userId) => _community.watchSavedPostIds(userId).map((p) => p.length);

  @override
  Stream<int> watchLikedCount(String userId) => _community.watchLikedPosts(userId).map((p) => p.length);

  @override
  Stream<int> watchCourseCount(String teacherId) => _db(_injected)
      .collection('courses')
      .where('teacherId', isEqualTo: teacherId)
      .snapshots()
      .map((s) => s.docs.length);
}

class FirebaseProfileViewerSource implements ProfileViewerSource {
  FirebaseProfileViewerSource({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth,
        _injected = firestore;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _injected;

  @override
  Future<ProfileViewer> currentViewer() async {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) return ProfileViewer.guest;
    try {
      final role = (await _db(_injected).collection('users').doc(user.uid).get()).data()?['role'];
      return ProfileViewer(userId: user.uid, role: role is String && role.isNotEmpty ? role : 'student');
    } catch (e) {
      debugPrint('Viewer role could not be loaded: $e');
      return ProfileViewer(userId: user.uid);
    }
  }
}
