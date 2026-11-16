import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structure guard-rails: no giant screens again, features live in their folders.
void main() {
  int linesOf(String p) => File(p).readAsLinesSync().length;

  test('the two giant screens stay split (page file = state + loading; sections in part files)', () {
    expect(linesOf('lib/features/teacher/pages/course_details/course_details_page.dart'), lessThan(1000));
    expect(linesOf('lib/features/student/pages/student_home_page.dart'), lessThan(600));
    for (final f in Directory('lib/features/teacher/pages/course_details').listSync().whereType<File>()) {
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
}
