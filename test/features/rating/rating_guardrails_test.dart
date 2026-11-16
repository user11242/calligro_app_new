import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratings guard-rails: one review per student per course, totals only on the server.
void main() {
  Iterable<File> dartIn(String dir) =>
      Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  test('rating domain is pure Dart; application has no Firebase or Flutter', () {
    for (final f in dartIn('lib/features/rating/domain')) {
      final c = f.readAsStringSync();
      expect(c.contains('package:flutter/') || c.contains('package:cloud_firestore') || c.contains('package:firebase_'), isFalse,
          reason: f.path);
    }
    for (final f in dartIn('lib/features/rating/application')) {
      final c = f.readAsStringSync();
      expect(c.contains('package:cloud_firestore') || c.contains('package:firebase_') || c.contains('package:flutter/'), isFalse,
          reason: f.path);
    }
  });

  test('nobody in the app writes rating totals (the server computes them)', () {
    for (final f in dartIn('lib')) {
      final c = f.readAsStringSync();
      for (final banned in ["'totalStars': FieldValue", "'reviewCount': FieldValue"]) {
        expect(c.contains(banned), isFalse, reason: '${f.path} writes $banned');
      }
    }
    expect(File('lib/features/rating/services/rating_service.dart').existsSync(), isFalse);
  });

  test('reviews are only created at their fixed id (never add())', () {
    for (final f in dartIn('lib')) {
      final c = f.readAsStringSync().replaceAll(RegExp(r'\s+'), '');
      expect(c.contains(".collection('reviews').add("), isFalse, reason: f.path);
      expect(c.contains(".collection('reviews').doc()"), isFalse, reason: f.path);
    }
    final repo = File('lib/features/rating/data/firestore_rating_repository.dart').readAsStringSync();
    expect(repo.contains('runTransaction'), isTrue, reason: 'read-then-create, never overwrite');
  });

  test('the home page asks CourseRatings, not Firestore', () {
    final home = File('lib/features/student/presentation/pages/student_home_page.dart').readAsStringSync();
    expect(home.contains("collection('reviews')"), isFalse);
    expect(home.contains('RatingScope.of(context).courseToRate()'), isTrue);
  });

  test('rules and server agree: fixed id, server totals, follow-only counters', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules.contains("reviewId == d.courseId + '_' + request.auth.uid"), isTrue);
    expect(rules.contains("keys.hasOnly(['followerCount', 'followingCount'])"), isTrue);
    expect(File('functions/ratings.js').readAsStringSync().contains('AggregateField.sum("rating")'), isTrue);
    expect(File('functions/index.js').readAsStringSync().contains('recomputeRatingsOnReview'), isTrue);
  });
}
