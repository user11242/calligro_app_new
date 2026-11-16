import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structure guard-rails: no giant screens again, features live in their folders.
void main() {
  int linesOf(String p) => File(p).readAsLinesSync().length;

  test('the two giant screens stay split (page file = state + loading; sections in part files)', () {
    expect(linesOf('lib/features/classroom/presentation/pages/course_details_page.dart'), lessThan(1000));
    expect(linesOf('lib/features/student/presentation/pages/student_home_page.dart'), lessThan(600));
    for (final f in Directory('lib/features/classroom/presentation/pages').listSync().whereType<File>()) {
      if (f.path.contains('course_details_')) expect(linesOf(f.path), lessThan(1000), reason: f.path);
    }
  });

  test('course chat lives in classroom; the meeting launcher lives in meet', () {
    expect(Directory('lib/features/course_chat').existsSync() &&
            Directory('lib/features/course_chat').listSync(recursive: true).whereType<File>().isNotEmpty,
        isFalse);
    expect(File('lib/features/classroom/presentation/chat/course_chat_page.dart').existsSync(), isTrue);
    expect(File('lib/features/meet/presentation/livekit_meet_service.dart').existsSync(), isTrue);
    expect(File('lib/features/teacher/services/livekit_meet_service.dart').existsSync(), isFalse);
  });

  test('no dead "meeting presence" check (nothing writes it since LiveKit)', () {
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      expect(f.readAsStringSync().contains('meetingPresence'), isFalse, reason: f.path);
    }
  });

  test('classroom chat domain is pure', () {
    expect(File('lib/features/classroom/domain/course_chat_message.dart').readAsStringSync().contains('package:'), isFalse);
  });

  test('no external meeting services: the classroom is Calligro Meet (LiveKit) only', () {
    // Built at run time so this test file itself does not match.
    final banned = RegExp(['jit', 'si'].join() + '|' + ['google', r'\s?meet'].join() + '|' + ['meet', r'\.google'].join(), caseSensitive: false);
    final files = [
      ...Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') || f.path.endsWith('.arb')),
      ...Directory('functions').listSync().whereType<File>().where((f) => f.path.endsWith('.js')),
      File('pubspec.yaml'),
    ];
    for (final f in files) {
      expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
    expect(File('pubspec.yaml').readAsStringSync().contains('googleapis'), isFalse);
  });

  group('role shells (admin / student / teacher) stay thin', () {
    const shells = ['admin', 'student', 'teacher'];
    Iterable<File> dartIn(String dir) =>
        Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    String shellOf(String importLine) =>
        RegExp(r'features/(admin|student|teacher)/').firstMatch(importLine)?.group(1) ?? '';
    List<String> importsOf(File f) => f
        .readAsLinesSync()
        .where((l) => l.startsWith('import ') || l.startsWith('export '))
        .toList();

    test('a shell is only its dashboard, screens and its own data (no feature code)', () {
      const allowed = {
        'admin': {'presentation', 'data', 'domain'}, // admin is also a feature (AdminRules)
        'student': {'presentation', 'data'},
        'teacher': {'presentation'},
      };
      for (final r in shells) {
        final dirs = Directory('lib/features/$r').listSync().whereType<Directory>().map((d) => d.uri.pathSegments[d.uri.pathSegments.length - 2]);
        for (final d in dirs) {
          expect(allowed[r]!.contains(d), isTrue, reason: 'lib/features/$r/$d: put feature code in its feature folder');
        }
        expect(Directory('lib/features/$r').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')), isEmpty,
            reason: 'lib/features/$r: files go in presentation/ or data/');
      }
    });

    test('shells do not import each other', () {
      for (final r in shells) {
        for (final f in dartIn('lib/features/$r')) {
          for (final l in importsOf(f)) {
            final other = shellOf(l);
            expect(other == '' || other == r, isTrue, reason: '${f.path}: $l');
          }
        }
      }
    });

    test('features never depend on a shell (except the frozen, documented links)', () {
      // Each of these is a known link that ARCHITECTURE.md explains. Do not add to this list:
      // move the code into a feature instead.
      const frozen = {
        'lib/features/notifications/presentation/app_notification_navigator.dart': {'admin'}, // opens the pending-teachers page
        'lib/features/profile/presentation/pages/my_profile_tab.dart': {'admin', 'student', 'teacher'}, // opens each role's settings
        'lib/features/classroom/presentation/pages/course_details_page.dart': {'admin'}, // AdminService.sendCourseNotification
      };
      for (final f in dartIn('lib/features')) {
        final path = f.path.replaceAll(r'\', '/');
        final own = shellOf('$path/');
        if (shells.contains(own) && path.startsWith('lib/features/$own/')) continue;
        for (final l in importsOf(f)) {
          final shell = shellOf(l) == '' && RegExp(r"'(\.\./)+(admin|student|teacher)/").hasMatch(l) ? 'relative' : shellOf(l);
          if (shell == '') continue;
          expect(frozen[path]?.contains(shell) ?? false, isTrue, reason: '$path depends on the $shell shell: $l');
        }
      }
    });
  });

  test('test/ mirrors lib/ (the old flat test folders do not come back)', () {
    for (final old in ['services', 'widgets', 'models', 'ui', 'utils']) {
      expect(Directory('test/$old').existsSync(), isFalse, reason: 'test/$old: put the test next to its feature');
    }
  });
}
