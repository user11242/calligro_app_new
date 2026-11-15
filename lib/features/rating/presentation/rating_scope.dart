import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../application/course_ratings.dart';
import '../data/firestore_rating_repository.dart';

/// The ONE place that picks the real rating implementation.
class RatingScope extends InheritedWidget {
  const RatingScope({super.key, required this.ratings, required super.child});

  final CourseRatings ratings;
  static CourseRatings? _fallback;

  /// Without a scope the same cached real service is used (one check at a time, app-wide).
  static CourseRatings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RatingScope>()?.ratings ??
      (_fallback ??= CourseRatings(
        repository: FirestoreRatingRepository(),
        currentUid: () => FirebaseAuth.instance.currentUser?.uid ?? '',
      ));

  @override
  bool updateShouldNotify(RatingScope oldWidget) => ratings != oldWidget.ratings;
}
