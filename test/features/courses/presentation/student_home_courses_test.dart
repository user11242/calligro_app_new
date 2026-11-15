import 'dart:async';

import 'package:calligro_app/features/courses/application/course_purchases.dart';
import 'package:calligro_app/features/courses/domain/course_models.dart';
import 'package:calligro_app/features/courses/presentation/course_scope.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:calligro_app/features/student/data/model/student_user_model.dart';
import 'package:calligro_app/features/student/data/services/student_service.dart';
import 'package:calligro_app/features/student/pages/student_home_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/course_fixtures.dart';
import '../fakes/fake_courses.dart';
import '../../rating/fakes/fake_ratings.dart';
import 'package:calligro_app/features/rating/application/course_ratings.dart';
import 'package:calligro_app/features/rating/presentation/rating_scope.dart';

class _Student extends StudentService {
  _Student(FakeFirebaseFirestore db, MockFirebaseAuth auth) : super(auth: auth, firestore: db);
  @override
  Stream<StudentUserModel> getStudentStream() =>
      Stream.value(StudentUserModel(uid: 's1', name: 'Sara', email: 's@x.com', photoUrl: '', isGuest: false));
  @override
  Stream<List<Map<String, dynamic>>> getTeachersStream() => Stream.value(const []);
}

/// The real student home page: its course lists come from the course repository.
void main() {
  testWidgets('enrolled and "explore" lists are live; started courses are not offered to non-students', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeCourseRepository()
      ..put(courseDoc('mine', name: 'Enrolled Naskh', enrolled: ['s1']))
      ..put(courseDoc('open', name: 'Open Diwani'));
    // Already started, and s1 is not in it.
    repo.put(Course.fromMap('started', {
      ...realCourseData(name: 'Started Kufi'),
      'startDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
    }));
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 's1'));

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: CourseScope(
        services: CourseServices(
          courses: repo,
          authoring: FakeAuthoring(),
          purchases: () => throw StateError('not used') as CoursePurchases,
          currentUid: () => 's1',
        ),
        child: RatingScope(
          ratings: CourseRatings(repository: FakeRatingRepository(), currentUid: () => 's1'),
          child: StudentHomePage(studentService: _Student(db, auth), auth: auth, firestore: db),
        ),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Enrolled Naskh'), findsWidgets);
    expect(find.text('Open Diwani'), findsWidgets);
    expect(find.text('Started Kufi'), findsNothing, reason: 'same rule as the catalogue');

    repo.put(courseDoc('fresh', name: 'Fresh Thuluth'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Fresh Thuluth'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
