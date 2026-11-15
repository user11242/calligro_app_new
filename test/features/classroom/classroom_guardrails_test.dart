import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pass 3 guard-rails: the inside of a course talks to data only through the
/// classroom layers, and the teacher controls follow the role in THIS course.
void main() {
  Iterable<File> dartIn(String dir) =>
      Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  test('classroom domain is pure Dart', () {
    for (final f in dartIn('lib/features/classroom/domain')) {
      final c = f.readAsStringSync();
      for (final banned in ['package:flutter/', 'package:cloud_firestore', 'package:firebase_', 'dart:io']) {
        expect(c.contains(banned), isFalse, reason: '${f.path} imports $banned');
      }
    }
  });

  test('application layer has no Firebase or Flutter', () {
    for (final f in dartIn('lib/features/classroom/application')) {
      final c = f.readAsStringSync();
      expect(c.contains('package:cloud_firestore') || c.contains('package:firebase_') || c.contains('package:flutter/'), isFalse,
          reason: f.path);
    }
  });

  test('assignment, submission, material, recording and board screens use no Firestore/Storage directly', () {
    for (final name in [
      'assignments_page.dart',
      'assignment_details_page.dart',
      'student_submissions_page.dart',
      'course_materials_page.dart',
      'recordings_page.dart',
      'announcements_board_page.dart',
    ]) {
      final c = File('lib/features/teacher/pages/course_details/$name').readAsStringSync();
      for (final banned in ['FirebaseFirestore', 'FirebaseStorage', 'FirebaseAuth.instance']) {
        expect(c.contains(banned), isFalse, reason: '$name uses $banned');
      }
    }
  });

  test('nobody writes submissionCount any more (any signed-in user could set it)', () {
    for (final f in dartIn('lib')) {
      expect(f.readAsStringSync().contains("'submissionCount'"), isFalse, reason: f.path);
    }
  });

  test('the course page decides teacher controls from the role in THIS course', () {
    final c = File('lib/features/teacher/pages/course_details/course_details_page.dart').readAsStringSync();
    expect(c.contains("return userRole == 'teacher';"), isFalse, reason: 'every teacher got teacher controls on every course');
    expect(c.contains('ClassroomAccess.roleOf('), isTrue);
    expect(c.contains("collection('notifications')"), isFalse, reason: 'reschedule notices go through ClassroomBoard (one batch)');
  });

  test('rules: students never grade themselves; work locks at the due date', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules.contains("hasOnly(['note', 'fileUrl', 'fileName', 'submittedAt', 'studentName', 'studentImage'])"), isTrue);
    expect(rules.contains("hasOnly(['seenByTeacher', 'status', 'points', 'feedback', 'gradedAt'])"), isTrue);
    expect(rules.contains('request.time < assignment().dueDate'), isTrue);
  });
}
