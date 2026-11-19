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
      final c = File('lib/features/classroom/presentation/pages/$name').readAsStringSync();
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
    final c = File('lib/features/classroom/presentation/pages/course_details_page.dart').readAsStringSync();
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

  test('chat reports use the field the rules check (it was "reportedBy", so every report failed)', () {
    final rules = File('firestore.rules').readAsStringSync();
    final chat = File('lib/features/classroom/data/course_chat_service.dart').readAsStringSync();
    expect(rules.contains('request.resource.data.reportedByUserId == request.auth.uid'), isTrue);
    expect(chat.contains("'reportedByUserId': reporterId"), isTrue);
    expect(chat.contains("'reportedBy':"), isFalse);
  });

  test('chat message limits match the rules (4000 characters, only the app\'s fields)', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules.contains("get('text', '').size() <= 4000"), isTrue);
    expect(rules.contains("hasOnly(['senderId', 'senderName', 'senderPhotoUrl', 'senderRole', 'text', 'imageUrl', 'createdAt'])"), isTrue);
  });

  test('students join only in the class window, from every entry point (the schedule rule)', () {
    final page = File('lib/features/classroom/presentation/pages/course_details_page.dart').readAsStringSync();
    final launch = File('lib/features/classroom/presentation/pages/course_details_classroom.dart').readAsStringSync();
    final hero = File('lib/features/student/presentation/pages/student_home_hero.dart').readAsStringSync();
    expect(page.contains('joinCheck: _role.canManage ? null : _studentJoinCheck'), isTrue, reason: 'the join bar is locked for students');
    expect(launch.contains('if (!_role.canManage && !_studentJoinCheck().canJoin)'), isTrue, reason: 'the join action re-checks');
    expect(launch.contains('SMART GATING DISABLED'), isFalse);
    expect(hero.contains('.joinCheck(DateTime.now())'), isTrue, reason: 'the home "Join class now" uses the same window');
  });
}
