import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../application/course_purchases.dart';
import '../data/firestore_course_repository.dart';
import '../data/store_gateways.dart';
import '../domain/course_repositories.dart';

/// What the course screens talk to. The ONLY place that picks real implementations.
class CourseServices {
  CourseServices({
    required this.courses,
    required CoursePurchases Function() purchases,
    required this.currentUid,
  }) : _purchases = purchases;

  /// Real services. Only the repository depends on [firestore]; purchases are
  /// the single app-wide instance ([appPurchases]).
  factory CourseServices.firebase({FirebaseFirestore? firestore, FirebaseAuth? auth}) => CourseServices(
        courses: FirestoreCourseRepository(firestore: firestore),
        purchases: appPurchases,
        currentUid: () => (auth ?? FirebaseAuth.instance).currentUser?.uid ?? '',
      );

  final CourseRepository courses;
  final String Function() currentUid;
  final CoursePurchases Function() _purchases;

  /// Resolved on first use (screens that only browse never touch the store).
  CoursePurchases get purchases => _purchases();

  static CoursePurchases? _app;

  /// The ONE purchase flow of the app: created once, never per screen.
  /// main.dart calls this at launch so re-delivered purchases are handled.
  static CoursePurchases appPurchases() => _app ??= CoursePurchases(
        store: InAppPurchaseStore(),
        enrollment: CloudFunctionsEnrollment(),
        intents: SharedPrefsIntentStore(),
        currentUid: () => FirebaseAuth.instance.currentUser?.uid ?? '',
      )..start();
}

class CourseScope extends InheritedWidget {
  const CourseScope({super.key, required this.services, required super.child});

  final CourseServices services;
  static CourseServices? _fallback;

  /// Without a scope (pushed pages, deep links) the same cached real services are used.
  static CourseServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CourseScope>()?.services ??
      (_fallback ??= CourseServices.firebase());

  @override
  bool updateShouldNotify(CourseScope oldWidget) => services != oldWidget.services;
}
