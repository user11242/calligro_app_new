import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:calligro_app/core/utils/country_utils.dart';

import '../domain/course_models.dart';
import '../domain/course_repositories.dart';

class FirestoreCourseRepository implements CourseRepository {
  FirestoreCourseRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;

  /// Safety cap for the live catalogue (the app has far fewer courses today).
  static const catalogCap = 500;

  final _teachers = <String, CourseTeacherSummary?>{};

  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _courses => _db.collection('courses');

  static List<Course> _newestFirst(QuerySnapshot<Map<String, dynamic>> s) {
    final list = [for (final d in s.docs) Course.fromMap(d.id, d.data())];
    list.sort((a, b) {
      final x = a.createdAt, y = b.createdAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    return list;
  }

  @override
  Stream<Course?> watchCourse(String courseId) => _courses.doc(courseId).snapshots().map((d) {
        final data = d.data();
        return data == null ? null : Course.fromMap(d.id, data);
      });

  // Same data as before the refactor (all courses, sorted on the phone):
  // no orderBy, so courses without createdAt still appear and no index is needed.
  @override
  Stream<List<Course>> watchCatalog() => _courses.limit(catalogCap).snapshots().map(_newestFirst);

  @override
  Stream<List<Course>> watchEnrolled(String uid) => uid.isEmpty
      ? Stream.value(const [])
      : _courses.where('enrolledStudents', arrayContains: uid).snapshots().map(_newestFirst);

  @override
  Stream<List<Course>> watchTeaching(String teacherId) => teacherId.isEmpty
      ? Stream.value(const [])
      : _courses.where('teacherId', isEqualTo: teacherId).snapshots().map(_newestFirst);

  /// The first [limit] of the catalogue (same query, same ordering rules).
  @override
  Stream<List<Course>> watchLatest({int limit = 10}) => watchCatalog().map((all) => all.take(limit).toList());

  @override
  Future<CourseTeacherSummary?> teacherSummary(String teacherId) async {
    if (_teachers.containsKey(teacherId)) return _teachers[teacherId];
    final user = (await _db.collection('users').doc(teacherId).get()).data();
    if (user == null) return _teachers[teacherId] = null;
    final courses = await _courses.where('teacherId', isEqualTo: teacherId).get();
    final stars = user['totalStars'] is num ? (user['totalStars'] as num).toDouble() : 0.0;
    final reviews = user['reviewCount'] is num ? (user['reviewCount'] as num).toInt() : 0;
    var students = 0;
    for (final d in courses.docs) {
      final e = d.data()['enrolledStudents'];
      students += e is List ? e.length : 0;
    }
    return _teachers[teacherId] = CourseTeacherSummary(
      id: teacherId,
      name: user['name'] is String ? user['name'] as String : '',
      photoUrl: user['photoUrl'] is String ? user['photoUrl'] as String : '',
      averageRating: reviews == 0 ? 0 : stars / reviews, // totalStars is a SUM
      reviewCount: reviews,
      followerCount: user['followerCount'] is num ? (user['followerCount'] as num).toInt() : 0,
      courseCount: courses.size,
      totalStudents: students,
      spokenLanguages: [for (final l in (user['spokenLanguages'] as List?) ?? const []) if (l is String) l],
      // Only the flag leaves the data layer, never the phone number.
      countryFlag: CountryUtils.getFlagFromPhoneNumber(
          user['phone'] is String ? user['phone'] as String : (user['phoneNumber'] is String ? user['phoneNumber'] as String : null)),
    );
  }
}
